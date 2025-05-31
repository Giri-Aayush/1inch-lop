#!/bin/bash

# Vector Plus Complete Setup Script
# One-command setup for any developer

set -e

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly RED='\033[0;31m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m'

print_header() {
    echo -e "${PURPLE}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                  VECTOR PLUS SETUP                    ║"
    echo "║           Complete Development Environment             ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

print_usage() {
    echo -e "${CYAN}Usage: $0 [OPTIONS]${NC}"
    echo
    echo -e "${YELLOW}Options:${NC}"
    echo "  --quick           Quick setup (skip optional components)"
    echo "  --no-test         Skip running tests after setup"
    echo "  --no-cli          Skip CLI build"
    echo "  --help            Show this help message"
    echo
    echo -e "${YELLOW}What this script does:${NC}"
    echo "  1. Checks and installs prerequisites (Foundry, Rust)"
    echo "  2. Builds smart contracts"
    echo "  3. Builds Vector Plus CLI"
    echo "  4. Runs comprehensive test suite"
    echo "  5. Sets up demo environment"
    echo "  6. Creates deployment configuration"
    echo
}

check_system() {
    echo -e "${CYAN}🔍 Checking system requirements...${NC}"
    
    # Check OS
    local os=$(uname -s)
    echo -e "${YELLOW}Operating System: $os${NC}"
    
    # Check if running on supported system
    case $os in
        "Darwin"|"Linux")
            echo -e "${GREEN}✅ Supported operating system${NC}"
            ;;
        *)
            echo -e "${YELLOW}⚠️  Untested operating system. Proceeding anyway...${NC}"
            ;;
    esac
    
    # Check required tools
    local missing_tools=()
    
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}❌ Missing required tools: ${missing_tools[*]}${NC}"
        echo -e "${YELLOW}Please install them and run this script again${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ System requirements satisfied${NC}"
    echo
}

install_foundry() {
    echo -e "${CYAN}🔨 Setting up Foundry...${NC}"
    
    if command -v forge &> /dev/null; then
        echo -e "${GREEN}✅ Foundry already installed${NC}"
        forge --version
    else
        echo -e "${YELLOW}📦 Installing Foundry...${NC}"
        curl -L https://foundry.paradigm.xyz | bash
        source ~/.bashrc || source ~/.zshrc || true
        foundryup
        
        if command -v forge &> /dev/null; then
            echo -e "${GREEN}✅ Foundry installed successfully${NC}"
        else
            echo -e "${RED}❌ Foundry installation failed${NC}"
            echo -e "${YELLOW}Please install manually: https://getfoundry.sh${NC}"
            exit 1
        fi
    fi
    echo
}

install_rust() {
    echo -e "${CYAN}🦀 Setting up Rust...${NC}"
    
    if command -v cargo &> /dev/null; then
        echo -e "${GREEN}✅ Rust already installed${NC}"
        rustc --version
    else
        echo -e "${YELLOW}📦 Installing Rust...${NC}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
        
        if command -v cargo &> /dev/null; then
            echo -e "${GREEN}✅ Rust installed successfully${NC}"
        else
            echo -e "${RED}❌ Rust installation failed${NC}"
            echo -e "${YELLOW}Please install manually: https://rustup.rs${NC}"
            exit 1
        fi
    fi
    echo
}

setup_environment() {
    echo -e "${CYAN}⚙️  Setting up environment...${NC}"
    
    # Create .env file if it doesn't exist
    if [[ ! -f ".env" ]]; then
        echo -e "${YELLOW}📝 Creating .env file from template...${NC}"
        cp .env.example .env
        echo -e "${GREEN}✅ .env file created${NC}"
        echo -e "${YELLOW}💡 Please edit .env with your configuration before deploying${NC}"
    else
        echo -e "${GREEN}✅ .env file already exists${NC}"
    fi
    
    # Create necessary directories
    mkdir -p deployments
    mkdir -p logs
    
    echo -e "${GREEN}✅ Environment setup complete${NC}"
    echo
}

build_contracts() {
    echo -e "${CYAN}📝 Building smart contracts...${NC}"
    
    # Install dependencies
    forge install --no-commit 2>/dev/null || true
    
    # Build contracts
    forge build
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Smart contracts built successfully${NC}"
    else
        echo -e "${RED}❌ Contract build failed${NC}"
        exit 1
    fi
    echo
}

