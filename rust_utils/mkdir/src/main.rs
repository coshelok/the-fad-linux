use std::fs;
use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("mkdir: missing operand");
        std::process::exit(1);
    }

    let mut recursive = false;
    let mut paths = Vec::new();

    for arg in &args[1..] {
        if arg == "-p" {
            recursive = true;
        } else {
            paths.push(arg);
        }
    }

    for path in paths {
        let result = if recursive {
            fs::create_dir_all(path)
        } else {
            fs::create_dir(path)
        };

        if let Err(e) = result {
            eprintln!("mkdir: cannot create directory {}: {}", path, e);
        }
    }
}
