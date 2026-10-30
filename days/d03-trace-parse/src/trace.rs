use core::fmt;

#[derive(Debug, PartialEq)]
pub enum ParseError {
    InvalidLine,
    InvalidOperation(String),
    MissingSize,
    MissingComma(String),
    InvalidAddress(String),
    InvalidSize(String),
}

impl fmt::Display for ParseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidLine => write!(f, "expected \'<op> <address>,<size>\'"),
            Self::InvalidOperation(op) => write!(f, "unknown operation \'{op}\'"),
            Self::MissingSize => write!(f, "missing size"),
            Self::MissingComma(addr) => write!(f, "missing \',\' in \'{addr}\'"),
            Self::InvalidAddress(addr) => write!(f, "invalid address \'{addr}\'"),
            Self::InvalidSize(size) => write!(f, "invalid size \'{size}\'"),
        }
    }
}

impl std::error::Error for ParseError {}

#[derive(Debug, PartialEq)]
pub enum Op {
    Instr,
    Load,
    Store,
    Modify,
}

#[derive(Debug, PartialEq)]
pub struct Access {
    pub op: Op,
    pub addr: u64,
    pub size: u64,
}

pub fn parse_line(line: &str) -> Result<Option<Access>, ParseError> {
    if line.trim_start().starts_with("==") {
        return Ok(None);
    }
    let mut parts = line.split_whitespace();
    let Some(op) = parts.next() else {
        return Ok(None);
    };
    let (addr, size_s) = parts
        .next()
        .ok_or(ParseError::InvalidLine)?
        .split_once(",")
        .ok_or_else(|| ParseError::MissingComma(line.to_owned()))?;
    if parts.next().is_some() {
        return Err(ParseError::InvalidLine);
    }
    let op = match op {
        "I" => Op::Instr,
        "L" => Op::Load,
        "S" => Op::Store,
        "M" => Op::Modify,
        _ => {
            return Err(ParseError::InvalidOperation(op.to_owned()));
        }
    };
    if size_s.is_empty() {
        return Err(ParseError::MissingSize);
    }
    let addr =
        u64::from_str_radix(addr, 16).map_err(|_| ParseError::InvalidAddress(addr.to_owned()))?;
    let size = size_s
        .parse::<u64>()
        .map_err(|_| ParseError::InvalidSize(size_s.to_owned()))?;
    if size == 0 {
        return Err(ParseError::InvalidSize(size_s.to_owned()));
    }
    Ok(Some(Access { op, addr, size }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn line_i_is_worked() {
        let line = "I  100,10";
        assert_eq!(
            parse_line(line),
            Ok(Some(Access {
                op: Op::Instr,
                addr: 0x100u64,
                size: 10,
            }))
        );
    }
    #[test]
    fn skipped_line() {
        let line = "==test==";
        assert_eq!(parse_line(line), Ok(None));
    }
    #[test]
    fn wrong_line() {
        let line = "L  2ab,10  I 2aa,11";
        assert_eq!(parse_line(line), Err(ParseError::InvalidLine));
    }
    #[test]
    fn data_line() {
        let line = "L  2ab,10";
        assert_eq!(
            parse_line(line),
            Ok(Some(Access {
                op: Op::Load,
                addr: 683,
                size: 10
            }))
        );
    }
    #[test]
    fn empty_line() {
        let line = "";
        assert_eq!(parse_line(line), Ok(None));
    }
}
