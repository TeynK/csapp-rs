struct Args {
    st: usize,
    len: usize,
    path: Option<String>,
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mut iter = args.iter().skip(1);
    let mut opt = Args {
        st: 0,
        len: usize::MAX,
        path: None,
    };
    while let Some(arg) = iter.next() {
        match arg.as_str() {
            flag @ ("-s" | "-l") => {
                match iter.next() {
                    Some(val) => match val.parse::<usize>() {
                        Ok(n) => match flag {
                            "-s" => opt.st = n,
                            _ => opt.len = n,
                        },
                        Err(_) => {
                            eprintln!("{flag}: It's not valid number.");
                            std::process::exit(1);
                        }
                    },
                    None => {
                        eprintln!("Need to write down valid number after {flag}.");
                        std::process::exit(1);
                    }
                };
            }
            s if s.starts_with('-') => {
                eprintln!("Unknown option: {}", s);
                std::process::exit(1);
            }
            path => {
                if opt.path.is_some() {
                    eprintln!("Only one file can be specified.");
                    std::process::exit(1);
                }
                opt.path = Some(path.to_string());
            }
        }
    }
    let path = match opt.path {
        Some(p) => p,
        None => {
            eprintln!("Usage: xxd-lite [-s start] [-l length] <file>");
            std::process::exit(1);
        }
    };

    let data: Vec<u8> = match std::fs::read(&path) {
        Ok(data) => data,
        Err(e) => {
            eprintln!("xxd-lite: {path}: {e}");
            std::process::exit(1);
        }
    };

    let start = opt.st.min(data.len());
    let end = start.saturating_add((opt.len).min(data.len()));
    let data = &data[start..end];
    for (i, chunk) in data.chunks(16).enumerate() {
        let offset = opt.st + i * 16;
        let mut line = String::new();
        let mut ascii = String::new();
        for (j, hex) in chunk.iter().enumerate() {
            if j % 2 == 0 && j != 0 {
                line.push(' ');
            }
            line.push_str(&format!("{:02x}", hex));
            ascii.push(match hex {
                0x20..=0x7e => *hex as char,
                _ => '.',
            });
        }
        println!("{:08x}: {:<39}  {}", offset, line, ascii);
    }
}
