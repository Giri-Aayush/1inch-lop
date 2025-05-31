use clap::Subcommand;
use colored::*;
use eyre::Result;
use serde::{Deserialize, Serialize};
use std::fs;

#[derive(Subcommand)]
pub enum VolatilityCommands {
    /// Generate volatility configuration file
    CreateConfig {
        /// Baseline volatility in basis points
        #[arg(long, default_value = "300")]
        baseline_volatility: u64,
        
        /// Current market volatility in basis points
        #[arg(long, default_value = "350")]
        current_volatility: u64,
        
        /// Maximum execution size in ETH
        #[arg(long, default_value = "5.0")]
        max_execution_size: f64,
        
        /// Minimum execution size in ETH
        #[arg(long, default_value = "0.1")]
        min_execution_size: f64,
        
        /// Enable conservative mode
        #[arg(long)]
        conservative_mode: bool,
        
        /// Output file path
        #[arg(short, long, default_value = "volatility-config.json")]
        output: String,
    },
    
    /// Validate volatility configuration
    Validate {
        /// Configuration file to validate
        file: String,
    },
    
    /// Calculate volatility adjustment for given amount
    Calculate {
        /// Base amount in ETH
        #[arg(long)]
        amount: f64,
        
        /// Volatility config file
        #[arg(long, default_value = "volatility-config.json")]
        config: String,
    },
}

#[derive(Debug, Serialize, Deserialize)]
struct VolatilityConfig {
    baseline_volatility: u64,
    current_volatility: u64,
    max_execution_size: String,
    min_execution_size: String,
    volatility_threshold: u64,
    conservative_mode: bool,
    emergency_threshold: u64,
    last_update_time: u64,
}

pub async fn handle_command(command: &VolatilityCommands, _cli: &crate::Cli) -> Result<()> {
    match command {
        VolatilityCommands::CreateConfig { 
            baseline_volatility, 
            current_volatility, 
            max_execution_size,
            min_execution_size,
            conservative_mode,
            output 
        } => {
            create_volatility_config(
                *baseline_volatility,
                *current_volatility,
                *max_execution_size,
                *min_execution_size,
                *conservative_mode,
                output
            ).await
        }
        VolatilityCommands::Validate { file } => {
            validate_volatility_config(file).await
        }
        VolatilityCommands::Calculate { amount, config } => {
            calculate_volatility_adjustment(*amount, config).await
        }
    }
}

async fn create_volatility_config(
    baseline_volatility: u64,
    current_volatility: u64,
    max_execution_size: f64,
    min_execution_size: f64,
    conservative_mode: bool,
    output: &str,
) -> Result<()> {
    let config = VolatilityConfig {
        baseline_volatility,
        current_volatility,
        max_execution_size: format!("{:.18}", max_execution_size * 1e18),
        min_execution_size: format!("{:.18}", min_execution_size * 1e18),
        volatility_threshold: baseline_volatility * 2,
        conservative_mode,
        emergency_threshold: baseline_volatility * 4,
        last_update_time: chrono::Utc::now().timestamp() as u64,
    };

    let json = serde_json::to_string_pretty(&config)?;
    fs::write(output, json)?;

    println!("{} {}", "✅ Created volatility config:".green(), output.cyan());
    println!("📊 Baseline volatility: {}bps", baseline_volatility.to_string().yellow());
    println!("📈 Current volatility: {}bps", current_volatility.to_string().yellow());
    println!("💰 Max execution: {} ETH", max_execution_size.to_string().yellow());
    println!("🔒 Conservative mode: {}", if conservative_mode { "ON".green() } else { "OFF".red() });
    println!();
    println!("{}", "🚀 Next steps:".bold());
    println!("  {} vector-plus volatility validate {}", "•".blue(), output);
    println!("  {} vector-plus volatility calculate --amount 1.0 --config {}", "•".blue(), output);

    Ok(())
}

