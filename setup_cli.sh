#!/bin/bash

# Setup CLI for 1inch Advanced Trading Strategies
# Minimal changes to your existing structure

echo "🚀 Setting up CLI for 1inch Advanced Trading Strategies..."

# Step 1: Minimal cleanup (keeps everything you have)
echo "📁 Organizing project structure..."
./cleanup_and_organize.sh

# Step 2: Make CLI executable
echo "🔧 Setting up CLI interface..."
chmod +x cli/1inch-strategies.sh

# Step 3: Create convenient launcher in root
cat > 1inch-cli.sh << 'EOF'
#!/bin/bash
# Launcher for 1inch Advanced Trading Strategies CLI
cd "$(dirname "$0")"
./cli/1inch-strategies.sh "$@"
EOF

chmod +x 1inch-cli.sh

# Step 4: Test basic functionality
echo "🧪 Testing basic setup..."
if forge build > /dev/null 2>&1; then
    echo "✅ Compilation works"
else
    echo "❌ Compilation issues detected"
fi

echo ""
echo "✅ CLI setup completed!"
echo ""
echo "🎯 Ready to use:"
echo "   ./1inch-cli.sh              # Start the CLI"
echo "   ./cli/1inch-strategies.sh   # Direct CLI access"
echo ""
echo "📂 Your structure (preserved):"
echo "   ├── src/                    # Your contracts (unchanged)"
echo "   ├── test/                   # Your tests (unchanged)"
echo "   ├── cli/                    # NEW: CLI interface"
echo "   ├── results/                # Organized test results"
echo "   └── 1inch-cli.sh           # Convenient launcher"
echo ""
echo "🏆 Ready for bounty submission workflow!"