use clap::{Parser, Subcommand};
use colored::*;
use eyre::Result;

mod commands;
mod config;
mod utils;

use commands::*;

#[derive(Parser)]
#[command(name = "vector-plus")]
#[command(about = "Vector Plus - Advanced Trading Strategies for 1inch Limit Order Protocol")]
#[command(version = "0.1.0")]
#[command(author = "1inch Team")]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    /// Network to use (mainnet, polygon, arbitrum)
    #[arg(long, default_value = "mainnet")]
    network: String,

    /// Configuration file path
    #[arg(long, default_value = "vector-plus.json")]
    config: String,

    /// Verbose output
    #[arg(short, long)]
    verbose: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// Volatility-based execution strategies
    Volatility {
        #[command(subcommand)]
        command: VolatilityCommands,
    },
    /// Time-Weighted Average Price execution
    Twap {
        #[command(subcommand)]
        command: TwapCommands,
    },
    /// Options on limit order execution rights
    Options {
        #[command(subcommand)]
        command: OptionsCommands,
    },
    /// Combined TWAP + Volatility strategies
    Combined {
        #[command(subcommand)]
        command: CombinedCommands,
    },
    /// Configuration management
    Config {
        #[command(subcommand)]
        command: ConfigCommands,
    },
    /// Show examples and documentation
    Examples,
    /// Interactive strategy builder
    Interactive,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    
    // Print Vector Plus banner
    print_banner();

    // Execute command
    match cli.command {
        Commands::Volatility { ref command } => {
            commands::volatility::handle_command(command, &cli).await
        }
        Commands::Twap { ref command } => {
            commands::twap::handle_command(command, &cli).await
        }
        Commands::Options { ref command } => {
            commands::options::handle_command(command, &cli).await
        }
        Commands::Combined { ref command } => {
            commands::combined::handle_command(command, &cli).await
        }
        Commands::Config { ref command } => {
            commands::config::handle_command(command, &cli).await
        }
        Commands::Examples => {
            commands::examples::show_examples().await
        }
        Commands::Interactive => {
            commands::interactive::run_interactive_mode(&cli).await
        }
    }
}

fn print_banner() {
    println!("{}", "╔════════════════════════════════════════════════════════╗".bright_blue());
    println!("{}", "║                    VECTOR PLUS                        ║".bright_blue());
    println!("{}", "║            Advanced Trading Strategies CLI            ║".bright_blue());
    println!("{}", "║                 for 1inch Protocol                    ║".bright_blue());
    println!("{}", "╚════════════════════════════════════════════════════════╝".bright_blue());
    println!();
}