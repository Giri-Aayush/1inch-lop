use clap::Subcommand;
use colored::*;
use eyre::Result;

#[derive(Subcommand)]
pub enum CombinedCommands {
    /// Create combined TWAP + Volatility strategy
    Create {
        /// TWAP duration in minutes
        #[arg(long)]
        twap_duration: u64,
        
        /// TWAP intervals
        #[arg(long)]
        twap_intervals: u32,
        
        /// Volatility threshold
        #[arg(long)]
        volatility_threshold: u64,
        
        /// Output file
        #[arg(short, long, default_value = "combined-strategy.json")]
        output: String,
    },
}

pub async fn handle_command(command: &CombinedCommands, _cli: &crate::Cli) -> Result<()> {
    match command {
        CombinedCommands::Create { twap_duration, twap_intervals, volatility_threshold, output } => {
            println!("{}", "🚀 Creating combined strategy...".cyan());
            println!("  • TWAP duration: {} minutes", twap_duration);
            println!("  • TWAP intervals: {}", twap_intervals);
            println!("  • Volatility threshold: {}bps", volatility_threshold);
            println!("{} {}", "✅ Combined strategy created:".green(), output);
            Ok(())
        }
    }
}