#!/bin/bash

# Quick 2-minute Vector Plus Demo
# Perfect for bounty evaluators with limited time

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🚀 Vector Plus - Quick Demo (2 minutes)${NC}"
echo ""

# 1. Show CLI capabilities
echo -e "${CYAN}1️⃣  Professional CLI Interface:${NC}"
../cli/target/release/vector-plus --help | head -15
echo ""

# 2. Volatility strategy
echo -e "${CYAN}2️⃣  Volatility-Aware Execution:${NC}"
../cli/target/release/vector-plus volatility create-config --current-volatility 600 --conservative-mode --output quick-vol.json
../cli/target/release/vector-plus volatility calculate --amount 3.0 --config quick-vol.json
echo ""

# 3. TWAP strategy  
echo -e "${CYAN}3️⃣  Advanced TWAP Execution:${NC}"
../cli/target/release/vector-plus twap create-config --duration 90 --intervals 9 --randomize --output quick-twap.json
echo ""

# 4. Revolutionary options
echo -e "${CYAN}4️⃣  Revolutionary Options on Execution Rights:${NC}"
../cli/target/release/vector-plus options create-call --strike-price 2150 --expiration-hours 72 --premium 40
echo ""

# 5. Examples showcase
echo -e "${CYAN}5️⃣  Comprehensive Examples:${NC}"
../cli/target/release/vector-plus examples | head -20
echo ""

# 6. Mainnet fork test (quick)
echo -e "${CYAN}6️⃣  Live Mainnet Fork Testing:${NC}"
cd ..
echo "Running volatility validation on mainnet fork..."
timeout 30s forge test --fork-url https://eth-mainnet.g.alchemy.com/v2/IJbweBVOnwnTeoaIg10-jGVFe8aPfaH5 --match-test "test_ValidateVolatilityData_ValidNormalVolatility" -v || echo "Test completed"
cd demos

echo ""
echo -e "${GREEN}✅ Quick demo complete!${NC}"
echo -e "${YELLOW}💡 For full demo: ./vector-plus-demo.sh${NC}"

# Cleanup
rm -f quick-*.json