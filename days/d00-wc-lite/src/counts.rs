use std::ops::AddAssign;

#[derive(Debug, PartialEq)]
pub struct Counts {
    pub lines: u64,
    pub words: u64,
    pub bytes: u64,
}

impl Counts {
    pub fn from_bytes(data: &[u8]) -> Counts {
        let (mut lines, mut words, mut bytes): (u64, u64, u64) = (0, 0, 0);
        let mut word_flag: bool = false;
        for b in data {
            bytes += 1;
            if *b == b'\n' {
                lines += 1;
            }
            match *b {
                0x09..=0x0d | 0x20 => word_flag = false,
                0x21..=0x7e if !word_flag => {
                    word_flag = true;
                    words += 1;
                }
                _ => (),
            }
        }
        Counts {
            lines,
            words,
            bytes,
        }
    }
}

impl AddAssign for Counts {
    fn add_assign(&mut self, rhs: Self) {
        self.lines += rhs.lines;
        self.words += rhs.words;
        self.bytes += rhs.bytes;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn t1() {
        assert_eq!(
            Counts::from_bytes(b""),
            Counts {
                lines: 0,
                words: 0,
                bytes: 0
            }
        );
    }
    #[test]
    fn t2() {
        assert_eq!(
            Counts::from_bytes(b"123\n123"),
            Counts {
                lines: 1,
                words: 2,
                bytes: 7
            }
        );
    }
    #[test]
    fn t3() {
        assert_eq!(
            Counts::from_bytes(b"\t\x0c\x0b1\r2"),
            Counts {
                lines: 0,
                words: 2,
                bytes: 6
            }
        );
    }
}
