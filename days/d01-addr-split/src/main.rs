use core::fmt;
use std::error::Error;
use std::ffi::OsString;
use std::io::{BufWriter, Write};
use std::str::FromStr;
use std::{io, process::ExitCode};

use crate::geometry::Geometry;
mod geometry;

#[derive(Debug)]
enum CliError {
    Usage,
    UnknownOption(String),
    MissingValue(&'static str),
    MissingOption(&'static str),
    InvalidValue {
        option: &'static str,
        value: String,
    },
    TooManyBits {
        set_bits: u32,
        block_bits: u32,
        addr_bits: u32,
    },
    InvalidAddress(String),
    AddressTooWide {
        addr: u64,
        addr_bits: u32,
    },
    Write(io::Error),
}

impl fmt::Display for CliError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Usage => write!(
                f,
                "usage: addr-split <address> -s <s> -E <E> -b <b> [-m <m>]"
            ),
            Self::UnknownOption(option) => write!(f, "unknown option \'{option}\'"),
            Self::MissingValue(option) => write!(f, "{option} needs a value"),
            Self::MissingOption(option) => write!(f, "missing {option}"),
            Self::InvalidValue { option, value } => {
                write!(f, "{option}: invalid value \'{value}\'")
            }
            Self::TooManyBits {
                set_bits,
                block_bits,
                addr_bits,
            } => write!(
                f,
                "s + b exceeds m (s={set_bits}, b={block_bits}, m={addr_bits})"
            ),
            Self::InvalidAddress(addr) => write!(f, "invalid address \'{addr}\'"),
            Self::AddressTooWide { addr, addr_bits } => {
                write!(f, "address {addr:#x} does not fit in m={addr_bits} bits")
            }
            Self::Write(e) => write!(f, "write error: {e}"),
        }
    }
}

impl std::error::Error for CliError {}

fn main() -> ExitCode {
    match run() {
        Ok(_) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("addr-split: {e}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<bool, Box<dyn Error>> {
    let (addr, geometry) = parse_args(std::env::args_os().skip(1))?;
    let mut out = BufWriter::new(io::stdout().lock());
    dump(addr, &geometry, &mut out)?;
    out.flush().map_err(CliError::Write)?;
    Ok(true)
}

fn parse_args(
    mut args: impl Iterator<Item = OsString>,
) -> Result<(u64, geometry::Geometry), CliError> {
    let (mut set_bits, mut block_bits, mut lines_per_set, mut addr_bits): (
        Option<u32>,
        Option<u32>,
        Option<u64>,
        u32,
    ) = (None, None, None, 64);
    let mut addr: Option<String> = None;
    while let Some(arg) = args.next() {
        match arg.to_str() {
            Some("-s") => set_bits = Some(parse_value("-s", args.next())?),
            Some("-E") => lines_per_set = Some(parse_value("-E", args.next())?),
            Some("-b") => block_bits = Some(parse_value("-b", args.next())?),
            Some("-m") => addr_bits = parse_value("-m", args.next())?,
            Some(opt) if opt.starts_with('-') => {
                return Err(CliError::UnknownOption(opt.to_owned()));
            }
            Some(s) if addr.is_none() => addr = Some(s.to_owned()),
            None => return Err(CliError::InvalidAddress(arg.to_string_lossy().into_owned())),
            Some(_) => return Err(CliError::Usage),
        }
    }
    let addr = addr.ok_or(CliError::Usage)?;
    let set_bits = set_bits.ok_or(CliError::MissingOption("-s"))?;
    let block_bits = block_bits.ok_or(CliError::MissingOption("-b"))?;
    let lines_per_set = lines_per_set.ok_or(CliError::MissingOption("-E"))?;
    if lines_per_set == 0 {
        return Err(CliError::InvalidValue {
            option: "-E",
            value: lines_per_set.to_string(),
        });
    }
    if addr_bits > 64 || addr_bits == 0 {
        return Err(CliError::InvalidValue {
            option: "-m",
            value: addr_bits.to_string(),
        });
    }
    match (set_bits as u64).checked_add(block_bits as u64) {
        Some(sum) if sum > addr_bits as u64 => {
            return Err(CliError::TooManyBits {
                set_bits,
                block_bits,
                addr_bits,
            });
        }
        None => {
            return Err(CliError::TooManyBits {
                set_bits,
                block_bits,
                addr_bits,
            });
        }
        _ => (),
    }
    let geometry = Geometry {
        m: addr_bits,
        s: set_bits,
        e: lines_per_set,
        b: block_bits,
    };
    let addr = parse_address(&addr)?;
    if (u128::from(addr) >> geometry.m) > 0 {
        return Err(CliError::AddressTooWide { addr, addr_bits });
    }
    Ok((addr, geometry))
}

fn parse_value<T: FromStr>(opt: &'static str, value: Option<OsString>) -> Result<T, CliError> {
    let Some(value) = value else {
        return Err(CliError::MissingValue(opt));
    };
    let Some(value) = value.to_str() else {
        return Err(CliError::InvalidValue {
            option: (opt),
            value: (value.to_string_lossy().into_owned()),
        });
    };
    let value = value.parse().map_err(|_| CliError::InvalidValue {
        option: (opt),
        value: (value.to_owned()),
    })?;
    Ok(value)
}

fn parse_address(addr: &str) -> Result<u64, CliError> {
    let (digits, radix) = match addr.split_at_checked(2) {
        Some(("0x" | "0X", rest)) => (rest, 16),
        _ => (addr, 10),
    };
    u64::from_str_radix(digits, radix).map_err(|_| CliError::InvalidAddress(addr.to_owned()))
}

fn dump(addr: u64, geometry: &Geometry, out: &mut impl Write) -> io::Result<()> {
    writeln!(out, "address {addr:#x} (m={})", geometry.m)?;
    let parts = geometry.split(addr);
    writeln!(
        out,
        "bits    {}|{}|{}",
        format_bits(parts.tag, (geometry.m - geometry.s - geometry.b) as usize),
        format_bits(parts.set, geometry.s as usize),
        format_bits(parts.offset, geometry.b as usize),
    )?;
    writeln!(
        out,
        "tag     {:#x} (t={})",
        parts.tag,
        geometry.m - geometry.s - geometry.b
    )?;
    writeln!(out, "set     {:#x} (s={})", parts.set, geometry.s)?;
    writeln!(out, "offset  {:#x} (b={})", parts.offset, geometry.b)?;
    writeln!(
        out,
        "cache   S={} E={} B={} C={}",
        1u128 << geometry.s,
        geometry.e,
        1u128 << geometry.b,
        (1u128 << (geometry.s + geometry.b)) * u128::from(geometry.e)
    )?;
    Ok(())
}

fn format_bits(value: u64, width: usize) -> String {
    if width == 0 {
        return String::from("");
    }
    format!("{:0width$b}", value)
}
