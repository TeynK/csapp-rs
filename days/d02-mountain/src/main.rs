use core::fmt;
use std::error::Error;
use std::ffi::OsString;
use std::io;
use std::io::{BufWriter, Write};
use std::process::ExitCode;

mod measure;

const MAX_SIZE: usize = 1 << 28;
const MIN_SIZE: usize = 1 << 14;
const DEFAULT_STRIDE: usize = 1 << 4;

#[derive(Debug)]
enum CliError {
    Usage,
    UnknownOption(String),
    MissingValue(&'static str),
    InvalidSize(String),
    InvalidStride(String),
    InvalidUTF(&'static str),
    Write(io::Error),
}

impl fmt::Display for CliError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Usage => write!(f, "usage: mountain [-M <size>] [-S <stride>]"),
            Self::UnknownOption(opt) => write!(f, "unknown option \'{opt}\'"),
            Self::MissingValue(opt) => write!(f, "{opt} needs a value"),
            Self::InvalidSize(size) => {
                write!(f, "-M: invalid size \'{size}\' (power of two, 16K..256M)")
            }
            Self::InvalidStride(stride) => write!(f, "-S: invalid stride \'{stride}\' (1..64)"),
            Self::InvalidUTF(opt) => write!(f, "{opt}: value is not valid UTF-8"),
            Self::Write(e) => write!(f, "write error: {e}"),
        }
    }
}

impl std::error::Error for CliError {}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("mountain: {e}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    let (work_set, stride) = parse_args(std::env::args_os().skip(1))?;
    let mut out = BufWriter::new(io::stdout().lock());
    let data: Vec<u64> = vec![1u64; work_set / 8];
    write_mountain(&mut out, &data, work_set, stride).map_err(CliError::Write)?;
    out.flush().map_err(CliError::Write)?;
    Ok(())
}

fn parse_args(mut args: impl Iterator<Item = OsString>) -> Result<(usize, usize), CliError> {
    let mut work_set: usize = MAX_SIZE;
    let mut stride: usize = DEFAULT_STRIDE;
    while let Some(arg) = args.next() {
        match arg.to_str() {
            Some("-M") => {
                work_set = parse_size(&parse_value("-M", args.next())?)?;
            }
            Some("-S") => {
                stride = parse_stride(&parse_value("-S", args.next())?)?;
            }
            Some(s) if s.starts_with('-') => return Err(CliError::UnknownOption(s.to_owned())),
            _ => return Err(CliError::Usage),
        }
    }
    Ok((work_set, stride))
}

fn parse_value(opt: &'static str, value: Option<OsString>) -> Result<String, CliError> {
    let Some(value) = value else {
        return Err(CliError::MissingValue(opt));
    };
    let Some(value) = value.to_str() else {
        return Err(CliError::InvalidUTF(opt));
    };
    Ok(value.to_owned())
}

fn parse_size(value: &str) -> Result<usize, CliError> {
    let (num, multiplier): (&str, usize) = if let Some(digits) = value.strip_suffix("M") {
        (digits, 1 << 20)
    } else if let Some(digits) = value.strip_suffix("K") {
        (digits, 1 << 10)
    } else {
        (value, 1)
    };
    let n = num
        .parse::<usize>()
        .map_err(|_| CliError::InvalidSize(value.to_owned()))?;
    let n = n
        .checked_mul(multiplier)
        .ok_or_else(|| CliError::InvalidSize(value.to_owned()))?;
    if !n.is_power_of_two() || !(MIN_SIZE..=MAX_SIZE).contains(&n) {
        return Err(CliError::InvalidSize(value.to_owned()));
    }
    Ok(n)
}

fn parse_stride(value: &str) -> Result<usize, CliError> {
    let n = value
        .parse::<usize>()
        .map_err(|_| CliError::InvalidStride(value.to_owned()))?;
    if !(1..=64).contains(&n) {
        return Err(CliError::InvalidStride(value.to_owned()));
    }
    Ok(n)
}

fn write_mountain(
    out: &mut impl Write,
    data: &[u64],
    max_size: usize,
    max_stride: usize,
) -> io::Result<()> {
    write!(out, "size")?;
    for i in 1..=max_stride {
        write!(out, ",s{i}")?;
    }
    writeln!(out)?;
    for e in MIN_SIZE.trailing_zeros()..=max_size.trailing_zeros() {
        let s = 1usize << e;
        write!(out, "{s}")?;
        for k in 1..=max_stride {
            write!(out, ",{:.0}", measure::throughput(&data[..s / 8], k))?;
        }
        writeln!(out)?;
    }
    Ok(())
}
