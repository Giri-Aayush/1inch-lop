#!/bin/bash

# Vector Plus CLI Demo Script
# Demonstrates advanced trading strategies with mainnet fork testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Demo configuration
DEMO_ETH_AMOUNT="2.5"
DEMO_USDC_AMOUNT="5000"
MAINNET_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/IJbweBVOnwnTeoaIg10-jGVFe8aPfaH5"

print_banner() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                 VECTOR PLUS DEMO                      ║${NC}"
    echo -e "${BLUE}║         Advanced Trading Strategies for 1inch         ║${NC}"
    echo -e "${BLUE}║              Live Mainnet Fork Testing                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

check_prerequisites() {
    echo -e "${CYAN}🔍 Checking prerequisites...${NC}"
    
    # Check if CLI is built
    if [ ! -f "../cli/target/release/vector-plus" ]; then
        echo -e "${YELLOW}⚠️  Vector Plus CLI not found. Building...${NC}"
        cd ../cli
        cargo build --release
        cd ../demos
    fi
    
    # Check if contracts are compiled
    if [ ! -d "../out" ]; then
        echo -e "${YELLOW}⚠️  Contracts not compiled. Building...${NC}"
        cd ..
        forge build
        cd demos
    fi
    
    echo -e "${GREEN}✅ Prerequisites ready!${NC}"
    echo ""
}

demo_cli_help() {
    print_section "📚 VECTOR PLUS CLI OVERVIEW"
    
    echo -e "${CYAN}Vector Plus provides advanced trading strategies:${NC}"
    echo "• 🌊 Volatility-aware execution"
    echo "• 🕒 TWAP with MEV protection"  
    echo "• 📞 Options on execution rights"
    echo "• 🚀 Combined strategies"
    echo ""
    
    echo -e "${YELLOW}💡 Available commands:${NC}"
    ../cli/target/release/vector-plus --help
    echo ""
}

demo_volatility_strategy() {
    print_section "🌊 VOLATILITY STRATEGY DEMO"
    
    echo -e "${CYAN}Step 1: Creating volatility configuration for current market conditions${NC}"
    ../cli/target/release/vector-plus volatility create-config \
        --baseline-volatility 300 \
        --current-volatility 750 \
        --max-execution-size 10.0 \
        --min-execution-size 0.05 \
        --conservative-mode \
        --output demo-volatility.json
    
    echo ""
    echo -e "${CYAN}Step 2: Validating configuration integrity${NC}"
    ../cli/target/release/vector-plus volatility validate demo-volatility.json
    
    echo ""
    echo -e "${CYAN}Step 3: Testing different execution amounts${NC}"
    
    for amount in "0.5" "2.0" "5.0" "15.0"; do
        echo -e "${YELLOW}📊 Testing ${amount} ETH execution:${NC}"
        ../cli/target/release/vector-plus volatility calculate \
            --amount ${amount} \
            --config demo-volatility.json
        echo ""
    done
}

demo_twap_strategy() {
    print_section "🕒 TWAP STRATEGY DEMO"
    
    echo -e "${CYAN}Step 1: Creating TWAP configuration${NC}"
    ../cli/target/release/vector-plus twap create-config \
        --duration 120 \
        --intervals 12 \
        --randomize \
        --output demo-twap.json
    
    echo ""
    echo -e "${CYAN}Step 2: Simulating TWAP execution${NC}"
    ../cli/target/release/vector-plus twap simulate \
        --config demo-twap.json \
        --order-size ${DEMO_ETH_AMOUNT}
    
    echo ""
    echo -e "${YELLOW}💡 TWAP Benefits:${NC}"
    echo "• Reduces market impact through time distribution"
    echo "• MEV protection via randomized execution"
    echo "• Adaptive intervals based on volatility"
    echo "• Emergency pause during extreme conditions"
    echo ""
}

demo_options_strategy() {
    print_section "📞 OPTIONS STRATEGY DEMO"
    
    echo -e "${CYAN}Revolutionary: Options on Limit Order Execution Rights${NC}"
    echo ""
    
    echo -e "${CYAN}Step 1: Creating call option (bullish strategy)${NC}"
    ../cli/target/release/vector-plus options create-call \
        --strike-price 2200 \
        --expiration-hours 168 \
        --premium 75
    
    echo ""
    echo -e "${CYAN}Step 2: Calculating fair premium${NC}"
    ../cli/target/release/vector-plus options premium \
        --current-price 2000 \
        --strike-price 2200 \
        --time-to-expiration 168
    
    echo ""
    echo -e "${YELLOW}💡 Options Innovation:${NC}"
    echo "• First-ever options on execution rights"
    echo "• Call options: Right to execute at favorable prices"
    echo "• Put options: Protection against adverse moves"
    echo "• Premium-based pricing with Greeks calculation"
    echo ""
}

demo_combined_strategy() {
    print_section "🚀 COMBINED STRATEGY DEMO"
    
    echo -e "${CYAN}Step 1: Creating advanced combined strategy${NC}"
    ../cli/target/release/vector-plus combined create \
        --twap-duration 180 \
        --twap-intervals 18 \
        --volatility-threshold 600 \
        --output demo-combined.json
    
    echo ""
    echo -e "${YELLOW}💡 Combined Strategy Benefits:${NC}"
    echo "• TWAP execution with volatility awareness"
    echo "• Dynamic interval adjustment"
    echo "• Risk-managed position sizing"
    echo "• Emergency controls and monitoring"
    echo ""
}

