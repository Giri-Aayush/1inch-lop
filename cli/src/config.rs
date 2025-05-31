use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct VectorPlusConfig {
    pub network: String,
    pub rpc_url: Option<String>,
    pub contracts: ContractConfig,
    pub defaults: DefaultConfig,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ContractConfig {
    pub volatility_calculator: Option<String>,
    pub twap_executor: Option<String>,
    pub options_calculator: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DefaultConfig {
    pub volatility: VolatilityDefaults,
    pub twap: TwapDefaults,
    pub options: OptionsDefaults,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct VolatilityDefaults {
    pub baseline_volatility: u64,
    pub max_execution_size: String,
    pub min_execution_size: String,
    pub conservative_mode: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TwapDefaults {
    pub duration: u64,
    pub intervals: u32,
    pub randomize_execution: bool,
    pub adaptive_intervals: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct OptionsDefaults {
    pub default_expiration_hours: u64,
    pub implied_volatility: u64,
    pub risk_free_rate: u64,
}

impl Default for VectorPlusConfig {
    fn default() -> Self {
        Self {
            network: "mainnet".to_string(),
            rpc_url: None,
            contracts: ContractConfig {
                volatility_calculator: None,
                twap_executor: None,
                options_calculator: None,
            },
            defaults: DefaultConfig {
                volatility: VolatilityDefaults {
                    baseline_volatility: 300,
                    max_execution_size: "5000000000000000000".to_string(), // 5 ETH
                    min_execution_size: "100000000000000000".to_string(),   // 0.1 ETH
                    conservative_mode: false,
                },
                twap: TwapDefaults {
                    duration: 7200, // 2 hours
                    intervals: 12,
                    randomize_execution: true,
                    adaptive_intervals: true,
                },
                options: OptionsDefaults {
                    default_expiration_hours: 168, // 1 week
                    implied_volatility: 8000,      // 80%
                    risk_free_rate: 300,           // 3%
                },
            },
        }
    }
}