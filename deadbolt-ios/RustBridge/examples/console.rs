use serde_json::{Value, json};
use std::{
    io::{self, BufRead, Write},
    path::PathBuf,
};

fn main() -> anyhow::Result<()> {
    let dir = PathBuf::from(
        std::env::args_os()
            .nth(1)
            .ok_or_else(|| anyhow::anyhow!("Usage: deadbolt-test-peer DATA_DIRECTORY"))?,
    );
    let input = io::stdin();
    let mut output = io::stdout().lock();
    for line in input.lock().lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        let response = match serde_json::from_str::<Value>(&line) {
            Ok(mut request) if request.is_object() => {
                if request.get("data_dir").is_none() {
                    request["data_dir"] = json!(dir);
                }
                deadbolt_ios::request_json(&request.to_string())
            }
            Ok(_) => json!({"ok":false,"error":"Request must be a JSON object"}).to_string(),
            Err(error) => json!({"ok":false,"error":error.to_string()}).to_string(),
        };
        writeln!(output, "{response}")?;
        output.flush()?;
    }
    let _ = deadbolt_ios::request_json(&json!({"data_dir":dir,"op":"lock"}).to_string());
    Ok(())
}
