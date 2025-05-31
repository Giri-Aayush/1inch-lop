use dialoguer::{theme::ColorfulTheme, Select, Input, Confirm};
use colored::*;
use eyre::Result;

pub async fn run_interactive_mode(_cli: &crate::Cli) -> Result<()> {
    println!("{}", "🎯 Vector Plus Interactive Mode".cyan().bold());
    println!();

    let strategies = vec![
        "🌊 Volatility-based execution",
        "🕒 TWAP execution", 
        "📞 Options on execution rights",
        "🚀 Combined TWAP + Volatility",
        "⚙️  Configuration management",
        "❌ Exit"
    ];

    let selection = Select::with_theme(&ColorfulTheme::default())
        .with_prompt("What would you like to create?")
        .items(&strategies)
        .default(0)
        .interact()?;

    match selection {
        0 => build_volatility_strategy().await,
        1 => build_twap_strategy().await,
        2 => build_options_strategy().await,
        3 => build_combined_strategy().await,
        4 => manage_configuration().await,
        _ => {
            println!("{}", "👋 Goodbye!".green());
            Ok(())
        }
    }
}

async fn build_volatility_strategy() -> Result<()> {
    println!("{}", "🌊 Building Volatility Strategy".blue().bold());
    println!();
    
    let baseline: u64 = Input::with_theme(&ColorfulTheme::default())
        .with_prompt("Baseline volatility (basis points)")
        .default(300)
        .interact()?;
    
    let current: u64 = Input::with_theme(&ColorfulTheme::default())
        .with_prompt("Current volatility (basis points)")
        .default(350)
        .interact()?;
    
    let max_size: f64 = Input::with_theme(&ColorfulTheme::default())
        .with_prompt("Maximum execution size (ETH)")
        .default(5.0)
        .interact()?;
    
    let conservative = Confirm::with_theme(&ColorfulTheme::default())
        .with_prompt("Enable conservative mode?")
        .default(false)
        .interact()?;
    
    println!();
    println!("{}", "✅ Volatility strategy configured!".green());
    println!("📁 Run: vector-plus volatility create-config \\");
    println!("       --baseline-volatility {} \\", baseline);
    println!("       --current-volatility {} \\", current);
    println!("       --max-execution-size {} {}", max_size, if conservative { "\\" } else { "" });
    if conservative {
        println!("       --conservative-mode");
    }
    
    Ok(())
}

async fn build_twap_strategy() -> Result<()> {
    println!("{}", "🕒 Building TWAP Strategy".blue().bold());
    println!();
    
    let duration: u64 = Input::with_theme(&ColorfulTheme::default())
        .with_prompt("Execution duration (minutes)")
        .default(120)
        .interact()?;
    
    let intervals: u32 = Input::with_theme(&ColorfulTheme::default())
        .with_prompt("Number of intervals")
        .default(12)
        .interact()?;
    
    let randomize = Confirm::with_theme(&ColorfulTheme::default())
        .with_prompt("Enable randomization?")
        .default(true)
        .interact()?;
    
    println!();
    println!("{}", "✅ TWAP strategy configured!".green());
    println!("📁 Run: vector-plus twap create-config \\");
    println!("       --duration {} \\", duration);
    println!("       --intervals {} {}", intervals, if randomize { "\\" } else { "" });
    if randomize {
        println!("       --randomize");
    }
    
    Ok(())
}

async fn build_options_strategy() -> Result<()> {
    println!("{}", "📞 Building Options Strategy".blue().bold());
    println!();
    
    let option_type = Select::with_theme(&ColorfulTheme::default())
        .with_prompt("Option type")
        .items(&["Call Option", "Put Option"])
        .default(0)
        .interact()?;
    
    let strike_price: f64 = Input::with_theme(&ColorfulTheme::default())
        .with_prompt("Strike price (USDC)")
        .default(2100.0)
        .interact()?;
    
    let expiration: u64 = Input::with_theme(&ColorfulTheme::default())
        .with_prompt("Expiration (hours)")
        .default(168)
        .interact()?;
    
    let premium: f64 = Input::with_theme(&ColorfulTheme::default())
        .with_prompt("Premium (USDC)")
        .default(50.0)
        .interact()?;
    
    println!();
    println!("{}", "✅ Options strategy configured!".green());
    println!("📁 Run: vector-plus options create-{} \\", if option_type == 0 { "call" } else { "put" });
    println!("       --strike-price {} \\", strike_price);
    println!("       --expiration-hours {} \\", expiration);
    println!("       --premium {}", premium);
    
    Ok(())
}

async fn build_combined_strategy() -> Result<()> {
    println!("{}", "🚀 Building Combined Strategy".blue().bold());
    println!();
    
    let twap_duration: u64 = Input::with_theme(&ColorfulTheme::default())
        .with_prompt("TWAP duration (minutes)")
        .default(180)
        .interact()?;
    
    let twap_intervals: u32 = Input::with_theme(&ColorfulTheme::default())
        .with_prompt("TWAP intervals")
        .default(18)
        .interact()?;
    
    let volatility_threshold: u64 = Input::with_theme(&ColorfulTheme::default())
        .with_prompt("Volatility threshold (basis points)")
        .default(600)
        .interact()?;
    
    println!();
    println!("{}", "✅ Combined strategy configured!".green());
    println!("📁 Run: vector-plus combined create \\");
    println!("       --twap-duration {} \\", twap_duration);
    println!("       --twap-intervals {} \\", twap_intervals);
    println!("       --volatility-threshold {}", volatility_threshold);
    
    Ok(())
}

async fn manage_configuration() -> Result<()> {
    println!("{}", "⚙️  Configuration Management".blue().bold());
    println!();
    
    let actions = vec![
        "Initialize new configuration",
        "Show current configuration",
        "Back to main menu"
    ];
    
    let selection = Select::with_theme(&ColorfulTheme::default())
        .with_prompt("What would you like to do?")
        .items(&actions)
        .default(0)
        .interact()?;
    
    match selection {
        0 => {
            println!("{}", "🔧 Run: vector-plus config init".green());
            Ok(())
        }
        1 => {
            println!("{}", "📋 Run: vector-plus config show".green());
            Ok(())
        }
        _ => Ok(())
    }
}