use std::ffi::OsString;
use std::fmt;
use std::fs;
use std::io::{self, BufWriter, Write};
use std::path::PathBuf;
use std::process::ExitCode;

const BYTES_PER_LINE: usize = 16;

struct Options {
    start: usize,
    limit: usize,
    path: PathBuf,
}

enum CliError {
    Usage,
    MissingValue(&'static str),
    BadNumber { flag: &'static str, text: String },
    UnknownOption(String),
    TooManyFiles,
    Read { path: PathBuf, source: io::Error },
    Write(io::Error),
}

impl fmt::Display for CliError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Usage => write!(f, "usage: xxd-lite [-s start] [-l length] <file>"),
            Self::MissingValue(flag) => write!(f, "{flag}: missing value"),
            Self::BadNumber { flag, text } => write!(f, "{flag}: invalid number: {text}"),
            Self::UnknownOption(opt) => write!(f, "unknown option: {opt}"),
            Self::TooManyFiles => write!(f, "only one file can be given"),
            Self::Read { path, source } => write!(f, "{}: {source}", path.display()),
            Self::Write(source) => write!(f, "write error: {source}"),
        }
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("xxd-lite: {e}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), CliError> {
    let Options { start, limit, path } = parse_args(std::env::args_os().skip(1))?;
    let data = fs::read(&path).map_err(|source| CliError::Read { path, source })?;
    let (start, data) = clamp_window(&data, start, limit);
    let mut out = BufWriter::new(io::stdout().lock());
    dump(data, start, &mut out).map_err(CliError::Write)?;
    out.flush().map_err(CliError::Write)
}

fn parse_args(mut args: impl Iterator<Item = OsString>) -> Result<Options, CliError> {
    let (mut start, mut limit, mut path): (usize, usize, Option<PathBuf>) = (0, usize::MAX, None);
    while let Some(arg) = args.next() {
        match arg.to_str() {
            Some("-s") => start = parse_value("-s", args.next())?,
            Some("-l") => limit = parse_value("-l", args.next())?,
            Some(s) if s.starts_with('-') => return Err(CliError::UnknownOption(s.to_owned())),
            _ if path.is_some() => return Err(CliError::TooManyFiles),
            _ => path = Some(PathBuf::from(arg)),
        }
    }
    let path = path.ok_or(CliError::Usage)?;
    Ok(Options { start, limit, path })
}

fn parse_value(flag: &'static str, value: Option<OsString>) -> Result<usize, CliError> {
    let Some(value) = value else {
        return Err(CliError::MissingValue(flag));
    };
    let text = value.to_string_lossy().into_owned();
    text.parse().map_err(|_| CliError::BadNumber { flag, text })
}

fn clamp_window(data: &[u8], start: usize, limit: usize) -> (usize, &[u8]) {
    let start = start.min(data.len());
    let end = start.saturating_add(limit).min(data.len());
    (start, &data[start..end])
}

fn dump(bytes: &[u8], base: usize, out: &mut impl Write) -> io::Result<()> {
    use std::fmt::Write as _;

    let mut hex = String::with_capacity(39);
    let mut ascii = String::with_capacity(BYTES_PER_LINE);

    for (i, chunk) in bytes.chunks(BYTES_PER_LINE).enumerate() {
        hex.clear();
        ascii.clear();
        for (j, &b) in chunk.iter().enumerate() {
            if j > 0 && j % 2 == 0 {
                hex.push(' ');
            }
            write!(hex, "{b:02x}").expect("Writing on String must not be failed.");
            ascii.push(match b {
                0x20..=0x7e => char::from(b),
                _ => '.',
            });
        }

        let offset = base + i * BYTES_PER_LINE;
        writeln!(out, "{offset:08x}: {hex:<39}  {ascii}")?;
    }
    Ok(())
}
