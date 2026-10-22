use core::fmt;
use std::error::Error;
use std::ffi::OsString;
use std::fs;
use std::io::{BufWriter, Write};
use std::{io, path::PathBuf, process::ExitCode};

mod counts;

struct Options {
    line_flag: bool,
    word_flag: bool,
    count_flag: bool,
    pathes: Vec<PathBuf>,
}

#[derive(Debug)]
enum CliError {
    Usage,
    UnknownOption(String),
    Read { path: PathBuf, source: io::Error },
    Write(io::Error),
}

impl fmt::Display for CliError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Usage => write!(f, "usage: wc-lite [-l] [-w] [-c] <file>..."),
            Self::UnknownOption(opt) => write!(f, "unknown option: {opt}"),
            Self::Read { path, source } => write!(f, "{}: {source}", path.display()),
            Self::Write(source) => write!(f, "write error: {source}"),
        }
    }
}

impl std::error::Error for CliError {}

fn main() -> ExitCode {
    match run() {
        Ok(flag) => {
            if flag {
                ExitCode::FAILURE
            } else {
                ExitCode::SUCCESS
            }
        }
        Err(e) => {
            eprintln!("wc-lite: {e}");
            ExitCode::FAILURE
        } 
    }
}

fn run() -> Result<bool, Box<dyn Error>> {
    let opt: Options = parse_args(std::env::args_os().skip(1))?;
    let mut out = BufWriter::new(io::stdout().lock());
    let flag = dump(opt, &mut out).map_err(CliError::Write)?;
    out.flush().map_err(CliError::Write)?;
    Ok(flag)
}

fn parse_args(args: impl Iterator<Item = OsString>) -> Result<Options, CliError> {
    let mut pathes: Vec<PathBuf> = Vec::new();
    let (mut line_flag, mut word_flag, mut count_flag): (bool, bool, bool) = (false, false, false);
    for arg in args {
        match arg.to_str() {
            Some("-") => pathes.push(PathBuf::from("-")),
            Some(s) if let Some(s) = s.strip_prefix('-') => {
                parse_flags(s, &mut line_flag, &mut word_flag, &mut count_flag)?
            }
            _ => pathes.push(PathBuf::from(arg)),
        }
    }
    if pathes.is_empty() {
        return Err(CliError::Usage);
    }
    if !line_flag && !word_flag && !count_flag {
        (line_flag, word_flag, count_flag) = (true, true, true);
    }
    Ok(Options {
        line_flag,
        word_flag,
        count_flag,
        pathes,
    })
}

fn parse_flags(
    s: &str,
    line_flag: &mut bool,
    word_flag: &mut bool,
    count_flag: &mut bool,
) -> Result<(), CliError> {
    if s.chars().all(|c| matches!(c, 'l' | 'w' | 'c')) {
        if s.contains('l') {
            *line_flag = true;
        }
        if s.contains('w') {
            *word_flag = true;
        }
        if s.contains('c') {
            *count_flag = true;
        }
    } else {
        return Err(CliError::UnknownOption(s.to_owned()));
    }
    Ok(())
}

fn dump(
    Options {
        line_flag,
        word_flag,
        count_flag,
        pathes,
    }: Options,
    out: &mut impl Write,
) -> io::Result<bool> {
    let mut results: Vec<Result<counts::Counts, CliError>> = Vec::new();
    for path in &pathes {
        results.push(read_file(path));
    }
    let width = calculate_width(
        &pathes,
        usize::from(line_flag) + usize::from(word_flag) + usize::from(count_flag),
    );
    let mut total = counts::Counts {
        lines: 0,
        words: 0,
        bytes: 0,
    };
    let total_flag = results.len() != 1;
    let mut err_flag = false;
    for (path, result) in pathes.iter().zip(results) {
        match result {
            Ok(c) => {
                if line_flag {
                    write!(out, "{:>width$} ", c.lines)?;
                }
                if word_flag {
                    write!(out, "{:>width$} ", c.words)?;
                }
                if count_flag {
                    write!(out, "{:>width$} ", c.bytes)?;
                }
                writeln!(out, "{}", path.display())?;
                total += c;
            }
            Err(e) => {
                eprintln!("wc-lite: {e}");
                err_flag = true;
            }
        }
    }
    if total_flag {
        if line_flag {
            write!(out, "{:>width$} ", total.lines)?;
        }
        if word_flag {
            write!(out, "{:>width$} ", total.words)?;
        }
        if count_flag {
            write!(out, "{:>width$} ", total.bytes)?;
        }
        writeln!(out, "total")?;
    }
    Ok(err_flag)
}

fn read_file(path: &PathBuf) -> Result<counts::Counts, CliError> {
    let data = fs::read(path).map_err(|source| CliError::Read {
        path: path.to_owned(),
        source,
    })?;
    Ok(counts::Counts::from_bytes(&data))
}

fn calculate_width(pathes: &Vec<PathBuf>, flag_count: usize) -> usize {
    if pathes.len() == 1 && flag_count == 1 {
        return 1;
    }
    let mut flag = false;
    let mut sum = 0;
    for path in pathes {
        if let Ok(f) = fs::metadata(path) {
            if f.is_file() {
                sum += f.len() as usize;
            } else {
                flag = true;
            }
        }
    }
    sum = sum.to_string().len();
    if flag {
        sum = sum.max(7);
    }
    sum
}
