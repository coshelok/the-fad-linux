use std::fs;
use std::env;
use std::io::{self, Read, Write};

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("cat: missing file operand");
        std::process::exit(1);
    }

    for filename in &args[1..] {
        match fs::File::open(filename) {
            Ok(mut file) => {
                let mut buffer = [0u8; 8192];
                loop {
                    match file.read(&mut buffer) {
                        Ok(0) => break,
                        Ok(n) => {
                            if let Err(e) = io::stdout().write_all(&buffer[..n]) {
                                eprintln!("cat: error writing to stdout: {}", e);
                                break;
                            }
                        }
                        Err(e) => {
                            eprintln!("cat: {}: {}", filename, e);
                            break;
                        }
                    }
                }
            }
            Err(e) => eprintln!("cat: cannot open {}: {}", filename, e),
        }
    }
}
