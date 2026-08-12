use std::error::Error;
use std::io;
use std::sync::Arc;
use std::time::Instant;

use reqwest::Client;
use serde_json::json;
use tokio::sync::Semaphore;

use alphax_rust_http::fetch;

#[derive(Debug, Clone)]
struct Options {
    url: String,
    requests: usize,
    concurrency: usize,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let options = parse_options(std::env::args().skip(1))
        .map_err(|message| io::Error::new(io::ErrorKind::InvalidInput, message))?;
    let client = Client::builder().http2_adaptive_window(true).build()?;
    let semaphore = Arc::new(Semaphore::new(options.concurrency));
    let started = Instant::now();
    let mut tasks = Vec::with_capacity(options.requests);

    for _ in 0..options.requests {
        let permit = Arc::clone(&semaphore).acquire_owned().await?;
        let client = client.clone();
        let url = options.url.clone();
        tasks.push(tokio::spawn(async move {
            let _permit = permit;
            fetch(&client, &url).await
        }));
    }

    let mut samples = Vec::with_capacity(options.requests);
    for task in tasks {
        samples.push(task.await??);
    }
    samples.sort_by(|left, right| left.total_ms.total_cmp(&right.total_ms));
    let total_bytes: u64 = samples.iter().map(|sample| sample.bytes_received).sum();
    let total_ms: f64 = samples.iter().map(|sample| sample.total_ms).sum();
    let statuses = samples.iter().fold(serde_json::Map::new(), |mut result, sample| {
        let key = sample.status_code.to_string();
        let count = result.get(&key).and_then(|value| value.as_u64()).unwrap_or(0) + 1;
        result.insert(key, json!(count));
        result
    });
    let p50 = samples[samples.len() / 2].total_ms;
    let output = json!({
        "client": "rust_reqwest",
        "url": options.url,
        "requests": samples.len(),
        "concurrency": options.concurrency,
        "bytes_received": total_bytes,
        "status_counts": statuses,
        "elapsed_ms": {
            "min": samples.first().map(|sample| sample.total_ms),
            "p50": p50,
            "max": samples.last().map(|sample| sample.total_ms),
            "average": total_ms / samples.len() as f64,
            "wall": started.elapsed().as_secs_f64() * 1000.0,
        }
    });
    println!("{}", serde_json::to_string_pretty(&output)?);
    Ok(())
}

fn parse_options<I>(args: I) -> Result<Options, String>
where
    I: IntoIterator<Item = String>,
{
    let mut args = args.into_iter();
    let mut url = String::from("http://127.0.0.1:8080/bytes/1024");
    let mut requests = 1;
    let mut concurrency = 1;
    while let Some(argument) = args.next() {
        match argument.as_str() {
            "--url" => url = args.next().ok_or("--url requires a value")?,
            "--requests" => {
                requests = args
                    .next()
                    .ok_or("--requests requires a value")?
                    .parse()
                    .map_err(|_| String::from("--requests must be a positive integer"))?;
            }
            "--concurrency" => {
                concurrency = args
                    .next()
                    .ok_or("--concurrency requires a value")?
                    .parse()
                    .map_err(|_| String::from("--concurrency must be a positive integer"))?;
            }
            "--help" => {
                println!("Usage: alphax_rust_http [--url URL] [--requests N] [--concurrency N]");
                std::process::exit(0);
            }
            other => return Err(format!("unknown argument: {other}")),
        }
    }
    if requests == 0 || concurrency == 0 {
        return Err(String::from("requests and concurrency must be positive"));
    }
    Ok(Options {
        url,
        requests,
        concurrency,
    })
}

#[cfg(test)]
mod tests {
    use super::parse_options;

    #[test]
    fn parses_shared_benchmark_options() {
        let options = parse_options(
            [
                String::from("--url"),
                String::from("https://example.com"),
                String::from("--requests"),
                String::from("4"),
                String::from("--concurrency"),
                String::from("2"),
            ]
            .into_iter(),
        )
        .expect("valid options");
        assert_eq!(options.url, "https://example.com");
        assert_eq!(options.requests, 4);
        assert_eq!(options.concurrency, 2);
    }
}
