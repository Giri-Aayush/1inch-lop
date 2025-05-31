#!/bin/bash

# Vector Plus Deployment Manager
# One-click deployment to any 1inch-supported network

set -e

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color

# Supported networks
readonly SUPPORTED_NETWORKS=("mainnet" "polygon" "arbitrum" "base" "optimism" "localhost")

print_header() {
    echo -e "${PURPLE}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                VECTOR PLUS DEPLOYMENT                 ║"
    echo "║           Advanced Trading Strategies CLI             ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

print_usage() {
    echo -e "${CYAN}Usage: $0 [NETWORK] [OPTIONS]${NC}"
    echo
    echo -e "${YELLOW}Supported Networks:${NC}"
    for network in "${SUPPORTED_NETWORKS[@]}"; do
        echo "  • $network"
    done
    echo
    echo -e "${YELLOW}Options:${NC}"
    echo "  --verify          Verify contracts on block explorer"
    echo "  --gas-price GWEI  Set gas price in GWEI"
    echo "  --dry-run         Simulate deployment without broadcasting"
    echo "  --help            Show this help message"
    echo
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 mainnet --verify"
    echo "  $0 polygon --gas-price 50"
    echo "  $0 localhost --dry-run"
    echo
}

check_prerequisites() {
    echo -e "${CYAN}🔍 Checking prerequisites...${NC}"
    
    # Check if forge is installed
    if ! command -v forge &> /dev/null; then
        echo -e "${RED}❌ Foundry not found. Please install: https://getfoundry.sh${NC}"
        exit 1
    fi
    
    # Check if .env file exists
    if [[ ! -f ".env" ]]; then
        echo -e "${YELLOW}⚠️  .env file not found. Creating from template...${NC}"
        cp .env.example .env
        echo -e "${YELLOW}📝 Please edit .env file with your configuration${NC}"
        echo -e "${YELLOW}   Especially: PRIVATE_KEY, RPC URLs, and API keys${NC}"
        exit 1
    fi
    
    # Source environment variables
    source .env
    
    # Check if private key is set
    if [[ -z "$PRIVATE_KEY" || "$PRIVATE_KEY" == "0x1234567890abcdef..." ]]; then
        echo -e "${RED}❌ PRIVATE_KEY not set in .env file${NC}"
        exit 1
    fi
    
    # Check if contracts are compiled
    if [[ ! -d "out" ]]; then
        echo -e "${YELLOW}⚠️  Contracts not compiled. Building...${NC}"
        forge build
    fi
    
    echo -e "${GREEN}✅ Prerequisites verified${NC}"
    echo
}

validate_network() {
    local network=$1
    
    if [[ ! " ${SUPPORTED_NETWORKS[@]} " =~ " ${network} " ]]; then
        echo -e "${RED}❌ Unsupported network: $network${NC}"
        echo -e "${YELLOW}Supported networks: ${SUPPORTED_NETWORKS[*]}${NC}"
        exit 1
    fi
}

get_rpc_url() {
    local network=$1
    
    case $network in
        mainnet)
            echo "$MAINNET_RPC_URL"
            ;;
        polygon)
            echo "$POLYGON_RPC_URL"
            ;;
        arbitrum)
            echo "$ARBITRUM_RPC_URL"
            ;;
        base)
            echo "$BASE_RPC_URL"
            ;;
        optimism)
            echo "$OPTIMISM_RPC_URL"
            ;;
        localhost)
            echo "http://localhost:8545"
            ;;
        *)
            echo ""
            ;;
    esac
}

create_deployments_dir() {
    mkdir -p deployments
    echo -e "${CYAN}📁 Created deployments directory${NC}"
}

