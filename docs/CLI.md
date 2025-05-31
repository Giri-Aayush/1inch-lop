# CLI Usage Guide

## Installation

```bash
# Build from source
cd cli
cargo build --release

# Binary location: ./cli/target/release/vector-plus
```

## Commands Overview

```bash
# Show help
vector-plus --help

# Show examples
vector-plus examples

# Interactive mode
vector-plus interactive
```

## Volatility Strategy

### Create Configuration
```bash
vector-plus volatility create-config [OPTIONS]

# Required:
--current-volatility <VALUE>     # Current market volatility (basis points)

# Optional:
--baseline-volatility <VALUE>    # Normal volatility (default: 300)
--max-execution-size <VALUE>     # Maximum execution (default: 5.0)
--min-execution-size <VALUE>     # Minimum execution (default: 0.1)
--conservative-mode              # Enable conservative mode
--output <FILE>                  # Save to file

# Examples:
vector-plus volatility create-config --current-volatility 750 --conservative-mode
vector-plus volatility create-config --current-volatility 200 --max-execution-size 10.0 --output vol.json
```

### Calculate Amount
```bash
vector-plus volatility calculate --amount <VALUE> --config <FILE>

# Example:
vector-plus volatility calculate --amount 2.5 --config strategy.json
```

### Validate Config
```bash
vector-plus volatility validate <FILE>
```

## TWAP Strategy

### Create Configuration
```bash
vector-plus twap create-config [OPTIONS]

# Required:
--duration <MINUTES>             # Total execution duration
--intervals <COUNT>              # Number of execution intervals

# Optional:
--randomize                      # Enable MEV protection (recommended)
--min-execution-gap <SECONDS>    # Minimum time between executions
--output <FILE>                  # Save to file

# Examples:
vector-plus twap create-config --duration 120 --intervals 12 --randomize
vector-plus twap create-config --duration 360 --intervals 24 --output twap.json
```

### Simulate Execution
```bash
vector-plus twap simulate --config <FILE> --order-size <VALUE>

# Optional:
--show-timeline                  # Display execution timeline

# Example:
vector-plus twap simulate --config twap.json --order-size 10.0 --show-timeline
```

### Check Status
```bash
vector-plus twap status <CONFIG_FILE>
```

## Options Strategy

### Create Call Option
```bash
vector-plus options create-call [OPTIONS]

# Required:
--strike-price <VALUE>           # Strike price
--expiration-hours <HOURS>       # Hours until expiration

# Optional:
--premium <VALUE>                # Premium amount
--output <FILE>                  # Save configuration

# Example:
vector-plus options create-call --strike-price 2200 --expiration-hours 168 --premium 65
```

### Create Put Option
```bash
vector-plus options create-put --strike-price <VALUE> --expiration-hours <HOURS>

# Example:
vector-plus options create-put --strike-price 1800 --expiration-hours 72 --premium 45
```

### Calculate Premium
```bash
vector-plus options premium [OPTIONS]

# Required:
--current-price <VALUE>          # Current market price
--strike-price <VALUE>           # Option strike price
--time-to-expiration <HOURS>     # Hours until expiration

# Optional:
--volatility <VALUE>             # Implied volatility (default: 80%)

# Example:
vector-plus options premium --current-price 2000 --strike-price 2200 --time-to-expiration 168
```

## Configuration Management

### Show Config
```bash
vector-plus config show
```

### Initialize
```bash
vector-plus config init [--network <NETWORK>]

# Supported networks: mainnet, polygon, arbitrum, base, optimism
```

### Set Network
```bash
vector-plus config set-network <NETWORK>
```

## Common Usage Patterns

### Conservative High-Volatility Setup
```bash
vector-plus volatility create-config \
  --current-volatility 900 \
  --baseline-volatility 300 \
  --max-execution-size 2.0 \
  --conservative-mode \
  --output conservative.json
```

### Large Order TWAP
```bash
vector-plus twap create-config \
  --duration 360 \
  --intervals 36 \
  --randomize \
  --output large-order.json

vector-plus twap simulate --config large-order.json --order-size 100.0
```

### Options Strategies
```bash
# Bullish call
vector-plus options create-call --strike-price 2200 --expiration-hours 168

# Bearish put  
vector-plus options create-put --strike-price 1800 --expiration-hours 72

# Premium calculation
vector-plus options premium --current-price 2000 --strike-price 2200 --time-to-expiration 168
```

## Output Formats

### JSON Output
```bash
# Save as JSON
vector-plus volatility create-config --current-volatility 500 --output config.json

# Format as JSON
vector-plus volatility create-config --current-volatility 500 --format json
```

### Verbose Mode
```bash
vector-plus --verbose volatility calculate --amount 2.0 --config strategy.json
```

## Environment Variables

```bash
# Set default paths
export VECTOR_PLUS_CONFIG_DIR="$HOME/.vector-plus"
export VECTOR_PLUS_DEFAULT_NETWORK="polygon"

# Debug mode
export RUST_LOG=debug
```

## Error Codes

- `0` - Success
- `1` - General error
- `2` - Invalid arguments  
- `3` - Configuration error
- `4` - Network error