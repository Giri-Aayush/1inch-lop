
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/calculators/VolatilityCalculator.sol";
import "../../src/interfaces/IOrderMixin.sol";

contract VolatilityCalculatorTest is Test {
    VolatilityCalculator public calculator;
    
    function setUp() public {
        calculator = new VolatilityCalculator();
    }
    
    function testLowVolatilityIncrease() public view {
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1,
            maker: address(0x123),
            receiver: address(0x456),
            makerAsset: address(0x789),
            takerAsset: address(0xABC),
            makingAmount: 1000e18,
            takingAmount: 2000e18,
            makerTraits: 0
        });
        
        // Low volatility scenario - should increase execution size
        VolatilityCalculator.VolatilityData memory volData = VolatilityCalculator.VolatilityData({
            baselineVolatility: 200,     // 2% baseline
            currentVolatility: 150,      // 1.5% current (lower than baseline)
            maxExecutionSize: 1500e18,   // Max size
            minExecutionSize: 10e18,     // Min size
            volatilityThreshold: 400,    // 4% threshold
            lastUpdateTime: block.timestamp, // Fresh data
            conservativeMode: false
        });
        
        bytes memory extraData = abi.encode(volData);
        
        uint256 makingAmount = calculator.getMakingAmount(
            order,
            "",
            bytes32(0),
            address(0),
            100e18, // Taking 100 tokens
            1000e18,
            extraData
        );
        
        // Should get increased amount (120% of base = 60e18)
        uint256 expectedBase = (100e18 * order.makingAmount) / order.takingAmount; // 50e18
        uint256 expectedIncrease = expectedBase * 120 / 100; // 60e18
        
        assertEq(makingAmount, expectedIncrease, "Should increase amount for low volatility");
        assertTrue(makingAmount > expectedBase, "Amount should be increased");
    }
    
    function testHighVolatilityReduction() public view {
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1,
            maker: address(0x123),
            receiver: address(0x456),
            makerAsset: address(0x789),
            takerAsset: address(0xABC),
            makingAmount: 1000e18,
            takingAmount: 2000e18,
            makerTraits: 0
        });
        
        // High volatility scenario - should reduce execution size
        VolatilityCalculator.VolatilityData memory volData = VolatilityCalculator.VolatilityData({
            baselineVolatility: 200,     // 2% baseline
            currentVolatility: 600,      // 6% current (high volatility)
            maxExecutionSize: 1500e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,    // 4% threshold (exceeded)
            lastUpdateTime: block.timestamp,
            conservativeMode: false
        });
        
        bytes memory extraData = abi.encode(volData);
        
        uint256 makingAmount = calculator.getMakingAmount(
            order,
            "",
            bytes32(0),
            address(0),
            100e18,
            1000e18,
            extraData
        );
        
        uint256 expectedBase = (100e18 * order.makingAmount) / order.takingAmount; // 50e18
        
        assertTrue(makingAmount < expectedBase, "Amount should be reduced for high volatility");
        assertTrue(makingAmount >= volData.minExecutionSize, "Should respect minimum size");
    }
    
    function testConservativeMode() public view {
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1,
            maker: address(0x123),
            receiver: address(0x456),
            makerAsset: address(0x789),
            takerAsset: address(0xABC),
            makingAmount: 1000e18,
            takingAmount: 2000e18,
            makerTraits: 0
        });
        
        // Normal volatility with conservative mode
        VolatilityCalculator.VolatilityData memory volData = VolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 250,      // Between baseline and threshold
            maxExecutionSize: 1500e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: true       // Conservative mode enabled
        });
        
        bytes memory extraData = abi.encode(volData);
        
        uint256 makingAmount = calculator.getMakingAmount(
            order,
            "",
            bytes32(0),
            address(0),
            100e18,
            1000e18,
            extraData
        );
        
        uint256 expectedBase = (100e18 * order.makingAmount) / order.takingAmount; // 50e18
        uint256 expectedConservative = expectedBase * 90 / 100; // 45e18 (10% reduction)
        
        assertEq(makingAmount, expectedConservative, "Should apply 10% reduction in conservative mode");
    }
    
    function testVolatilityTooHigh() public {
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1,
            maker: address(0x123),
            receiver: address(0x456),
            makerAsset: address(0x789),
            takerAsset: address(0xABC),
            makingAmount: 1000e18,
            takingAmount: 2000e18,
            makerTraits: 0
        });
        
        // Extremely high volatility - should revert
        VolatilityCalculator.VolatilityData memory volData = VolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 2000,     // 20% - extremely high (>3x threshold)
            maxExecutionSize: 1500e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,    // 4% threshold
            lastUpdateTime: block.timestamp,
            conservativeMode: false
        });
        
        bytes memory extraData = abi.encode(volData);
        
        vm.expectRevert(VolatilityCalculator.VolatilityTooHigh.selector);
        calculator.getMakingAmount(
            order,
            "",
            bytes32(0),
            address(0),
            100e18,
            1000e18,
            extraData
        );
    }
    
    function testStaleData() public {
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1,
            maker: address(0x123),
            receiver: address(0x456),
            makerAsset: address(0x789),
            takerAsset: address(0xABC),
            makingAmount: 1000e18,
            takingAmount: 2000e18,
            makerTraits: 0
        });
        
        // Move time forward to make data stale
        vm.warp(10000);
        
        // Stale data (older than 1 hour)
        VolatilityCalculator.VolatilityData memory volData = VolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 300,
            maxExecutionSize: 1500e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: 5000,        // 5000 seconds ago (stale)
            conservativeMode: false
        });
        
        bytes memory extraData = abi.encode(volData);
        
        vm.expectRevert(VolatilityCalculator.InvalidVolatilityData.selector);
        calculator.getMakingAmount(
            order,
            "",
            bytes32(0),
            address(0),
            100e18,
            1000e18,
            extraData
        );
    }
    
    function testInvalidVolatilityData() public {
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1,
            maker: address(0x123),
            receiver: address(0x456),
            makerAsset: address(0x789),
            takerAsset: address(0xABC),
            makingAmount: 1000e18,
            takingAmount: 2000e18,
            makerTraits: 0
        });
        
        // Invalid data: max < min
        VolatilityCalculator.VolatilityData memory volData = VolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 300,
            maxExecutionSize: 10e18,     // Max smaller than min!
            minExecutionSize: 100e18,    // Min larger than max!
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: false
        });
        
        bytes memory extraData = abi.encode(volData);
        
        vm.expectRevert(VolatilityCalculator.InvalidVolatilityData.selector);
        calculator.getMakingAmount(
            order,
            "",
            bytes32(0),
            address(0),
            100e18,
            1000e18,
            extraData
        );
    }
    
    function testGetTakingAmount() public view {
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1,
            maker: address(0x123),
            receiver: address(0x456),
            makerAsset: address(0x789),
            takerAsset: address(0xABC),
            makingAmount: 1000e18,
            takingAmount: 2000e18,
            makerTraits: 0
        });
        
        VolatilityCalculator.VolatilityData memory volData = VolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 150,      // Low volatility
            maxExecutionSize: 1500e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: false
        });
        
        bytes memory extraData = abi.encode(volData);
        
        uint256 takingAmount = calculator.getTakingAmount(
            order,
            "",
            bytes32(0),
            address(0),
            50e18,  // Making 50 tokens
            1000e18,
            extraData
        );
        
        // Should get taking amount with low volatility increase
        assertTrue(takingAmount > 0, "Taking amount should be positive");
        
        // Base calculation: (50e18 * 2000e18) / 1000e18 = 100e18
        // With 20% increase: 120e18
        uint256 expectedBase = (50e18 * order.takingAmount) / order.makingAmount;
        uint256 expectedIncrease = expectedBase * 120 / 100;
        
        assertEq(takingAmount, expectedIncrease, "Should calculate taking amount correctly");
    }
    
    function testGetVolatilityAdjustmentFactor() public view {
        // Test low volatility
        VolatilityCalculator.VolatilityData memory lowVolData = VolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 150,
            maxExecutionSize: 1500e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: false
        });
        
        uint256 factor = calculator.getVolatilityAdjustmentFactor(lowVolData);
        assertEq(factor, 120, "Low volatility should return 120 (20% increase)");
        
        // Test high volatility
        VolatilityCalculator.VolatilityData memory highVolData = VolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 600,
            maxExecutionSize: 1500e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: false
        });
        
        uint256 highFactor = calculator.getVolatilityAdjustmentFactor(highVolData);
        assertTrue(highFactor < 100, "High volatility should reduce factor");
        
        // Test conservative mode
        VolatilityCalculator.VolatilityData memory conservativeData = VolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 250,  // Normal volatility
            maxExecutionSize: 1500e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: true
        });
        
        uint256 conservativeFactor = calculator.getVolatilityAdjustmentFactor(conservativeData);
        assertEq(conservativeFactor, 90, "Conservative mode should return 90 (10% reduction)");
    }
}
