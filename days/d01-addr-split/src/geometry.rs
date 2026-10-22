pub struct Geometry {
    pub m: u32, // 1 <= m <= 64
    pub s: u32, // >= 0
    pub e: u64, // >= 1
    pub b: u32, // >= 0
}
#[derive(Debug, PartialEq)]
pub struct Parts {
    pub tag: u64,
    pub set: u64,
    pub offset: u64,
}

impl Geometry {
    pub fn split(&self, mut addr: u64) -> Parts {
        let offset = slice_addr(&mut addr, self.b);
        let set = slice_addr(&mut addr, self.s);
        let tag = addr;
        Parts { offset, set, tag }
    }
}

fn slice_addr(addr: &mut u64, slice_bits: u32) -> u64 {
    let field = match 1u64.checked_shl(slice_bits) {
        Some(bits) => (bits - 1) & *addr,
        None => *addr,
    };
    *addr = addr.checked_shr(slice_bits).unwrap_or_default();
    field
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn split_small_address() {
        let case = Geometry {
            m: 8,
            s: 3,
            e: 1,
            b: 4,
        };
        assert_eq!(
            case.split(0xab),
            Parts {
                tag: 0b1,
                set: 0b010,
                offset: 0b1011
            }
        )
    }
    #[test]
    fn no_set_bits() {
        let case = Geometry {
            m: 8,
            s: 0,
            e: 1,
            b: 4,
        };
        assert_eq!(
            case.split(0xab),
            Parts {
                tag: 0xa,
                set: 0,
                offset: 0xb
            }
        )
    }
    #[test]
    fn no_tag_bits() {
        let case = Geometry {
            m: 8,
            s: 4,
            e: 1,
            b: 4,
        };
        assert_eq!(
            case.split(0xab),
            Parts {
                tag: 0,
                set: 0xa,
                offset: 0xb
            }
        )
    }
    #[test]
    fn large_one_bits() {
        let case = Geometry {
            m: 64,
            s: 64,
            e: 1,
            b: 0,
        };
        assert_eq!(
            case.split(0xab),
            Parts {
                tag: 0,
                set: 0xab,
                offset: 0
            }
        )
    }
}
