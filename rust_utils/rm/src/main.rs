use std::env;
use std::fs;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("rm: missing operand");
        std::process::exit(1);
    }

    let mut recursive = false;
    let mut force = false;
    let mut files = Vec::new();

    for arg in &args[1..] {
        match arg.as_str() {
            "-r" | "-R" => recursive = true,
            "-f" => force = true,
            "-rf" | "-fr" | "-Rf" | "-fR" => { recursive = true; force = true; }
            _ => files.push(arg),
        }
    }

    'next: for path in files {
        let meta = fs::metadata(path);
        match meta {
            Ok(m) if m.is_dir() && !recursive => {
                eprintln!("rm: cannot remove '{}': Is a directory", path);
                continue 'next;
            }
            Ok(_) => {}
            Err(e) => {
                if !force {
                    eprintln!("rm: cannot remove '{}': {}", path, e);
                }
                continue 'next;
            }
        }

        let result = if recursive { fs::remove_dir_all(path) } else { fs::remove_file(path) };

        if let Err(e) = result {
            if !force {
                eprintln!("rm: cannot remove '{}': {}", path, e);
            }
        }
    }
}
