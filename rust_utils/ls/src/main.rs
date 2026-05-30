use std::fs;
use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    let default_paths = vec![".".to_string()];
    let paths = if args.len() > 1 { &args[1..] } else { &default_paths[..] };

    for path in paths {
        match fs::read_dir(path) {
            Ok(entries) => {
                println!("{}:", path);
                for entry in entries {
                    if let Ok(e) = entry {
                        println!("  {}", e.file_name().to_string_lossy());
                    }
                }
            }
            Err(e) => eprintln!("ls: error reading directory {}: {}", path, e),
        }
    }
}
