// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/calculators/EnhancedVolatilityCalculator.sol";
import "../src/calculators/EnhancedTWAPVolatilityExecutor.sol";
import "../src/calculators/OptionsCalculator.sol";

/**
 * @title Deploy
 * @notice Deployment script for Vector Plus trading strategies
 * @dev Deploys all calculator contracts to any 1inch-supported network
 */
contract Deploy is Script {
    
    // Deployment configuration
    struct DeploymentConfig {
        address feeCollector;
        bool verify;
        uint256 deployerPrivateKey;
        string network;
    }
    
    // Deployed contract addresses
    struct DeployedContracts {
        address volatilityCalculator;
        address twapExecutor;
        address optionsCalculator;
        uint256 blockNumber;
        string network;
    }
    
    function run() external {
        DeploymentConfig memory config = _getDeploymentConfig();
        
        console.log("===========================================");
        console.log("         VECTOR PLUS DEPLOYMENT");
        console.log("===========================================");
        console.log("Network:", config.network);
        console.log("Fee Collector:", config.feeCollector);
        console.log("Verify Contracts:", config.verify);
        console.log("===========================================");
        
        vm.startBroadcast(config.deployerPrivateKey);
        
        DeployedContracts memory deployed = _deployContracts(config);
        
        vm.stopBroadcast();
        
        _saveDeployment(deployed);
        _printDeploymentSummary(deployed);
        
        if (config.verify) {
            _verifyContracts(deployed);
        }
    }
    
    function _getDeploymentConfig() internal view returns (DeploymentConfig memory config) {
        // Get configuration from environment variables
        config.deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        config.feeCollector = vm.envOr("FEE_COLLECTOR", msg.sender);
        config.verify = vm.envOr("VERIFY_CONTRACTS", false);
        config.network = vm.envOr("NETWORK", string("localhost"));
        
        // Network-specific fee collector addresses
        if (keccak256(bytes(config.network)) == keccak256(bytes("mainnet"))) {
            config.feeCollector = vm.envOr("MAINNET_FEE_COLLECTOR", config.feeCollector);
        } else if (keccak256(bytes(config.network)) == keccak256(bytes("polygon"))) {
            config.feeCollector = vm.envOr("POLYGON_FEE_COLLECTOR", config.feeCollector);
        } else if (keccak256(bytes(config.network)) == keccak256(bytes("arbitrum"))) {
            config.feeCollector = vm.envOr("ARBITRUM_FEE_COLLECTOR", config.feeCollector);
        }
    }
    
    function _deployContracts(DeploymentConfig memory config) 
        internal 
        returns (DeployedContracts memory deployed) 
    {
        deployed.network = config.network;
        deployed.blockNumber = block.number;
        
        console.log("\n🔧 Deploying EnhancedVolatilityCalculator...");
        EnhancedVolatilityCalculator volatilityCalc = new EnhancedVolatilityCalculator();
        deployed.volatilityCalculator = address(volatilityCalc);
        console.log("✅ EnhancedVolatilityCalculator deployed:", deployed.volatilityCalculator);
        
        console.log("\n🔧 Deploying EnhancedTWAPVolatilityExecutor...");
        EnhancedTWAPVolatilityExecutor twapExecutor = new EnhancedTWAPVolatilityExecutor(
            deployed.volatilityCalculator
        );
        deployed.twapExecutor = address(twapExecutor);
        console.log("✅ EnhancedTWAPVolatilityExecutor deployed:", deployed.twapExecutor);
        
        console.log("\n🔧 Deploying OptionsCalculator...");
        OptionsCalculator optionsCalc = new OptionsCalculator(config.feeCollector);
        deployed.optionsCalculator = address(optionsCalc);
        console.log("✅ OptionsCalculator deployed:", deployed.optionsCalculator);
        
        console.log("\n🎉 All contracts deployed successfully!");
    }
    
    function _saveDeployment(DeployedContracts memory deployed) internal {
        string memory deploymentJson = string(abi.encodePacked(
            '{\n',
            '  "network": "', deployed.network, '",\n',
            '  "blockNumber": ', vm.toString(deployed.blockNumber), ',\n',
            '  "timestamp": ', vm.toString(block.timestamp), ',\n',
            '  "contracts": {\n',
            '    "EnhancedVolatilityCalculator": "', vm.toString(deployed.volatilityCalculator), '",\n',
            '    "EnhancedTWAPVolatilityExecutor": "', vm.toString(deployed.twapExecutor), '",\n',
            '    "OptionsCalculator": "', vm.toString(deployed.optionsCalculator), '"\n',
            '  }\n',
            '}'
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/",
            deployed.network,
            "-deployment.json"
        ));
        
        vm.writeFile(filename, deploymentJson);
        console.log("\n💾 Deployment saved to:", filename);
    }
    
    function _printDeploymentSummary(DeployedContracts memory deployed) internal pure {
        console.log("\n===========================================");
        console.log("         DEPLOYMENT SUMMARY");
        console.log("===========================================");
        console.log("Network:", deployed.network);
        console.log("Block Number:", deployed.blockNumber);
        console.log("");
        console.log("📊 EnhancedVolatilityCalculator:");
        console.log("   ", deployed.volatilityCalculator);
        console.log("");
        console.log("⏱️  EnhancedTWAPVolatilityExecutor:");
        console.log("   ", deployed.twapExecutor);
        console.log("");
        console.log("📞 OptionsCalculator:");
        console.log("   ", deployed.optionsCalculator);
        console.log("===========================================");
        console.log("🚀 Ready for Vector Plus CLI integration!");
        console.log("===========================================");
    }
    
    function _verifyContracts(DeployedContracts memory deployed) internal pure {
        console.log("\n🔍 Contract verification will be handled by --verify flag");
        console.log("Use: forge script script/Deploy.s.sol --verify --etherscan-api-key $ETHERSCAN_API_KEY");
    }
}