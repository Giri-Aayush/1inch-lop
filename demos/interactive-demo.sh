#!/bin/bash

# Interactive Demo Script
# Lets users choose what to demonstrate

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

show_menu() {
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║              VECTOR PLUS DEMONSTRATION SUITE           ║${NC}"
    echo -e "${PURPLE}║           Advanced Trading Strategy Showcase           ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Technical Demonstrations:${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} 📈 Executive Overview (professional summary)"
    echo -e "${YELLOW}2)${NC} 🏢 Complete Technical Showcase (comprehensive)"
    echo -e "${YELLOW}3)${NC} 🔬 Mainnet Fork Validation (live testing)"
    echo -e "${YELLOW}4)${NC} 🌊 Volatility Engine Analysis"
    echo -e "${YELLOW}5)${NC} ⏱️  TWAP Execution Deep Dive"
    echo -e "${YELLOW}6)${NC} 💎 Options Implementation Showcase"
    echo -e "${YELLOW}7)${NC} 🎯 Interactive CLI Experience"
    echo -e "${YELLOW}8)${NC} ⛽ Gas Efficiency Benchmarks"
    echo -e "${YELLOW}9)${NC} 🏆 Technical Achievement Summary"
    echo -e "${YELLOW}0)${NC} ❌ Exit"
    echo ""
}

run_volatility_deep_dive() {
    echo -e "${CYAN}🌊 Volatility Strategy Deep Dive${NC}"
    echo ""
    
    echo "Testing various market conditions:"
    
    # Low volatility
    echo -e "${GREEN}📊 Low Volatility Market (150bps):${NC}"
    ../cli/target/release/vector-plus volatility create-config \
        --baseline-volatility 200 \
        --current-volatility 150 \
        --max-execution-size 15.0 \
        --output low-vol.json
    
    ../cli/target/release/vector-plus volatility calculate --amount 5.0 --config low-vol.json
    
    # High volatility
    echo -e "${YELLOW}📊 High Volatility Market (800bps):${NC}"
    ../cli/target/release/vector-plus volatility create-config \
        --baseline-volatility 300 \
        --current-volatility 800 \
        --conservative-mode \
        --output high-vol.json
    
    ../cli/target/release/vector-plus volatility calculate --amount 5.0 --config high-vol.json
    
    # Extreme volatility
    echo -e "${RED}📊 Extreme Volatility Market (1100bps):${NC}"
    ../cli/target/release/vector-plus volatility create-config \
        --baseline-volatility 300 \
        --current-volatility 1100 \
        --conservative-mode \
        --output extreme-vol.json
    
    ../cli/target/release/vector-plus volatility calculate --amount 5.0 --config extreme-vol.json
    
    rm -f *-vol.json
}

run_twap_showcase() {
    echo -e "${CYAN}🕒 TWAP Execution Showcase${NC}"
    echo ""
    
    echo "Different TWAP strategies:"
    
    # Quick execution
    echo -e "${GREEN}⚡ Quick TWAP (30 minutes, 6 intervals):${NC}"
    ../cli/target/release/vector-plus twap create-config \
        --duration 30 \
        --intervals 6 \
        --output quick-twap.json
    
    # Standard execution  
    echo -e "${BLUE}📊 Standard TWAP (2 hours, 12 intervals):${NC}"
    ../cli/target/release/vector-plus twap create-config \
        --duration 120 \
        --intervals 12 \
        --randomize \
        --output standard-twap.json
    
    # Patient execution
    echo -e "${PURPLE}🐌 Patient TWAP (6 hours, 24 intervals):${NC}"
    ../cli/target/release/vector-plus twap create-config \
        --duration 360 \
        --intervals 24 \
        --randomize \
        --output patient-twap.json
    
    echo "Testing execution simulations..."
    ../cli/target/release/vector-plus twap simulate --config standard-twap.json --order-size 10.0
    
    rm -f *-twap.json
}

run_options_innovation() {
    echo -e "${CYAN}📞 Options Innovation Demo${NC}"
    echo ""
    
    echo "Revolutionary options on execution rights:"
    
    # Call options for different scenarios
    echo -e "${GREEN}📈 Bullish Call Option (Strike: $2200):${NC}"
    ../cli/target/release/vector-plus options create-call \
        --strike-price 2200 \
        --expiration-hours 168 \
        --premium 60
    
    echo -e "${BLUE}📊 At-the-money Call (Strike: $2000):${NC}"
    ../cli/target/release/vector-plus options create-call \
        --strike-price 2000 \
        --expiration-hours 72 \
        --premium 40
    
    # Premium calculations
    echo -e "${YELLOW}💰 Premium Calculations:${NC}"
    ../cli/target/release/vector-plus options premium \
        --current-price 2000 \
        --strike-price 2200 \
        --time-to-expiration 168
}

