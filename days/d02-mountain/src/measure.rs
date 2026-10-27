use std::hint::black_box;
use std::time::{Duration, Instant};

pub fn read_stride(data: &[u64], stride: usize) -> u64 {
    let mut sum: u64 = 0;
    for &x in data.iter().step_by(stride) {
        sum = sum.wrapping_add(x);
    }
    sum
}

pub fn throughput(data: &[u64], stride: usize) -> f64 {
    black_box(read_stride(black_box(data), stride));
    let mut repeat: u64 = 1;
    let mut consumed_time: Duration = Duration::ZERO;
    while consumed_time < Duration::from_millis(10) {
        let start = Instant::now();
        for _ in 0..repeat {
            black_box(read_stride(black_box(data), stride));
        }
        consumed_time = start.elapsed();
        repeat *= 2;
    }
    repeat /= 2;
    repeat as f64 * (data.len().div_ceil(stride) as f64 * 8f64) / consumed_time.as_secs_f64() / 1e6
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_elements() {
        let v: Vec<u64> = vec![1, 1, 1, 1, 1, 1, 1, 1];
        assert_eq!(read_stride(&v, 1), 8);
    }

    #[test]
    fn undivisible_stride() {
        let v: Vec<u64> = vec![1, 2, 4, 8, 16, 32, 64];
        assert_eq!(read_stride(&v, 3), 0b01001001);
    }

    #[test]
    fn overflow_element() {
        let v: Vec<u64> = vec![1, u64::MAX];
        assert_eq!(read_stride(&v, 1), 0);
    }
}
