use core::fmt;
use lru_set::set::{CacheSet, Outcome};
use std::{
    ffi::{OsStr, OsString},
    io::{self, BufWriter, Write},
    process::ExitCode,
};

enum CliError {
    Usage,
    InvalidValue(String),
    InvalidTag(String),
    Write(io::Error),
}

impl fmt::Display for CliError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Usage => write!(f, "usage: lru-set -E <lines> [<tag>...]"),
            Self::InvalidValue(s) => write!(f, "-E: invalid number of lines '{s}'"),
            Self::InvalidTag(s) => write!(f, "invalid tag '{s}'"),
            Self::Write(e) => write!(f, "write error: {e}"),
        }
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(_) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("lru-set: {e}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), CliError> {
    let (lines, tags) = parse_args(std::env::args_os().skip(1))?;
    let mut out = BufWriter::new(io::stdout().lock());
    let mut cache = CacheSet::new(lines);
    simulate(&mut out, &mut cache, &tags).map_err(CliError::Write)?;
    out.flush().map_err(CliError::Write)?;
    Ok(())
}

fn parse_args(mut args: impl Iterator<Item = OsString>) -> Result<(usize, Vec<u64>), CliError> {
    if args.next().as_deref() != Some(OsStr::new("-E")) {
        return Err(CliError::Usage);
    }
    let Some(lines) = args.next() else {
        return Err(CliError::Usage);
    };
    let lines: usize = lines
        .to_str()
        .and_then(|s| s.parse::<usize>().ok())
        .filter(|n| (1..=65536).contains(n))
        .ok_or_else(|| CliError::InvalidValue(lines.to_string_lossy().into_owned()))?;
    let tags: Vec<u64> = args
        .map(|a| {
            a.to_str()
                .ok_or_else(|| CliError::InvalidTag(a.to_string_lossy().into_owned()))
                .and_then(|s| {
                    s.parse::<u64>()
                        .map_err(|_| CliError::InvalidTag(s.to_owned()))
                })
        })
        .collect::<Result<Vec<u64>, CliError>>()?;
    Ok((lines, tags))
}

fn simulate(out: &mut impl Write, cache: &mut CacheSet, tags: &[u64]) -> Result<(), io::Error> {
    let (mut hit_count, mut miss_count, mut evictions): (u64, u64, u64) = (0, 0, 0);
    for &tag in tags {
        match cache.access(tag) {
            Outcome::Hit => {
                hit_count += 1;
                writeln!(out, "{} hit", tag)?
            }
            Outcome::Miss => {
                miss_count += 1;
                writeln!(out, "{} miss", tag)?
            }
            Outcome::MissEvict { victim } => {
                miss_count += 1;
                evictions += 1;
                writeln!(out, "{} miss eviction {}", tag, victim)?
            }
        }
    }
    writeln!(
        out,
        "hits:{hit_count} misses:{miss_count} evictions:{evictions}"
    )?;
    Ok(())
}
