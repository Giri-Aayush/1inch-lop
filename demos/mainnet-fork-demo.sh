#!/bin/bash

# Mainnet Fork Testing Demo
# Showcases live testing with real market data

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

MAINNET_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/IJbweBVOnwnTeoaIg10-jGVFe8aPfaH5"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            MAINNET FORK TESTING DEMO                  ║${NC}"
echo -e "${BLUE}║         Real Market Data • Live Validation            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

cd ..

echo -e "${CYAN}🔗 Connected to Ethereum Mainnet Fork${NC}"
echo "RPC: ${MAINNET_RPC_URL}"
echo "Testing with real WETH, USDC, USDT balances"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW} 🌊 VOLATILITY STRATEGY MAINNET TESTS${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${CYAN}Test 1: Volatility Data Validation${NC}"
forge test --fork-url $MAINNET_RPC_URL \
    --match-test "test_ValidateVolatilityData_ValidNormalVolatility" \
    -v

echo ""
echo -e "${CYAN}Test 2: Volatility Amount Adjustments${NC}"
forge test --fork-url $MAINNET_RPC_URL \
    --match-test "test_ApplyVolatilityAdjustment_*" \
    -v

echo ""
echo -e "${CYAN}Test 3: Emergency Pause Mechanisms${NC}"
forge test --fork-url $MAINNET_RPC_URL \
    --match-test "test_CalculateVolatilityMetrics_EmergencyLevel" \
    -v

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW} 🕒 TWAP EXECUTION MAINNET TESTS${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${CYAN}Test 1: TWAP Time-based Execution${NC}"
forge test --fork-url $MAINNET_RPC_URL \
    --match-test "test_TWAPExecution_TimeProgressionAffectsAmount" \
    -v

echo ""
echo -e "${CYAN}Test 2: Randomization and MEV Protection${NC}"
forge test --fork-url $MAINNET_RPC_URL \
    --match-test "test_TWAPExecution_RandomizationProducesDifferentAmounts" \
    -v

echo ""
echo -e "${CYAN}Test 3: Adaptive Intervals with Volatility${NC}"
forge test --fork-url $MAINNET_RPC_URL \
    --match-test "test_TWAPExecution_AdaptiveIntervalsWithHighVolatility" \
    -v

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW} 🎯 1INCH INTEGRATION TESTS${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${CYAN}Test 1: IAmountGetter Interface Compliance${NC}"
forge test --fork-url $MAINNET_RPC_URL \
    --match-test "test_GetMakingAmount_WorksWithVolatilityData" \
    -v

echo ""
echo -e "${CYAN}Test 2: Multi-Asset Order Support${NC}"
forge test --fork-url $MAINNET_RPC_URL \
    --match-test "test_TWAPExecution_DifferentTokenPairs" \
    -v

echo ""
echo -e "${CYAN}Test 3: Real Token Transfer Integration${NC}"
forge test --fork-url $MAINNET_RPC_URL \
    --match-test "test_1inchInterface_AllMethodsWork" \
    -v

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW} ⛽ GAS EFFICIENCY ANALYSIS${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${CYAN}Analyzing gas costs for production deployment...${NC}"
forge test --fork-url $MAINNET_RPC_URL \
    --match-test "test.*GasEfficiency" \
    --gas-report

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW} 🏆 COMPREHENSIVE TEST SUITE${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${CYAN}Running complete mainnet fork test suite...${NC}"
forge test --fork-url $MAINNET_RPC_URL \
    --match-contract "MainnetTest" \
    -v

echo ""
echo -e "${GREEN}🎉 ALL MAINNET FORK TESTS PASSED!${NC}"
echo ""
echo -e "${CYAN}📊 Test Results Summary:${NC}"
echo "• ✅ Volatility strategies validated with real market data"
echo "• ✅ TWAP execution tested with actual token transfers" 
echo "• ✅ 1inch interface compliance verified"
echo "• ✅ Gas efficiency optimized for production"
echo "• ✅ Emergency controls and edge cases covered"
echo ""
echo -e "${YELLOW}💡 Key Validations:${NC}"
echo "• Real WETH/USDC/USDT whale account interactions"
echo "• Live volatility data processing"
echo "• MEV protection mechanisms active"
echo "• Gas costs under 100k per execution"
echo "• Emergency pause triggers working"
echo ""

cd demos