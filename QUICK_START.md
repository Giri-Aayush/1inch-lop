# Vector Plus Quick Start Guide

## 🚀 You're Ready to Go!

Vector Plus has been successfully set up on your system. Here's how to get started:

### 1. Deploy to Local Network (Testing)

```bash
# Start local blockchain (in another terminal)
anvil

# Deploy contracts locally
./deploy.sh localhost

# Test with CLI
cd cli
./target/release/vector-plus --network localhost --help
```

### 2. Deploy to Mainnet

```bash
# Edit .env file with your configuration
nano .env

# Deploy to mainnet (requires real ETH for gas)
./deploy.sh mainnet --verify

# Use with deployed contracts
./cli/target/release/vector-plus --network mainnet
```

### 3. Run Demos

```bash
cd demos

# Executive overview (90 seconds)
./executive-summary.sh

# Complete technical showcase  
./vector-plus-showcase.sh

# Interactive demo menu
./interactive-demo.sh
```

### 4. Run Tests

```bash
# All tests
./test-suite.sh

# Just mainnet fork tests
./test-suite.sh --fork

# With gas reporting
./test-suite.sh --gas-report
```

### 5. CLI Usage Examples

```bash
# Create volatility strategy
vector-plus volatility create-config --current-volatility 500

# Create TWAP execution
vector-plus twap create-config --duration 120 --intervals 12

# Create options on execution rights
vector-plus options create-call --strike-price 2100 --premium 50

# Interactive guidance
vector-plus interactive
```

## 📁 Project Structure

- `src/` - Smart contracts
- `cli/` - Vector Plus CLI (Rust)
- `demos/` - Demonstration scripts
- `test/` - Comprehensive test suites
- `script/` - Deployment scripts
- `deployments/` - Deployment artifacts

## 🌐 Supported Networks

- Ethereum Mainnet
- Polygon
- Arbitrum
- Base
- Optimism
- Local (Anvil/Hardhat)

## 🆘 Need Help?

1. Check `demos/` for usage examples
2. Run `vector-plus --help` for CLI documentation
3. Review test files for implementation examples
4. Check deployment logs in `deployments/`

Happy trading! 🎯
