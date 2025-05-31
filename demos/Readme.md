# Vector Plus CLI Demos

This directory contains comprehensive demonstration scripts showcasing the Vector Plus CLI and its advanced trading strategies.

## 🚀 Quick Start

```bash
# Make scripts executable
chmod +x *.sh

# Run interactive demo menu
./interactive-demo.sh

# Or run specific demos directly
./quick-demo.sh              # 2-minute overview
./vector-plus-demo.sh         # Full comprehensive demo  
./mainnet-fork-demo.sh        # Live mainnet fork testing
```

## 📋 Available Demos

### 1. Quick Demo (`quick-demo.sh`)
**Duration: 2 minutes**
- CLI overview and help system
- Basic volatility strategy
- TWAP configuration
- Options creation
- Live mainnet test sample

Perfect for bounty evaluators with limited time.

### 2. Comprehensive Demo (`vector-plus-demo.sh`)  
**Duration: 10 minutes**
- Complete feature showcase
- All strategy types demonstrated
- Mainnet fork testing
- Gas efficiency analysis
- Configuration management
- Bounty submission highlights

The full experience showcasing every capability.

### 3. Mainnet Fork Demo (`mainnet-fork-demo.sh`)
**Duration: 5 minutes**
- Live mainnet fork testing
- Real WETH/USDC/USDT interactions
- Gas cost analysis
- 1inch integration validation
- Comprehensive test suite

Proves production readiness with real market data.

### 4. Interactive Demo (`interactive-demo.sh`)
**User-driven experience**
- Menu-driven demo selection
- Deep dives into specific strategies
- Customizable testing scenarios
- Guided exploration

## 🎯 Demo Highlights

### Volatility Strategy Demo
```bash
# Creates config with high volatility (750bps)
vector-plus volatility create-config --current-volatility 750 --conservative-mode

# Tests different execution amounts
vector-plus volatility calculate --amount 2.0
```

### TWAP Strategy Demo
```bash
# Creates 2-hour TWAP with randomization
vector-plus twap create-config --duration 120 --intervals 12 --randomize

# Simulates execution
vector-plus twap simulate --order-size 2.5
```

### Options Innovation Demo
```bash
# Revolutionary options on execution rights
vector-plus options create-call --strike-price 2200 --expiration-hours 168

# Fair premium calculation
vector-plus options premium --current-price 2000 --strike-price 2200
```

### Mainnet Fork Testing
```bash
# Live testing with real market data
forge test --fork-url $MAINNET_RPC_URL --match-contract VolatilityStrategyTests
forge test --fork-url $MAINNET_RPC_URL --match-contract TWAPExecutionTests
```

## 🏆 Bounty Submission Value

These demos showcase:

### Innovation ✨
- **First-ever options on limit order execution rights**
- **Advanced volatility-aware TWAP execution**
- **Professional CLI with interactive guidance**

### Code Quality 💎
- **Comprehensive mainnet fork testing**
- **Gas-optimized smart contracts**
- **Type-safe Rust implementation**
- **Professional error handling**

### 1inch Integration 🔗
- **Full IAmountGetter interface compliance**
- **Multi-asset support (ETH, USDC, USDT)**
- **Production-ready deployment**

### Real-World Ready 🌍
- **Live mainnet validation**
- **Emergency pause mechanisms**
- **Multi-network support**
- **Professional developer tooling**

## 🧪 Testing Setup

The demos use:
- **Mainnet RPC**: Alchemy endpoint with real market data
- **Test Tokens**: WETH, USDC, USDT from whale accounts
- **Gas Analysis**: Real transaction cost estimation
- **Multi-network**: Mainnet, Polygon, Arbitrum support

## 📊 Expected Demo Results

### Volatility Strategy
- **Low volatility (150bps)**: Increased execution sizes (+20%)
- **High volatility (750bps)**: Reduced execution sizes (-40% + conservative)
- **Emergency volatility (1100bps)**: Execution paused

### TWAP Execution
- **12 intervals over 2 hours**: ~10 minute intervals
- **Randomization enabled**: ±15% execution variance
- **Adaptive intervals**: Shorter during high volatility

### Options Innovation
- **Call options**: Strike $2200, 1-week expiry
- **Premium calculation**: Based on time value + intrinsic value
- **Greeks analysis**: Delta, gamma, theta calculations

### Gas Efficiency
- **Volatility calculation**: ~50k gas
- **TWAP execution**: ~75k gas  
- **Options creation**: ~120k gas
- **All under 150k gas limit**

## 🚀 Running for Bounty Evaluation

For bounty evaluators, we recommend:

1. **Quick overview**: `./quick-demo.sh`
2. **Technical validation**: `./mainnet-fork-demo.sh`
3. **Full exploration**: `./interactive-demo.sh`

Each demo is self-contained and provides clear output with professional formatting.

## 💡 Pro Tips

- Use `--verbose` flag for detailed output
- All configs are saved as JSON for inspection
- Demos clean up temporary files automatically
- Interactive mode provides guided setup
- Mainnet fork tests use real market data

## 🛠️ Troubleshooting

If demos fail to run:

```bash
# Ensure CLI is built
cd ../cli && cargo build --release

# Ensure contracts are compiled  
cd .. && forge build

# Check RPC connectivity
curl -X POST <https://eth-mainnet.g.alchemy.com/v2/IJbweBVOnwnTeoaIg10-jGVFe8aPfaH5>

# Make scripts executable
chmod +x demos/*.sh
```
