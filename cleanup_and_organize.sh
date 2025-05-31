#!/bin/bash

# Minimal cleanup and organization for 1inch Advanced Trading Strategies
# Keeps your existing structure but adds CLI layer

echo "🧹 Cleaning up and organizing project..."

# Create CLI directory (only new addition)
mkdir -p cli

# Organize existing test results
mkdir -p results
if [ -f "mainnet_test_results.txt" ]; then
    mv mainnet_test_results.txt results/
fi
if [ -f "comprehensive_test_results.txt" ]; then
    mv comprehensive_test_results.txt results/
fi

# Keep your existing structure exactly as is:
# ✅ src/ (your contracts - no changes)
# ✅ test/ (your tests - no changes) 
# ✅ script/ (if exists - no changes)

echo "📁 Current structure (preserved):"
echo "├── src/                        # Your contracts (unchanged)"
echo "│   ├── calculators/            # Strategy contracts"
echo "│   └── interfaces/             # Contract interfaces"
echo "├── test/                       # Your tests (unchanged)"
echo "│   ├── integration/            # Integration tests"
echo "│   ├── mainnet-fork-tests/     # Mainnet fork tests"
echo "│   └── unit/                   # Unit tests"
echo "├── cli/                        # NEW: CLI interface"
echo "├── results/                    # Test results (organized)"
echo "└── foundry.toml                # Your config (unchanged)"

echo ""
echo "✅ Minimal cleanup completed!"
echo "✅ All your existing work preserved"
echo "✅ Ready for CLI development"