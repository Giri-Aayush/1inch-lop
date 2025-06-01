// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/calculators/EnhancedVolatilityCalculator.sol";
import "../../src/calculators/EnhancedTWAPVolatilityExecutor.sol";

contract EnhancedTWAPVolatilityTest is Test {
    EnhancedVolatilityCalculator public volatilityCalc;
    EnhancedTWAPVolatilityExecutor public twapExecutor;

    function setUp() public {
        volatilityCalc = new EnhancedVolatilityCalculator();
        twapExecutor = new EnhancedTWAPVolatilityExecutor(address(volatilityCalc));
        vm.warp(1_685_000_000); // Set base timestamp
    }

    function testHighVolatilityReducesAmount() public view {
        EnhancedVolatilityCalculator.VolatilityData memory volData = EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 200, // 2%
            currentVolatility: 600, // 6% (high)
            maxExecutionSize: 100e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400, // 4%
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 1000 // 10%
         });

        uint256 baseAmount = 50e18;
        uint256 adjustedAmount = volatilityCalc.applyVolatilityAdjustment(baseAmount, volData);

        assertTrue(adjustedAmount < baseAmount, "High volatility should reduce amount");
        assertTrue(adjustedAmount >= volData.minExecutionSize, "Should respect minimum");
    }

    function testLowVolatilityIncreasesAmount() public view {
        EnhancedVolatilityCalculator.VolatilityData memory volData = EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 100, // 1% (low)
            maxExecutionSize: 100e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 1000
        });

        uint256 baseAmount = 50e18;
        uint256 adjustedAmount = volatilityCalc.applyVolatilityAdjustment(baseAmount, volData);

        assertTrue(adjustedAmount > baseAmount, "Low volatility should increase amount");
        assertTrue(adjustedAmount <= volData.maxExecutionSize, "Should respect maximum");
    }

    function testEmergencyPause() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 1200, // 12% (emergency level)
            maxExecutionSize: 100e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 1000 // 10% threshold
         });

        // Should revert with EmergencyModeTriggered since currentVolatility > emergencyThreshold
        vm.expectRevert(EnhancedVolatilityCalculator.EmergencyModeTriggered.selector);
        volatilityCalc.validateVolatilityData(volData);
    }

    function testVolatilityTooHigh() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 1200, // 6x baseline (over 5x limit)
            maxExecutionSize: 100e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 2000 // Higher than current volatility
         });

        // Should revert with VolatilityTooHigh since currentVolatility > baseline * 5
        vm.expectRevert(EnhancedVolatilityCalculator.VolatilityTooHigh.selector);
        volatilityCalc.validateVolatilityData(volData);
    }

    function testTWAPVolatilityIntegration() public view {
        IOrderMixin.Order memory order = _createTestOrder(1000e18, 500e18);

        EnhancedTWAPVolatilityExecutor.TWAPData memory twapData = EnhancedTWAPVolatilityExecutor.TWAPData({
            startTime: block.timestamp,
            duration: 3600, // 1 hour
            intervals: 12, // 5 min intervals
            baseInterval: 300, // 5 minutes
            lastExecutionTime: 0,
            executedAmount: 0,
            randomizeExecution: false,
            adaptiveIntervals: true
        });

        EnhancedVolatilityCalculator.VolatilityData memory volData = EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 600, // High volatility
            maxExecutionSize: 100e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 1000
        });

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory combinedData =
            EnhancedTWAPVolatilityExecutor.CombinedStrategyData({ twap: twapData, volatility: volData });

        bytes memory extraData = abi.encode(combinedData);

        uint256 amount =
            twapExecutor.getMakingAmount(order, "", keccak256("test"), address(0), 50e18, 1000e18, extraData);

        assertTrue(amount > 0, "Should allow execution");
        assertTrue(amount <= 100e18, "Should respect volatility limits");
    }

    function testAdaptiveIntervals() public view {
        EnhancedVolatilityCalculator.VolatilityData memory highVolData = EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 600, // High volatility
            maxExecutionSize: 100e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 1000
        });

        EnhancedVolatilityCalculator.VolatilityData memory lowVolData = EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 50, // Very low volatility
            maxExecutionSize: 100e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 1000
        });

        uint256 baseInterval = 300; // 5 minutes

        uint256 highVolInterval = volatilityCalc.getAdjustedInterval(baseInterval, highVolData);
        uint256 lowVolInterval = volatilityCalc.getAdjustedInterval(baseInterval, lowVolData);

        assertTrue(highVolInterval < baseInterval, "High volatility should shorten intervals");
        assertTrue(lowVolInterval > baseInterval, "Low volatility should lengthen intervals");
    }

    function testRiskScoreCalculation() public view {
        EnhancedVolatilityCalculator.VolatilityData memory lowRisk = EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 150, // Below baseline
            maxExecutionSize: 100e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 1000
        });

        EnhancedVolatilityCalculator.VolatilityData memory highRisk = EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 800, // 4x baseline
            maxExecutionSize: 100e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 1000
        });

        uint256 lowRiskScore = volatilityCalc.calculateRiskScore(lowRisk);
        uint256 highRiskScore = volatilityCalc.calculateRiskScore(highRisk);

        assertTrue(lowRiskScore <= 200, "Low risk should have low score");
        assertTrue(highRiskScore >= 800, "High risk should have high score");
        assertTrue(highRiskScore > lowRiskScore, "Risk scores should correlate with volatility");
    }

    function testExecutionProgress() public view {
        IOrderMixin.Order memory order = _createTestOrder(1000e18, 500e18);
        uint256 remainingAmount = 300e18; // 70% executed

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory data = _createCombinedData();
        bytes memory extraData = abi.encode(data);

        uint256 progress = twapExecutor.getExecutionProgress(order, remainingAmount, extraData);

        assertEq(progress, 7000, "Should show 70% progress (7000 basis points)");
    }

    function testStaleDataRevert() public {
        EnhancedVolatilityCalculator.VolatilityData memory staleData = EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 300,
            maxExecutionSize: 100e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp - 7200, // 2 hours old
            conservativeMode: false,
            emergencyThreshold: 1000
        });

        vm.expectRevert(EnhancedVolatilityCalculator.StaleVolatilityData.selector);
        volatilityCalc.validateVolatilityData(staleData);
    }

    function testRandomizedExecution() public view {
        IOrderMixin.Order memory order = _createTestOrder(1000e18, 500e18);

        EnhancedTWAPVolatilityExecutor.TWAPData memory twapData = EnhancedTWAPVolatilityExecutor.TWAPData({
            startTime: block.timestamp,
            duration: 3600,
            intervals: 12,
            baseInterval: 300,
            lastExecutionTime: 0,
            executedAmount: 0,
            randomizeExecution: true, // Enable randomization
            adaptiveIntervals: false
        });

        EnhancedVolatilityCalculator.VolatilityData memory volData = _createVolatilityData();

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory combinedData =
            EnhancedTWAPVolatilityExecutor.CombinedStrategyData({ twap: twapData, volatility: volData });

        bytes memory extraData = abi.encode(combinedData);

        // Execute multiple times with different order hashes to see randomization
        uint256 amount1 =
            twapExecutor.getMakingAmount(order, "", keccak256("hash1"), address(0), 50e18, 1000e18, extraData);

        uint256 amount2 =
            twapExecutor.getMakingAmount(order, "", keccak256("hash2"), address(0), 50e18, 1000e18, extraData);

        // Amounts should be different due to randomization
        assertTrue(amount1 != amount2, "Randomization should produce different amounts");
        assertTrue(amount1 > 0 && amount2 > 0, "Both amounts should be positive");
    }

    // Helper functions
    function _createTestOrder(
        uint256 makingAmount,
        uint256 takingAmount
    )
        internal
        pure
        returns (IOrderMixin.Order memory)
    {
        return IOrderMixin.Order({
            salt: 1,
            maker: address(0x1),
            receiver: address(0x1),
            makerAsset: address(0x2),
            takerAsset: address(0x3),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: 0
        });
    }

    function _createVolatilityData() internal view returns (EnhancedVolatilityCalculator.VolatilityData memory) {
        return EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 300,
            maxExecutionSize: 100e18,
            minExecutionSize: 10e18,
            volatilityThreshold: 400,
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 1000
        });
    }

    function _createCombinedData() internal view returns (EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory) {
        EnhancedTWAPVolatilityExecutor.TWAPData memory twapData = EnhancedTWAPVolatilityExecutor.TWAPData({
            startTime: block.timestamp,
            duration: 3600,
            intervals: 12,
            baseInterval: 300,
            lastExecutionTime: 0,
            executedAmount: 0,
            randomizeExecution: false,
            adaptiveIntervals: true
        });

        return
            EnhancedTWAPVolatilityExecutor.CombinedStrategyData({ twap: twapData, volatility: _createVolatilityData() });
    }
}
