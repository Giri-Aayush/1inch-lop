# Testing Guide

## Quick Test Commands

### Run All Tests
```bash
# Complete test suite
./test-suite.sh

# Unit tests only (fast)
forge test --no-match-contract Fork

# Fork tests with real market data
./test-suite.sh --fork

# CLI tests
./test-suite.sh --cli
```

### Specific Test Categories
```bash
# Volatility strategy tests
forge test --match-contract "Volatility"

# TWAP execution tests  
forge test --match-contract "TWAP"

# Options tests
forge test --match-contract "Options"
```

## Unit Tests

### Smart Contract Tests
```bash
# All unit tests
forge test --no-match-contract "(Fork|Integration)"

# Specific contracts
forge test --match-contract "VolatilityCalculator" -v
forge test --match-contract "TWAPCalculator" -v
forge test --match-contract "OptionsCalculator" -v

# Specific test cases
forge test --match-test "testLowVolatilityIncrease" -vv
forge test --match-test "testTWAPWithRandomization" -vv
forge test --match-test "testProfitableCallExercise" -vv
```

### CLI Tests
```bash
# Build CLI first
cd cli && cargo build --release && cd ..

# Run CLI tests
cargo test --manifest-path cli/Cargo.toml

# Specific CLI modules
cargo test --manifest-path cli/Cargo.toml volatility
cargo test --manifest-path cli/Cargo.toml twap
cargo test --manifest-path cli/Cargo.toml options
```

## Mainnet Fork Tests

### Setup
```bash
# Set RPC URL for fork testing
export MAINNET_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/your-key"

# Verify connection
curl -X POST $MAINNET_RPC_URL \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Run Fork Tests
```bash
# All fork tests
forge test --fork-url $MAINNET_RPC_URL

# Specific categories
forge test --fork-url $MAINNET_RPC_URL --match-contract "VolatilityStrategyTests"
forge test --fork-url $MAINNET_RPC_URL --match-contract "TWAPExecutionTests"
forge test --fork-url $MAINNET_RPC_URL --match-contract "MainnetForkTest"

# Integration with 1inch
forge test --fork-url $MAINNET_RPC_URL --match-contract "OneinchIntegration"
```

### What Fork Tests Validate
- **Real market data** with WETH, USDC, USDT from whale accounts
- **Live volatility conditions** affecting position sizing
- **Time-based TWAP execution** over multiple intervals
- **1inch protocol compatibility** with actual limit orders
- **Gas efficiency** with real transaction costs

## Gas Efficiency Tests

### Run Gas Analysis
```bash
# Gas usage report
forge test --fork-url $MAINNET_RPC_URL --gas-report

# Specific gas tests
forge test --fork-url $MAINNET_RPC_URL --match-test "GasEfficiency" --gas-report

# Detailed gas analysis
forge test --fork-url $MAINNET_RPC_URL --gas-report -vv
```

### Expected Gas Usage
| Operation | Expected Gas | Test |
|-----------|--------------|------|
| Volatility calculation | ~50k gas | `test_VolatilityCalculation_GasEfficiency` |
| TWAP execution | ~75k gas | `test_TWAPCalculation_GasEfficiency` |
| Options creation | ~120k gas | `test_OptionsCreation_GasEfficiency` |

## Demo Tests

### Interactive Demos
```bash
# Quick 2-minute demo
cd demos && ./quick-demo.sh

# Full demonstration
./vector-plus-showcase.sh

# Interactive menu
./interactive-demo.sh

# Mainnet fork demo
./mainnet-fork-demo.sh
```

### Manual Testing Scenarios
```bash
# High volatility scenario
vector-plus volatility create-config --current-volatility 1100 --conservative-mode --output extreme.json
vector-plus volatility calculate --amount 10.0 --config extreme.json

# Large order TWAP
vector-plus twap create-config --duration 360 --intervals 36 --randomize --output large.json
vector-plus twap simulate --config large.json --order-size 100.0

# Options testing
vector-plus options create-call --strike-price 2200 --expiration-hours 168 --premium 65
vector-plus options premium --current-price 2000 --strike-price 2200 --time-to-expiration 168
```

## Test Coverage

### Generate Coverage Report
```bash
# Install coverage tool
cargo install cargo-llvm-cov

# Generate coverage for contracts
forge coverage --report lcov

# Generate coverage for CLI
cargo llvm-cov --manifest-path cli/Cargo.toml --html

# View coverage
open target/llvm-cov/html/index.html
```

### Coverage Targets
- **Smart Contracts:** >95% line coverage
- **CLI:** >90% function coverage
- **Integration:** >85% scenario coverage

## Debugging Failed Tests

### Common Issues

#### RPC Connection Problems
```bash
# Test RPC connectivity
curl -X POST $MAINNET_RPC_URL -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Use alternative RPC
export MAINNET_RPC_URL="https://ethereum-mainnet.core.chainstack.com/your-key"

# Use specific block for consistency
forge test --fork-url $MAINNET_RPC_URL --fork-block-number 18500000
```

#### Gas Estimation Failures
```bash
# Use higher gas limit
forge test --fork-url $MAINNET_RPC_URL --gas-limit 30000000

# Skip gas-sensitive tests
forge test --no-match-test "GasEfficiency"
```

#### CLI Build Issues
```bash
# Update Rust
rustup update

# Clean and rebuild
cd cli && cargo clean && cargo build --release
```

### Debug Output
```bash
# Verbose test output
forge test --match-test "failing_test" -vvvv

# Trace execution
forge test --match-test "failing_test" --debug

# CLI debug mode
RUST_LOG=debug ./cli/target/release/vector-plus volatility calculate --amount 2.0 --config test.json
```

## Test Environment Setup

### Development Environment
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Setup project
./setup.sh
```

### CI Environment Variables
```bash
export MAINNET_RPC_URL="your_mainnet_rpc_url"
export FOUNDRY_PROFILE="ci"
export RUST_LOG="info"
```

## Test Data

### Test Fixtures
- **Whale Accounts:** Real WETH/USDC/USDT balances from mainnet
- **Market Conditions:** Various volatility scenarios (low, normal, high, extreme)
- **Time Scenarios:** Different TWAP durations and intervals
- **Option Scenarios:** ITM, OTM, ATM options with various expiration times

### Test Networks
- **Mainnet Fork:** Real market data and conditions
- **Local Testnet:** Fast isolated testing
- **Public Testnets:** Integration testing before mainnet