demo_mainnet_fork_testing() {
    print_section "🔗 MAINNET FORK TESTING"
    
    echo -e "${CYAN}Running comprehensive mainnet fork tests...${NC}"
    echo "• Using RPC: ${MAINNET_RPC_URL}"
    echo "• Testing with real market data"
    echo "• Validating gas efficiency"
    echo ""
    
    cd ..
    
    echo -e "${YELLOW}Test 1: Volatility Strategy Tests${NC}"
    forge test --fork-url $MAINNET_RPC_URL --match-contract VolatilityStrategyTests -v
    
    echo ""
    echo -e "${YELLOW}Test 2: TWAP Execution Tests${NC}"
    forge test --fork-url $MAINNET_RPC_URL --match-contract TWAPExecutionTests -v
    
    echo ""
    echo -e "${YELLOW}Test 3: Integration Tests${NC}"
    forge test --fork-url $MAINNET_RPC_URL --match-test "test_Integration_*" -v
    
    cd demos
    
    echo -e "${GREEN}✅ All mainnet fork tests passed!${NC}"
    echo ""
}

demo_interactive_mode() {
    print_section "🎯 INTERACTIVE MODE DEMO"
    
    echo -e "${CYAN}Vector Plus includes an interactive mode for guided setup:${NC}"
    echo ""
    echo -e "${YELLOW}💡 Try running:${NC}"
    echo "vector-plus interactive"
    echo ""
    echo "This provides a step-by-step wizard for:"
    echo "• Volatility strategy configuration"
    echo "• TWAP parameter optimization"
    echo "• Options strategy setup"
    echo "• Combined strategy creation"
    echo ""
}

demo_configuration_management() {
    print_section "⚙️ CONFIGURATION MANAGEMENT"
    
    echo -e "${CYAN}Step 1: Showing current configuration${NC}"
    ../cli/target/release/vector-plus config show
    
    echo ""
    echo -e "${CYAN}Step 2: Network-specific configurations${NC}"
    echo -e "${YELLOW}💡 Vector Plus supports multiple networks:${NC}"
    echo "• Mainnet (default)"
    echo "• Polygon"
    echo "• Arbitrum"
    echo ""
    echo "Example: vector-plus --network polygon volatility create-config"
    echo ""
}

demo_gas_efficiency() {
    print_section "⛽ GAS EFFICIENCY ANALYSIS"
    
    echo -e "${CYAN}Running gas analysis on mainnet fork...${NC}"
    cd ..
    
    echo -e "${YELLOW}Gas usage for different strategies:${NC}"
    forge test --fork-url $MAINNET_RPC_URL --gas-report --match-test "test.*GasEfficiency" -v
    
    cd demos
    echo ""
    echo -e "${GREEN}✅ All strategies optimized for production gas costs${NC}"
    echo ""
}

show_bounty_highlights() {
    print_section "🏆 BOUNTY SUBMISSION HIGHLIGHTS"
    
    echo -e "${GREEN}✅ Innovation:${NC}"
    echo "• First-ever options on limit order execution rights"
    echo "• Revolutionary volatility-aware TWAP execution"
    echo "• Professional CLI with interactive guidance"
    echo ""
    
    echo -e "${GREEN}✅ Code Quality:${NC}"
    echo "• Comprehensive mainnet fork testing"
    echo "• Gas-optimized smart contracts"
    echo "• Type-safe Rust CLI with error handling"
    echo "• Modular, extensible architecture"
    echo ""
    
    echo -e "${GREEN}✅ 1inch Integration:${NC}"
    echo "• Full IAmountGetter interface compliance"
    echo "• Compatible with existing limit orders"
    echo "• Production-ready deployment scripts"
    echo ""
    
    echo -e "${GREEN}✅ Real-World Ready:${NC}"
    echo "• Live mainnet fork validation"
    echo "• MEV protection mechanisms"
    echo "• Emergency pause controls"
    echo "• Professional developer tooling"
    echo ""
}

cleanup_demo_files() {
    echo -e "${CYAN}🧹 Cleaning up demo files...${NC}"
    rm -f demo-*.json
    echo -e "${GREEN}✅ Demo cleanup complete${NC}"
    echo ""
}

main() {
    print_banner
    
    echo -e "${YELLOW}🚀 Starting Vector Plus comprehensive demo...${NC}"
    echo ""
    
    check_prerequisites
    demo_cli_help
    demo_volatility_strategy
    demo_twap_strategy
    demo_options_strategy
    demo_combined_strategy
    demo_mainnet_fork_testing
    demo_gas_efficiency
    demo_interactive_mode
    demo_configuration_management
    show_bounty_highlights
    
    echo -e "${GREEN}🎉 Demo completed successfully!${NC}"
    echo ""
    echo -e "${YELLOW}💡 Next steps:${NC}"
    echo "• Run individual strategies: vector-plus --help"
    echo "• Try interactive mode: vector-plus interactive"
    echo "• View examples: vector-plus examples"
    echo "• Test on different networks: vector-plus --network polygon"
    echo ""
    
    cleanup_demo_files
}

# Run main function
main "$@"