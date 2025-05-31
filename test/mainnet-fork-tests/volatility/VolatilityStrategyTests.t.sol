// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/BaseMainnetTest.sol";

/**
 * @title VolatilityStrategyTests
 * @notice Comprehensive testing of volatility-aware trading strategies
 * @dev Tests all aspects of volatility calculation and adjustment
 */
contract VolatilityStrategyTests is BaseMainnetTest {
    
    // ============ VALIDATION TESTS ============
    
    function test_ValidateVolatilityData_ValidLowVolatility() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createLowVolatilityData();
        
        // Should not revert for valid low volatility data
        volatilityCalc.validateVolatilityData(volData);
    }
    
    function test_ValidateVolatilityData_ValidNormalVolatility() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createNormalVolatilityData();
        
        // Should not revert for valid normal volatility data
        volatilityCalc.validateVolatilityData(volData);
    }
    
    function test_ValidateVolatilityData_ValidHighVolatility() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        
        // Should not revert for valid high volatility data
        volatilityCalc.validateVolatilityData(volData);
    }
    
    function test_ValidateVolatilityData_ValidExtremeVolatility() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createExtremeVolatilityData();
        
        // Should not revert for extreme but valid volatility data
        volatilityCalc.validateVolatilityData(volData);
    }
    
    function testRevert_ValidateVolatilityData_EmergencyThreshold() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        volData.currentVolatility = 1300; // Above emergency threshold of 1200
        
        vm.expectRevert(EnhancedVolatilityCalculator.EmergencyModeTriggered.selector);
        volatilityCalc.validateVolatilityData(volData);
    }
    
    function testRevert_ValidateVolatilityData_VolatilityTooHigh() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        volData.currentVolatility = 1600; // 5.33x baseline (over 5x limit)
        volData.emergencyThreshold = 2000; // Set higher to avoid emergency error
        
        vm.expectRevert(EnhancedVolatilityCalculator.VolatilityTooHigh.selector);
        volatilityCalc.validateVolatilityData(volData);
    }
    
    function testRevert_ValidateVolatilityData_StaleData() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createNormalVolatilityData();
        volData.lastUpdateTime = block.timestamp - 7200; // 2 hours old (stale)
        
        vm.expectRevert(EnhancedVolatilityCalculator.StaleVolatilityData.selector);
        volatilityCalc.validateVolatilityData(volData);
    }
    
    function testRevert_ValidateVolatilityData_InvalidSizes() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createNormalVolatilityData();
        volData.maxExecutionSize = 0.05 ether; // Less than minExecutionSize
        
        vm.expectRevert(EnhancedVolatilityCalculator.InvalidVolatilityData.selector);
        volatilityCalc.validateVolatilityData(volData);
    }
    
    // ============ AMOUNT ADJUSTMENT TESTS ============
    
    function test_ApplyVolatilityAdjustment_LowVolatilityIncreasesAmount() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createLowVolatilityData();
        uint256 baseAmount = 1 ether;
        
        uint256 adjustedAmount = volatilityCalc.applyVolatilityAdjustment(baseAmount, volData);
        
        assertGt(adjustedAmount, baseAmount, "Low volatility should increase amount");
        _assertVolatilityBounds(adjustedAmount, volData);
    }
    
    function test_ApplyVolatilityAdjustment_NormalVolatilityMaintainsAmount() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createNormalVolatilityData();
        uint256 baseAmount = 1 ether;
        
        uint256 adjustedAmount = volatilityCalc.applyVolatilityAdjustment(baseAmount, volData);
        
        assertApproxEqRel(adjustedAmount, baseAmount, 0.1e18, "Normal volatility should maintain amount"); // Within 10%
        _assertVolatilityBounds(adjustedAmount, volData);
    }
    
    function test_ApplyVolatilityAdjustment_HighVolatilityReducesAmount() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        uint256 baseAmount = 2 ether;
        
        uint256 adjustedAmount = volatilityCalc.applyVolatilityAdjustment(baseAmount, volData);
        
        assertLt(adjustedAmount, baseAmount, "High volatility should reduce amount");
        _assertVolatilityBounds(adjustedAmount, volData);
    }
    
    function test_ApplyVolatilityAdjustment_ExtremeVolatilityMaxReduction() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createExtremeVolatilityData();
        uint256 baseAmount = 5 ether;
        
        uint256 adjustedAmount = volatilityCalc.applyVolatilityAdjustment(baseAmount, volData);
        
        assertLt(adjustedAmount, baseAmount / 2, "Extreme volatility should significantly reduce amount");
        _assertVolatilityBounds(adjustedAmount, volData);
    }
    
    function test_ApplyVolatilityAdjustment_ConservativeMode() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createNormalVolatilityData();
        volData.conservativeMode = true;
        uint256 baseAmount = 1 ether;
        
        uint256 adjustedAmount = volatilityCalc.applyVolatilityAdjustment(baseAmount, volData);
        
        assertLt(adjustedAmount, baseAmount, "Conservative mode should reduce amount");
        _assertVolatilityBounds(adjustedAmount, volData);
    }
    
    function test_ApplyVolatilityAdjustment_RespectsMinimumSize() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        uint256 baseAmount = 0.05 ether; // Very small amount
        
        uint256 adjustedAmount = volatilityCalc.applyVolatilityAdjustment(baseAmount, volData);
        
        assertGe(adjustedAmount, volData.minExecutionSize, "Should enforce minimum execution size");
    }
    
    function test_ApplyVolatilityAdjustment_RespectsMaximumSize() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createLowVolatilityData();
        uint256 baseAmount = 20 ether; // Very large amount
        
        uint256 adjustedAmount = volatilityCalc.applyVolatilityAdjustment(baseAmount, volData);
        
        assertLe(adjustedAmount, volData.maxExecutionSize, "Should enforce maximum execution size");
    }
    
    // ============ METRICS CALCULATION TESTS ============
    
    function test_CalculateVolatilityMetrics_LowVolatility() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createLowVolatilityData();
        
        EnhancedVolatilityCalculator.VolatilityMetrics memory metrics = 
            volatilityCalc.calculateVolatilityMetrics(volData);
        
        assertGt(metrics.adjustmentFactor, 100, "Low volatility should increase adjustment factor");
        assertLe(metrics.riskScore, 200, "Low volatility should have low risk score");
        assertFalse(metrics.shouldPause, "Low volatility should not trigger pause");
    }
    
    function test_CalculateVolatilityMetrics_HighVolatility() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        
        EnhancedVolatilityCalculator.VolatilityMetrics memory metrics = 
            volatilityCalc.calculateVolatilityMetrics(volData);
        
        assertLt(metrics.adjustmentFactor, 100, "High volatility should decrease adjustment factor");
        assertGt(metrics.riskScore, 500, "High volatility should have high risk score");
        assertFalse(metrics.shouldPause, "High but manageable volatility should not trigger pause");
    }
    
    function test_CalculateVolatilityMetrics_EmergencyLevel() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createExtremeVolatilityData();
        volData.currentVolatility = 1300; // Above emergency threshold
        
        EnhancedVolatilityCalculator.VolatilityMetrics memory metrics = 
            volatilityCalc.calculateVolatilityMetrics(volData);
        
        assertEq(metrics.adjustmentFactor, 0, "Emergency level should zero out adjustment factor");
        assertTrue(metrics.shouldPause, "Emergency level should trigger pause");
        assertEq(metrics.riskScore, 1000, "Emergency level should have maximum risk score");
    }
    
    // ============ RISK SCORE TESTS ============
    
    function test_CalculateRiskScore_ProgressiveScaling() public {
        uint256[] memory volatilities = new uint256[](5);
        volatilities[0] = 200;  // Below baseline
        volatilities[1] = 300;  // At baseline
        volatilities[2] = 600;  // 2x baseline
        volatilities[3] = 900;  // 3x baseline
        volatilities[4] = 1200; // 4x baseline
        
        uint256 previousScore = 0;
        
        for (uint i = 0; i < volatilities.length; i++) {
            EnhancedVolatilityCalculator.VolatilityData memory volData = _createNormalVolatilityData();
            volData.currentVolatility = volatilities[i];
            
            uint256 riskScore = volatilityCalc.calculateRiskScore(volData);
            
            if (i > 0) {
                assertGt(riskScore, previousScore, "Risk score should increase with volatility");
            }
            previousScore = riskScore;
        }
    }
    
    function test_CalculateRiskScore_BoundaryValues() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createNormalVolatilityData();
        
        // Test minimum risk (below baseline)
        volData.currentVolatility = 200;
        uint256 minRisk = volatilityCalc.calculateRiskScore(volData);
        assertEq(minRisk, 100, "Minimum risk should be 100");
        
        // Test maximum risk (extreme volatility)
        volData.currentVolatility = 2000; // Very high
        uint256 maxRisk = volatilityCalc.calculateRiskScore(volData);
        assertEq(maxRisk, 1000, "Maximum risk should be 1000");
    }
    
    // ============ INTERVAL MULTIPLIER TESTS ============
    
    function test_CalculateIntervalMultiplier_HighVolatilityFasterExecution() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        
        uint256 multiplier = volatilityCalc.calculateIntervalMultiplier(volData);
        
        assertLt(multiplier, 100, "High volatility should reduce intervals (faster execution)");
        assertGe(multiplier, 50, "Should not go below 50% of base interval");
    }
    
    function test_CalculateIntervalMultiplier_LowVolatilitySlowerExecution() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createLowVolatilityData();
        
        uint256 multiplier = volatilityCalc.calculateIntervalMultiplier(volData);
        
        assertGt(multiplier, 100, "Low volatility should increase intervals (slower execution)");
        assertLe(multiplier, 200, "Should not exceed 200% of base interval");
    }
    
    function test_CalculateIntervalMultiplier_NormalVolatilityBaseInterval() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createNormalVolatilityData();
        
        uint256 multiplier = volatilityCalc.calculateIntervalMultiplier(volData);
        
        assertEq(multiplier, 100, "Normal volatility should maintain base intervals");
    }
    
    // ============ INTEGRATION TESTS ============
    
    function test_GetAdjustedInterval_ScalesCorrectly() public {
        uint256 baseInterval = 600; // 10 minutes
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        
        uint256 adjustedInterval = volatilityCalc.getAdjustedInterval(baseInterval, volData);
        
        assertLt(adjustedInterval, baseInterval, "High volatility should reduce interval");
        assertGt(adjustedInterval, baseInterval / 2, "Should not reduce below 50%");
    }
    
    function test_ShouldPauseExecution_WorksCorrectly() public {
        // Normal volatility - should not pause
        EnhancedVolatilityCalculator.VolatilityData memory normalVol = _createNormalVolatilityData();
        assertFalse(volatilityCalc.shouldPauseExecution(normalVol), "Normal volatility should not pause");
        
        // Emergency level - should pause
        EnhancedVolatilityCalculator.VolatilityData memory emergencyVol = _createExtremeVolatilityData();
        emergencyVol.currentVolatility = 1300; // Above emergency threshold
        assertTrue(volatilityCalc.shouldPauseExecution(emergencyVol), "Emergency volatility should pause");
    }
    
    function test_GetVolatilityAdjustmentFactor_ReturnsCorrectValues() public {
        // Test low volatility
        EnhancedVolatilityCalculator.VolatilityData memory lowVol = _createLowVolatilityData();
        uint256 lowFactor = volatilityCalc.getVolatilityAdjustmentFactor(lowVol);
        assertGt(lowFactor, 100, "Low volatility should have factor > 100");
        
        // Test high volatility
        EnhancedVolatilityCalculator.VolatilityData memory highVol = _createHighVolatilityData();
        uint256 highFactor = volatilityCalc.getVolatilityAdjustmentFactor(highVol);
        assertLt(highFactor, 100, "High volatility should have factor < 100");
    }
    
    // ============ 1INCH INTERFACE TESTS ============
    
    function test_GetMakingAmount_WorksWithVolatilityData() public {
        IOrderMixin.Order memory order = _createETHSellOrder(1 ether, TEST_ETH_PRICE);
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createNormalVolatilityData();
        bytes memory extraData = abi.encode(volData);
        
        uint256 makingAmount = volatilityCalc.getMakingAmount(
            order, "", keccak256("test"), bob, 0.5 ether, 1 ether, extraData
        );
        
        assertGt(makingAmount, 0, "Should return valid making amount");
        _assertVolatilityBounds(makingAmount, volData);
    }
    
    function test_GetTakingAmount_WorksWithVolatilityData() public {
        IOrderMixin.Order memory order = _createETHSellOrder(1 ether, TEST_ETH_PRICE);
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createNormalVolatilityData();
        bytes memory extraData = abi.encode(volData);
        
        uint256 takingAmount = volatilityCalc.getTakingAmount(
            order, "", keccak256("test"), bob, 0.5 ether, 1 ether, extraData
        );
        
        assertGt(takingAmount, 0, "Should return valid taking amount");
    }
    
    // ============ GAS EFFICIENCY TESTS ============
    
    function test_VolatilityCalculation_GasEfficiency() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createNormalVolatilityData();
        uint256 baseAmount = 1 ether;
        
        uint256 gasBefore = gasleft();
        volatilityCalc.applyVolatilityAdjustment(baseAmount, volData);
        uint256 gasUsed = gasBefore - gasleft();
        
        _assertGasEfficiency(gasUsed, 50000, "Volatility adjustment");
    }
    
    function test_MetricsCalculation_GasEfficiency() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        
        uint256 gasBefore = gasleft();
        volatilityCalc.calculateVolatilityMetrics(volData);
        uint256 gasUsed = gasBefore - gasleft();
        
        _assertGasEfficiency(gasUsed, 30000, "Volatility metrics calculation");
    }
    
    // ============ EDGE CASE TESTS ============
    
    function test_ZeroBaseAmount_HandledCorrectly() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createNormalVolatilityData();
        
        uint256 adjustedAmount = volatilityCalc.applyVolatilityAdjustment(0, volData);
        
        assertEq(adjustedAmount, volData.minExecutionSize, "Zero amount should return minimum size");
    }
    
    function test_VeryLargeAmount_HandledCorrectly() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createNormalVolatilityData();
        uint256 veryLargeAmount = 1000 ether;
        
        uint256 adjustedAmount = volatilityCalc.applyVolatilityAdjustment(veryLargeAmount, volData);
        
        assertEq(adjustedAmount, volData.maxExecutionSize, "Very large amount should return maximum size");
    }
    
    function test_BorderlineVolatility_HandledCorrectly() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createNormalVolatilityData();
        volData.currentVolatility = volData.volatilityThreshold; // Exactly at threshold
        
        uint256 baseAmount = 1 ether;
        uint256 adjustedAmount = volatilityCalc.applyVolatilityAdjustment(baseAmount, volData);
        
        assertLt(adjustedAmount, baseAmount, "Threshold volatility should trigger reduction");
    }
}