deploy_contracts() {
    local network=$1
    local verify_flag=$2
    local gas_price=$3
    local dry_run=$4
    
    echo -e "${BLUE}🚀 Deploying Vector Plus to $network...${NC}"
    echo
    
    local rpc_url=$(get_rpc_url $network)
    if [[ -z "$rpc_url" ]]; then
        echo -e "${RED}❌ RPC URL not configured for $network${NC}"
        echo -e "${YELLOW}Please set ${network^^}_RPC_URL in .env file${NC}"
        exit 1
    fi
    
    # Build forge command
    local forge_cmd="forge script script/Deploy.s.sol"
    forge_cmd="$forge_cmd --rpc-url $rpc_url"
    forge_cmd="$forge_cmd --private-key $PRIVATE_KEY"
    
    if [[ $dry_run != true ]]; then
        forge_cmd="$forge_cmd --broadcast"
    else
        echo -e "${YELLOW}🔍 Dry run mode - will not broadcast transactions${NC}"
    fi
    
    if [[ -n "$gas_price" ]]; then
        local gas_price_wei=$((gas_price * 1000000000))
        forge_cmd="$forge_cmd --gas-price $gas_price_wei"
        echo -e "${YELLOW}⛽ Using gas price: $gas_price GWEI${NC}"
    fi
    
    if [[ $verify_flag == true && $dry_run != true ]]; then
        case $network in
            mainnet)
                forge_cmd="$forge_cmd --verify --etherscan-api-key $ETHERSCAN_API_KEY"
                ;;
            polygon)
                forge_cmd="$forge_cmd --verify --etherscan-api-key $POLYGONSCAN_API_KEY"
                ;;
            arbitrum)
                forge_cmd="$forge_cmd --verify --etherscan-api-key $ARBISCAN_API_KEY"
                ;;
        esac
        echo -e "${YELLOW}🔍 Contract verification enabled${NC}"
    fi
    
    # Set environment variable for deployment script
    export NETWORK=$network
    
    echo -e "${CYAN}📡 Executing deployment...${NC}"
    echo -e "${YELLOW}Command: $forge_cmd${NC}"
    echo
    
    # Execute deployment
    eval $forge_cmd
    
    if [[ $? -eq 0 && $dry_run != true ]]; then
        echo
        echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
        echo -e "${CYAN}📊 Deployment details saved to: deployments/$network-deployment.json${NC}"
        
        # Update CLI configuration
        update_cli_config $network
    else
        echo -e "${RED}❌ Deployment failed or was simulated${NC}"
        exit 1
    fi
}

update_cli_config() {
    local network=$1
    local deployment_file="deployments/$network-deployment.json"
    
    if [[ -f "$deployment_file" ]]; then
        echo -e "${CYAN}🔧 Updating Vector Plus CLI configuration...${NC}"
        
        # Create CLI config file
        cat > "vector-plus-$network.json" << EOF
{
  "network": "$network",
  "rpcUrl": "$(get_rpc_url $network)",
  "contracts": $(cat $deployment_file | jq '.contracts'),
  "deploymentBlock": $(cat $deployment_file | jq '.blockNumber'),
  "timestamp": $(cat $deployment_file | jq '.timestamp')
}
EOF
        
        echo -e "${GREEN}✅ CLI config created: vector-plus-$network.json${NC}"
        echo
        echo -e "${YELLOW}💡 Use with CLI:${NC}"
        echo -e "${CYAN}  vector-plus --network $network --config vector-plus-$network.json${NC}"
    fi
}

run_post_deployment_tests() {
    local network=$1
    
    echo -e "${BLUE}🧪 Running post-deployment tests...${NC}"
    
    if [[ "$network" == "localhost" ]]; then
        # Run local tests
        forge test -vv
    else
        # Run fork tests against deployed contracts
        local rpc_url=$(get_rpc_url $network)
        forge test --fork-url "$rpc_url" --match-contract "DeploymentTest" -v
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
    else
        echo -e "${YELLOW}⚠️  Some tests failed. Please review the output.${NC}"
    fi
}

main() {
    print_header
    
    # Parse arguments
    local network=""
    local verify_flag=false
    local gas_price=""
    local dry_run=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verify)
                verify_flag=true
                shift
                ;;
            --gas-price)
                gas_price="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            -*)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                print_usage
                exit 1
                ;;
            *)
                if [[ -z "$network" ]]; then
                    network="$1"
                else
                    echo -e "${RED}❌ Multiple networks specified${NC}"
                    print_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Default to localhost if no network specified
    if [[ -z "$network" ]]; then
        network="localhost"
    fi
    
    validate_network "$network"
    check_prerequisites
    create_deployments_dir
    
    echo -e "${YELLOW}🎯 Deployment Configuration:${NC}"
    echo -e "${CYAN}  Network: $network${NC}"
    echo -e "${CYAN}  Verify: $verify_flag${NC}"
    echo -e "${CYAN}  Gas Price: ${gas_price:-"default"}${NC}"
    echo -e "${CYAN}  Dry Run: $dry_run${NC}"
    echo
    
    deploy_contracts "$network" "$verify_flag" "$gas_price" "$dry_run"
    
    if [[ $dry_run != true ]]; then
        run_post_deployment_tests "$network"
        
        echo
        echo -e "${GREEN}🚀 Vector Plus deployment complete!${NC}"
        echo
        echo -e "${YELLOW}Next steps:${NC}"
        echo -e "${CYAN}  1. Test the CLI: cd cli && ./target/release/vector-plus --network $network${NC}"
        echo -e "${CYAN}  2. Run demos: cd demos && ./vector-plus-showcase.sh${NC}"
        echo -e "${CYAN}  3. Integrate with your application using the deployed contracts${NC}"
    fi
}

# Execute main function
main "$@"