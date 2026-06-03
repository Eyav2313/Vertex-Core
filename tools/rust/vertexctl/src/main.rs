use anyhow::Result;
use clap::{Parser, Subcommand};

#[derive(Debug, Parser)]
#[command(name = "vertexctl")]
#[command(about = "Vertex OS system control helper")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Print current tool and platform information.
    Status,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Command::Status => {
            println!("vertexctl 0.1.0");
            println!("channel: development");
            println!("desktop: vertex-glass");
        }
    }

    Ok(())
}
