#[derive(Debug, PartialEq)]
pub enum Outcome {
    ///태그가 세트에 있었을 때
    Hit,
    ///태그가 없었고, 빈 줄에 넣었을 때
    Miss,
    ///태그가 없었고, 빈 줄이 없어서 LRU줄을 쫒아내고 넣은 경우, victim은 쫒겨난 줄
    MissEvict { victim: u64 },
}

pub struct CacheSet {
    //line_set: Vec<Line>,
    /// Vec와 Option으로 캐시의 LRU 순서 및 사용 여부를 표현
    lru_list: Vec<Option<u64>>,
}

impl CacheSet {
    /// CacheSet 생성자, lines가 0인 경우는 이전에 처리해서 오류취급 안함.
    pub fn new(lines: usize) -> Self {
        Self {
            lru_list: vec![None; lines],
        }
    }
    /// CacheSet에 접근해서 업데이트하는 함수, Outcome으로 결과를 반환함
    pub fn access(&mut self, tag: u64) -> Outcome {
        if let Some(i) = self.lru_list.iter().position(|&line| line == Some(tag)) {
            self.lru_list.remove(i);
            self.lru_list.push(Some(tag));
            return Outcome::Hit;
        };
        if let Some(i) = self.lru_list.iter().position(|&line| line.is_none()) {
            self.lru_list.remove(i);
            self.lru_list.push(Some(tag));
            return Outcome::Miss;
        };
        let victim = self.lru_list.remove(0).expect("There are no empty line");
        self.lru_list.push(Some(tag));
        Outcome::MissEvict { victim }
    }
    /// 순서를 바꾸지 않고 존재 여부만 확인하는 함수.
    pub fn contains(&self, tag: u64) -> bool {
        self.lru_list.contains(&Some(tag))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn one_line_cache() {
        let mut cache = CacheSet::new(1);
        assert_eq!(cache.access(1), Outcome::Miss);
        let input: Vec<u64> = vec![0, 1, 0, 1, 0, 1];
        for x in input {
            assert_eq!(cache.access(x), Outcome::MissEvict { victim: 1 - x });
            assert_eq!(cache.contains(x), true);
        }
    }
    #[test]
    fn lru_hit() {
        let mut cache = CacheSet::new(2);
        let input: Vec<u64> = vec![0, 1, 0, 2];
        let output: Vec<Outcome> = vec![
            Outcome::Miss,
            Outcome::Miss,
            Outcome::Hit,
            Outcome::MissEvict { victim: 1 },
        ];
        for (x, o) in input.iter().zip(output) {
            assert_eq!(cache.access(*x), o);
            assert_eq!(cache.contains(*x), true);
        }
    }
    #[test]
    fn only_cold_miss() {
        let mut cache = CacheSet::new(4);
        let input: Vec<u64> = vec![0, 1, 3, 2];
        let output: Vec<Outcome> = vec![Outcome::Miss, Outcome::Miss, Outcome::Miss, Outcome::Miss];
        for (x, o) in input.iter().zip(output) {
            assert_eq!(cache.access(*x), o);
            assert_eq!(cache.contains(*x), true);
            assert!(cache.contains(*x));
        }
    }
}
