use eyre::Result;
use std::fs;

pub fn parse_eth_amount(amount_str: &str) -> Result<f64> {
    amount_str.parse::<f64>()
        .map_err(|_| eyre::eyre!("Invalid ETH amount: {}", amount_str))
}

pub fn format_wei_to_eth(wei_str: &str) -> Result<f64> {
    let wei: f64 = wei_str.parse()
        .map_err(|_| eyre::eyre!("Invalid wei amount: {}", wei_str))?;
    Ok(wei / 1e18)
}

pub fn format_eth_to_wei(eth: f64) -> String {
    format!("{:.0}", eth * 1e18)
}

pub fn ensure_file_exists(path: &str) -> Result<()> {
    if !std::path::Path::new(path).exists() {
        return Err(eyre::eyre!("File not found: {}", path));
    }
    Ok(())
}

pub fn write_json_file<T: serde::Serialize>(path: &str, data: &T) -> Result<()> {
    let json = serde_json::to_string_pretty(data)?;
    fs::write(path, json)?;
    Ok(())
}

pub fn read_json_file<T: serde::de::DeserializeOwned>(path: &str) -> Result<T> {
    let content = fs::read_to_string(path)?;
    let data = serde_json::from_str(&content)?;
    Ok(data)
}