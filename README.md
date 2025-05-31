# Vector Plus: Advanced Trading Strategies for 1inch Protocol

> Revolutionary DeFi trading strategies featuring options on execution rights, volatility-aware position sizing, and MEV-resistant TWAP execution.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.19-blue)](https://docs.soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-orange)](https://getfoundry.sh/)

## What We Built

### 1. Options on Execution Rights (Industry First)
Trade options on the **right to execute** limit orders, not the underlying assets.

![alt text](./docs/assets/1.png)

### 2. Volatility-Aware Position Sizing
Dynamic execution sizing based on real-time market volatility.

![alt text](./docs/assets/2.png)

### 3. MEV-Resistant TWAP Execution
Time-weighted execution with anti-MEV randomization.

- **±15% randomization** prevents predictable execution patterns
- **Adaptive intervals** - shorter during high volatility
- **Progress tracking** with emergency controls

## System Architecture

![alt text](./docs/assets/3.png)

## Quick Start

```bash
# Setup everything
git clone https://github.com/your-repo/vector-plus.git
cd vector-plus
./setup.sh

# Create volatility strategy
./cli/target/release/vector-plus volatility create-config \
  --current-volatility 750 \
  --conservative-mode

# Create TWAP strategy
./cli/target/release/vector-plus twap create-config \
  --duration 120 \
  --intervals 12 \
  --randomize

# Run tests
forge test
./test-suite.sh --fork
```

## Key Features

### Revolutionary Options System
- **First-ever options on limit order execution rights**
- Call/put options with strike prices and expiration times
- 30-minute exercise window before expiration
- Premium collection with protocol fees

### Intelligent Risk Management
- **Real-time volatility analysis** with 0-1000 risk scoring
- **Emergency pause mechanisms** for extreme market conditions
- **Progressive position sizing** based on market conditions

### MEV Protection
- **±15% execution randomization** prevents predictable patterns
- **Adaptive intervals** adjust based on volatility
- **Time-weighted distribution** reduces market impact

## Smart Contracts

| Contract | Purpose | Gas Cost |
|----------|---------|----------|
| `OptionsCalculator` | Options on execution rights | ~120k gas |
| `EnhancedVolatilityCalculator` | Volatility-aware sizing | ~50k gas |
| `EnhancedTWAPVolatilityExecutor` | TWAP + volatility execution | ~75k gas |

All contracts implement the 1inch `IAmountGetter` interface for seamless integration.

## Testing & Validation

- **95+ unit tests** covering all strategy logic
- **54 mainnet fork tests** with real market data (WETH, USDC, USDT)
- **Live price feeds** from Ethereum mainnet
- **Multi-network validation** on 5+ EVM chains

## Usage Examples

### Volatility Strategy
```bash
# High volatility market - reduce position size
vector-plus volatility create-config \
  --current-volatility 900 \
  --conservative-mode \
  --max-execution-size 2.0

# Calculate adjusted amount
vector-plus volatility calculate --amount 5.0 --config strategy.json
# Output: 2.5 ETH (50% reduction due to high volatility)
```

### TWAP Strategy
```bash
# 6-hour execution with MEV protection
vector-plus twap create-config \
  --duration 360 \
  --intervals 36 \
  --randomize

# Simulate execution
vector-plus twap simulate --order-size 20.0 --config twap.json
```

### Options Strategy
```bash
# Create call option for bullish bet
vector-plus options create-call \
  --strike-price 2200 \
  --expiration-hours 168 \
  --premium 65

# Calculate fair premium
vector-plus options premium \
  --current-price 2000 \
  --strike-price 2200 \
  --time-to-expiration 168
```

## Network Support

- **Ethereum Mainnet** - Primary deployment
- **Polygon** - L2 for lower fees
- **Arbitrum** - Optimistic rollup
- **Base** - Coinbase L2
- **Optimism** - Ethereum L2

## Performance Metrics

| Strategy | Gas Usage | Execution Time | Risk Reduction |
|----------|-----------|----------------|----------------|
| Volatility Management | ~50k gas | <1 second | Up to 50% size reduction |
| TWAP Execution | ~75k gas | Configurable intervals | MEV protection via randomization |
| Options Trading | ~120k gas | 30-min exercise window | Premium-based risk transfer |

## Documentation

- **[CLI Guide](./docs/CLI.md)** - Complete command reference
- **[Testing Guide](./docs/TESTING.md)** - Running tests and validation
- **[API Reference](./src/)** - Smart contract documentation

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Vector Plus** - Advancing DeFi trading through intelligent automation and risk management.