async fn validate_volatility_config(file: &str) -> Result<()> {
    println!("{} {}", "🔍 Validating volatility config:".cyan(), file.yellow());
    
    let content = fs::read_to_string(file)
        .map_err(|_| eyre::eyre!("Could not read file: {}", file))?;
    
    let config: VolatilityConfig = serde_json::from_str(&content)
        .map_err(|e| eyre::eyre!("Invalid JSON format: {}", e))?;
    
    let mut warnings = Vec::new();
    let mut errors = Vec::new();
    
    // Validation checks
    if config.current_volatility > config.baseline_volatility * 3 {
        warnings.push("⚠️  Current volatility is >3x baseline - consider conservative mode".yellow());
    }
    
    if config.current_volatility > config.emergency_threshold {
        errors.push("🚨 Current volatility exceeds emergency threshold!".red());
    }
    
    let max_size: f64 = config.max_execution_size.parse().unwrap_or(0.0);
    let min_size: f64 = config.min_execution_size.parse().unwrap_or(0.0);
    
    if max_size <= min_size {
        errors.push("❌ Max execution size must be > min execution size".red());
    }
    
    let age = chrono::Utc::now().timestamp() as u64 - config.last_update_time;
    if age > 3600 {
        warnings.push("⚠️  Configuration is more than 1 hour old".yellow());
    }
    
    // Print results
    if errors.is_empty() && warnings.is_empty() {
        println!("{}", "✅ Volatility configuration is valid!".green());
        println!("📊 Configuration summary:");
        println!("  • Baseline: {}bps", config.baseline_volatility);
        println!("  • Current: {}bps", config.current_volatility);
        println!("  • Threshold: {}bps", config.volatility_threshold);
        println!("  • Emergency: {}bps", config.emergency_threshold);
    } else {
        for warning in &warnings {
            println!("{}", warning);
        }
        for error in &errors {
            println!("{}", error);
        }
        if !errors.is_empty() {
            return Err(eyre::eyre!("Configuration validation failed"));
        }
    }
    
    Ok(())
}

async fn calculate_volatility_adjustment(amount: f64, config_file: &str) -> Result<()> {
    let content = fs::read_to_string(config_file)?;
    let config: VolatilityConfig = serde_json::from_str(&content)?;
    
    println!("{} {} ETH", "🧮 Calculating volatility adjustment for:".cyan(), amount.to_string().yellow());
    
    let adjustment_factor = if config.current_volatility <= config.baseline_volatility {
        // Low volatility: increase amount
        let boost = (config.baseline_volatility - config.current_volatility) * 50 / config.baseline_volatility;
        100 + std::cmp::min(boost, 50)
    } else if config.current_volatility > config.volatility_threshold {
        // High volatility: decrease amount
        let reduction = (config.current_volatility - config.baseline_volatility) * 50 / config.baseline_volatility;
        let reduction = std::cmp::min(reduction, 50);
        100 - reduction
    } else {
        // Normal volatility
        if config.conservative_mode { 90 } else { 100 }
    };
    
    let adjusted_amount = (amount * adjustment_factor as f64) / 100.0;
    let max_eth = config.max_execution_size.parse::<f64>().unwrap_or(0.0) / 1e18;
    let min_eth = config.min_execution_size.parse::<f64>().unwrap_or(0.0) / 1e18;
    
    let final_amount = adjusted_amount.max(min_eth).min(max_eth);
    
    println!("📊 Volatility Analysis:");
    println!("  • Baseline volatility: {}bps", config.baseline_volatility);
    println!("  • Current volatility: {}bps", config.current_volatility);
    println!("  • Adjustment factor: {}%", adjustment_factor);
    println!();
    println!("💰 Execution Amounts:");
    println!("  • Original amount: {} ETH", amount);
    println!("  • Adjusted amount: {} ETH", adjusted_amount);
    println!("  • Final amount: {} ETH", final_amount);
    println!("  • Min allowed: {} ETH", min_eth);
    println!("  • Max allowed: {} ETH", max_eth);
    
    if final_amount != adjusted_amount {
        if final_amount == max_eth {
            println!("{}", "⚠️  Amount capped at maximum limit".yellow());
        } else {
            println!("{}", "⚠️  Amount raised to minimum limit".yellow());
        }
    }
    
    Ok(())
}