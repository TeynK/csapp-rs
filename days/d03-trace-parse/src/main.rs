use core::fmt;
use std::error::Error;
use std::ffi::OsString;
use std::fs::File;
use std::io::{self, BufRead, BufReader};
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use crate::trace::ParseError;

mod trace;

#[derive(Debug)]
enum CliError {
    Usage,
    Read {
        path: PathBuf,
        error: io::Error,
    },
    Parse {
        path: PathBuf,
        line: usize,
        error: ParseError,
    },
    Write(io::Error),
}

impl fmt::Display for CliError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Usage => write!(f, "usage: trace-parse <trace-file>"),
            Self::Read { path, error } => write!(f, "{}: {error}", path.display()),
            Self::Parse { path, line, error } => write!(f, "{}:{line}: {error}", path.display()),
            Self::Write(e) => write!(f, "{e}"),
        }
    }
}

impl std::error::Error for CliError {}

struct Summary {
    instr: u64,
    load: u64,
    store: u64,
    modify: u64,
    min: Option<u64>,
    max: Option<u64>,
}

impl Summary {
    fn count(&mut self, other: trace::Access) {
        match other.op {
            trace::Op::Instr => {
                self.instr += 1;
                return;
            }
            trace::Op::Load => {
                self.load += 1;
            }
            trace::Op::Modify => {
                self.modify += 1;
            }
            trace::Op::Store => {
                self.store += 1;
            }
        }
        match self.min {
            Some(_) => self.min = self.min.min(Some(other.addr)),
            None => self.min = Some(other.addr),
        }
        match self.max {
            Some(_) => self.max = self.max.max(Some(other.addr)),
            None => self.max = Some(other.addr),
        }
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("trace-parse: {e}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    // 인자 받아서 파싱
    let path = parse_path(std::env::args_os().skip(1))?;
    let summary = summarize(&path)?;
    let mut out = BufWriter::new(io::stdout().lock());
    dump(&mut out, &summary)?;
    out.flush().map_err(CliError::Write)?;
    Ok(())
}

fn parse_path(args: impl Iterator<Item = OsString>) -> Result<PathBuf, CliError> {
    let mut path: Option<PathBuf> = None;
    for arg in args {
        match arg.to_str() {
            Some(s) if s.starts_with("-") => return Err(CliError::Usage),
            Some(_) if path.is_none() => path = Some(PathBuf::from(arg)),
            _ => return Err(CliError::Usage),
        }
    }
    let Some(path) = path else {
        return Err(CliError::Usage);
    };
    Ok(path)
}

fn summarize(path: &Path) -> Result<Summary, Box<dyn Error>> {
    let reader = BufReader::new(File::open(path).map_err(|e| CliError::Read {
        path: path.to_owned(),
        error: e,
    })?);
    let mut summary = Summary {
        instr: 0,
        load: 0,
        store: 0,
        modify: 0,
        min: None,
        max: None,
    };
    for (i, line) in reader.lines().enumerate() {
        let line = line.map_err(|e| CliError::Read {
            path: path.to_owned(),
            error: e,
        })?;
        let access = trace::parse_line(&line).map_err(|e| CliError::Parse {
            path: path.to_owned(),
            line: i + 1,
            error: e,
        })?;
        if let Some(a) = access {
            summary.count(a);
        }
    }
    Ok(summary)
}

fn dump(out: &mut impl Write, summary: &Summary) -> Result<(), io::Error> {
    writeln!(out, "instr {}", summary.instr)?;
    writeln!(out, "load {}", summary.load)?;
    writeln!(out, "store {}", summary.store)?;
    writeln!(out, "modify {}", summary.modify)?;
    match summary.min {
        Some(x) => writeln!(out, "min {:#x}", x),
        None => writeln!(out, "min -"),
    }?;
    match summary.max {
        Some(x) => writeln!(out, "max {:#x}", x),
        None => writeln!(out, "max -"),
    }?;
    Ok(())
}