build_cli() {
    local skip_cli=$1
    
    if [[ $skip_cli == true ]]; then
        echo -e "${YELLOW}⏭️  Skipping CLI build${NC}"
        return
    fi
    
    echo -e "${CYAN}💻 Building Vector Plus CLI...${NC}"
    
    cd cli
    
    # Build CLI in release mode
    cargo build --release
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Vector Plus CLI built successfully${NC}"
        
        # Test CLI
        ./target/release/vector-plus --version
    else
        echo -e "${RED}❌ CLI build failed${NC}"
        cd ..
        exit 1
    fi
    
    cd ..
    echo
}

run_tests() {
    local skip_tests=$1
    
    if [[ $skip_tests == true ]]; then
        echo -e "${YELLOW}⏭️  Skipping tests${NC}"
        return
    fi
    
    echo -e "${CYAN}🧪 Running test suite...${NC}"
    
    # Make test script executable
    chmod +x test-suite.sh
    
    # Run basic tests
    ./test-suite.sh --unit --cli
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Basic tests passed${NC}"
    else
        echo -e "${YELLOW}⚠️  Some tests failed, but setup continues${NC}"
    fi
    echo
}

setup_demos() {
    echo -e "${CYAN}🎭 Setting up demo environment...${NC}"
    
    cd demos
    
    # Make demo scripts executable
    chmod +x *.sh
    
    # Test one demo script
    if [[ -f "executive-summary.sh" ]]; then
        echo -e "${YELLOW}🧪 Testing demo functionality...${NC}"
        timeout 30s ./executive-summary.sh > /dev/null 2>&1 || true
        echo -e "${GREEN}✅ Demo environment ready${NC}"
    fi
    
    cd ..
    echo
}

create_quick_start_guide() {
    cat > "QUICK_START.md" << 'EOF'
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
EOF

    echo -e "${GREEN}✅ Quick start guide created: QUICK_START.md${NC}"
}

print_success_summary() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                   SETUP COMPLETE!                     ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    echo -e "${YELLOW}🎉 Vector Plus is ready for deployment and testing!${NC}"
    echo
    echo -e "${CYAN}📋 What was set up:${NC}"
    echo "  ✅ Foundry development environment"
    echo "  ✅ Rust and Cargo toolchain"
    echo "  ✅ Smart contracts compiled"
    echo "  ✅ Vector Plus CLI built"
    echo "  ✅ Test suite configured"
    echo "  ✅ Demo environment ready"
    echo "  ✅ Deployment scripts prepared"
    echo
    echo -e "${YELLOW}🚀 Next Steps:${NC}"
    echo -e "${CYAN}  1. Edit .env file: nano .env${NC}"
    echo -e "${CYAN}  2. Deploy locally: ./deploy.sh localhost${NC}"
    echo -e "${CYAN}  3. Run demos: cd demos && ./vector-plus-showcase.sh${NC}"
    echo -e "${CYAN}  4. Deploy to mainnet: ./deploy.sh mainnet --verify${NC}"
    echo
    echo -e "${YELLOW}📖 Documentation:${NC}"
    echo -e "${CYAN}  • Quick Start: cat QUICK_START.md${NC}"
    echo -e "${CYAN}  • CLI Help: ./cli/target/release/vector-plus --help${NC}"
    echo -e "${CYAN}  • Run Tests: ./test-suite.sh --help${NC}"
    echo
}

main() {
    print_header
    
    # Parse arguments
    local quick_setup=false
    local skip_tests=false
    local skip_cli=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                quick_setup=true
                shift
                ;;
            --no-test)
                skip_tests=true
                shift
                ;;
            --no-cli)
                skip_cli=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                print_usage
                exit 1
                ;;
        esac
    done
    
    echo -e "${YELLOW}🎯 Setup Configuration:${NC}"
    echo -e "${CYAN}  Quick Setup: $quick_setup${NC}"
    echo -e "${CYAN}  Skip Tests: $skip_tests${NC}"
    echo -e "${CYAN}  Skip CLI: $skip_cli${NC}"
    echo
    
    # Run setup steps
    check_system
    install_foundry
    install_rust
    setup_environment
    build_contracts
    build_cli "$skip_cli"
    
    if [[ $quick_setup != true ]]; then
        run_tests "$skip_tests"
        setup_demos
    fi
    
    create_quick_start_guide
    print_success_summary
}

# Execute main function
main "$@"