run_interactive_cli() {
    echo -e "${CYAN}🎯 Interactive CLI Experience${NC}"
    echo ""
    echo "Launching Vector Plus interactive mode..."
    echo "This provides a guided setup experience for users."
    echo ""
    ../cli/target/release/vector-plus interactive
}

run_gas_analysis() {
    echo -e "${CYAN}⛽ Gas Efficiency Analysis${NC}"
    echo ""
    cd ..
    echo "Analyzing gas costs on mainnet fork..."
    forge test --fork-url https://eth-mainnet.g.alchemy.com/v2/IJbweBVOnwnTeoaIg10-jGVFe8aPfaH5 \
        --match-test "test.*GasEfficiency" \
        --gas-report \
        -v
    cd demos
}

run_bounty_highlights() {
    echo -e "${CYAN}🏆 Bounty Highlights Summary${NC}"
    echo ""
    echo -e "${GREEN}🚀 INNOVATION HIGHLIGHTS:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "• 📞 First-ever options on limit order execution rights"
    echo "• 🌊 Advanced volatility-aware position sizing"
    echo "• 🕒 MEV-protected TWAP with adaptive intervals"
    echo "• 🎯 Professional Rust CLI with interactive guidance"
    echo ""
    
    echo -e "${GREEN}💎 CODE QUALITY:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "• ✅ Comprehensive mainnet fork testing"
    echo "• ✅ Gas-optimized smart contracts (<100k gas)"
    echo "• ✅ Type-safe Rust implementation"
    echo "• ✅ Professional error handling and validation"
    echo ""
    
    echo -e "${GREEN}🔗 1INCH INTEGRATION:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "• ✅ Full IAmountGetter interface compliance"
    echo "• ✅ Compatible with existing limit orders"
    echo "• ✅ Multi-asset support (ETH, USDC, USDT, DAI)"
    echo "• ✅ Production-ready deployment"
    echo ""
    
    echo -e "${GREEN}🌍 REAL-WORLD READY:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "• ✅ Live mainnet fork validation"
    echo "• ✅ Emergency pause mechanisms"
    echo "• ✅ Multi-network support (Mainnet, Polygon, Arbitrum)"
    echo "• ✅ Professional developer tooling"
    echo ""
    
    echo -e "${YELLOW}💡 DEMO COMMANDS TO TRY:${NC}"
    echo "vector-plus --help"
    echo "vector-plus examples"
    echo "vector-plus interactive"
    echo "vector-plus volatility create-config --current-volatility 500"
    echo ""
}

main() {
    while true; do
        show_menu
        read -p "Choose demo (0-9): " choice
        echo ""
        
        case $choice in
            1)
                echo -e "${YELLOW}📈 Running Executive Overview...${NC}"
                ./executive-summary.sh
                ;;
            2)
                echo -e "${YELLOW}🏢 Running Technical Showcase...${NC}"
                ./vector-plus-showcase.sh
                ;;
            3)
                echo -e "${YELLOW}🔬 Running Mainnet Fork Validation...${NC}"
                ./mainnet-fork-demo.sh
                ;;
            4)
                run_volatility_deep_dive
                ;;
            5)
                run_twap_showcase
                ;;
            6)
                run_options_innovation
                ;;
            7)
                run_interactive_cli
                ;;
            8)
                run_gas_analysis
                ;;
            9)
                run_bounty_highlights
                ;;
            0)
                echo -e "${GREEN}👋 Thank you for exploring Vector Plus!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please select 0-9.${NC}"
                ;;
        esac
        
        echo ""
        echo -e "${CYAN}Press Enter to continue...${NC}"
        read
        clear
    done
}

# Check if CLI is available
if [ ! -f "../cli/target/release/vector-plus" ]; then
    echo -e "${RED}❌ Vector Plus CLI not found!${NC}"
    echo "Please build it first: cd cli && cargo build --release"
    exit 1
fi

# Run main menu
main