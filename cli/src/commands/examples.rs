use colored::*;
use eyre::Result;

pub async fn show_examples() -> Result<()> {
    println!("{}", "📚 Vector Plus Examples".cyan().bold());
    println!();
    
    println!("{}", "🌊 Volatility Strategy Examples:".yellow().bold());
    println!("  {} vector-plus volatility create-config --current-volatility 500 --conservative-mode", "•".blue());
    println!("  {} vector-plus volatility validate volatility-config.json", "•".blue());
    println!("  {} vector-plus volatility calculate --amount 2.5 --config volatility-config.json", "•".blue());
    println!();
    
    println!("{}", "🕒 TWAP Strategy Examples:".yellow().bold());
    println!("  {} vector-plus twap create-config --duration 120 --intervals 12 --randomize", "•".blue());
    println!("  {} vector-plus twap simulate --order-size 10.0 --config twap-config.json", "•".blue());
    println!();
    
    println!("{}", "📞 Options Strategy Examples:".yellow().bold());
    println!("  {} vector-plus options create-call --strike-price 2100 --expiration-hours 168 --premium 50", "•".blue());
    println!("  {} vector-plus options premium --current-price 2000 --strike-price 2100 --time-to-expiration 24", "•".blue());
    println!();
    
    println!("{}", "🚀 Combined Strategy Examples:".yellow().bold());
    println!("  {} vector-plus combined create --twap-duration 180 --twap-intervals 18 --volatility-threshold 600", "•".blue());
    println!();
    
    println!("{}", "⚙️  Configuration Examples:".yellow().bold());
    println!("  {} vector-plus config init --force", "•".blue());
    println!("  {} vector-plus config show", "•".blue());
    println!("  {} vector-plus --network polygon --verbose volatility create-config", "•".blue());
    println!();
    
    println!("{}", "💡 Pro Tips:".green().bold());
    println!("  {} Use --verbose flag for detailed output", "•".cyan());
    println!("  {} All configs are saved as JSON files for easy editing", "•".cyan());
    println!("  {} Run 'vector-plus interactive' for guided setup", "•".cyan());
    
    Ok(())
}