// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IOrderMixin.sol";

/**
 * @title EnhancedVolatilityCalculator
 * @notice Advanced volatility-based execution engine with modular utilities
 * @dev Provides volatility adjustments, interval optimization, and risk management
 * @author 1inch Advanced Strategy Engine
 */
contract EnhancedVolatilityCalculator {
    // ============ STRUCTS ============

    struct VolatilityData {
        uint256 baselineVolatility; // Expected normal volatility (basis points)
        uint256 currentVolatility; // Current market volatility (basis points)
        uint256 maxExecutionSize; // Maximum single execution size
        uint256 minExecutionSize; // Minimum single execution size
        uint256 volatilityThreshold; // High volatility threshold (basis points)
        uint256 lastUpdateTime; // Last volatility update timestamp
        bool conservativeMode; // Conservative execution mode
        uint256 emergencyThreshold; // Emergency stop threshold
    }

    struct VolatilityMetrics {
        uint256 adjustmentFactor; // 0-200 (100 = no change)
        uint256 intervalMultiplier; // 50-300 (100 = no change)
        uint256 riskScore; // 0-1000 (0 = safe, 1000 = extreme risk)
        bool shouldPause; // Emergency pause flag
    }

    // ============ CONSTANTS ============

    uint256 private constant MAX_VOLATILITY_MULTIPLIER = 500; // 5x baseline = extreme
    uint256 private constant STALE_DATA_THRESHOLD = 3600; // 1 hour
    uint256 private constant BASIS_POINTS = 10_000; // 100%

    // ============ ERRORS ============

    error VolatilityTooHigh();
    error InvalidVolatilityData();
    error StaleVolatilityData();
    error EmergencyModeTriggered();

    // ============ EVENTS ============

    event VolatilityAdjustmentApplied(
        uint256 originalAmount, uint256 adjustedAmount, uint256 currentVolatility, uint256 adjustmentFactor
    );

    event EmergencyPauseTriggered(uint256 volatility, uint256 threshold);

    // ============ MAIN INTERFACE ============

    /**
     * @notice Calculate making amount with volatility adjustments
     * @dev Implements IAmountCalculator interface for 1inch integration
     */
    function getMakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata,
        bytes32,
        address,
        uint256 takingAmount,
        uint256,
        bytes calldata extraData
    )
        external
        view
        returns (uint256)
    {
        VolatilityData memory volData = abi.decode(extraData, (VolatilityData));

        validateVolatilityData(volData);

        uint256 baseAmount = (takingAmount * order.makingAmount) / order.takingAmount;
        return applyVolatilityAdjustment(baseAmount, volData);
    }

    /**
     * @notice Calculate taking amount with volatility adjustments
     */
    function getTakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata,
        bytes32,
        address,
        uint256 makingAmount,
        uint256,
        bytes calldata extraData
    )
        external
        view
        returns (uint256)
    {
        VolatilityData memory volData = abi.decode(extraData, (VolatilityData));

        validateVolatilityData(volData);

        uint256 baseAmount = (makingAmount * order.takingAmount) / order.makingAmount;
        return applyVolatilityAdjustment(baseAmount, volData);
    }

    // ============ CORE VOLATILITY LOGIC ============

    /**
     * @notice Validate volatility data integrity and freshness
     * @param volData The volatility data to validate
     */
    function validateVolatilityData(VolatilityData memory volData) public view {
        if (volData.maxExecutionSize < volData.minExecutionSize) {
            revert InvalidVolatilityData();
        }

        if (volData.currentVolatility > volData.emergencyThreshold) {
            revert EmergencyModeTriggered();
        }

        if (volData.currentVolatility > volData.baselineVolatility * MAX_VOLATILITY_MULTIPLIER / 100) {
            revert VolatilityTooHigh();
        }

        if (block.timestamp > volData.lastUpdateTime + STALE_DATA_THRESHOLD) {
            revert StaleVolatilityData();
        }
    }

    /**
     * @notice Apply sophisticated volatility-based amount adjustment
     * @param amount Base execution amount
     * @param volData Volatility parameters
     * @return Adjusted amount based on current market conditions
     */
    function applyVolatilityAdjustment(uint256 amount, VolatilityData memory volData) public pure returns (uint256) {
        VolatilityMetrics memory metrics = calculateVolatilityMetrics(volData);

        if (metrics.shouldPause) {
            return 0; // Emergency pause
        }

        uint256 adjustedAmount = (amount * metrics.adjustmentFactor) / 100;

        // Apply bounds
        adjustedAmount = _min(adjustedAmount, volData.maxExecutionSize);
        adjustedAmount = _max(adjustedAmount, volData.minExecutionSize);

        return adjustedAmount;
    }

    /**
     * @notice Calculate comprehensive volatility metrics
     * @param volData Volatility data
     * @return metrics Complete volatility analysis
     */
    function calculateVolatilityMetrics(VolatilityData memory volData)
        public
        pure
        returns (VolatilityMetrics memory metrics)
    {
        metrics.riskScore = calculateRiskScore(volData);
        metrics.shouldPause = (volData.currentVolatility > volData.emergencyThreshold);

        if (metrics.shouldPause) {
            metrics.adjustmentFactor = 0;
            metrics.intervalMultiplier = 100;
            return metrics;
        }

        // Calculate adjustment factor (50-150)
        if (volData.currentVolatility <= volData.baselineVolatility) {
            // Low volatility: increase size (up to +50%)
            uint256 boost = (volData.baselineVolatility - volData.currentVolatility) * 50 / volData.baselineVolatility;
            metrics.adjustmentFactor = 100 + _min(boost, 50);
        } else if (volData.currentVolatility > volData.volatilityThreshold) {
            // High volatility: decrease size (up to -50%)
            uint256 reduction =
                (volData.currentVolatility - volData.baselineVolatility) * 50 / volData.baselineVolatility;
            reduction = _min(reduction, 50);
            metrics.adjustmentFactor = 100 - reduction;
        } else {
            // Normal volatility
            metrics.adjustmentFactor = volData.conservativeMode ? 90 : 100;
        }

        // Calculate interval multiplier (50-300)
        metrics.intervalMultiplier = calculateIntervalMultiplier(volData);
    }

    /**
     * @notice Calculate risk score (0-1000)
     * @param volData Volatility data
     * @return riskScore Numerical risk assessment
     */
    function calculateRiskScore(VolatilityData memory volData) public pure returns (uint256 riskScore) {
        if (volData.currentVolatility <= volData.baselineVolatility) {
            return 100; // Low risk
        }

        uint256 volatilityRatio = (volData.currentVolatility * 1000) / volData.baselineVolatility;

        if (volatilityRatio <= 2000) {
            return 100 + (volatilityRatio - 1000) / 2; // 100-600
        } else if (volatilityRatio <= 4000) {
            return 600 + (volatilityRatio - 2000) / 5; // 600-1000
        } else {
            return 1000; // Maximum risk
        }
    }

    /**
     * @notice Calculate optimal interval multiplier for TWAP
     * @param volData Volatility data
     * @return multiplier Interval adjustment (50-300)
     */
    function calculateIntervalMultiplier(VolatilityData memory volData) public pure returns (uint256 multiplier) {
        if (volData.currentVolatility > volData.volatilityThreshold) {
            // High volatility: shorter intervals (faster execution)
            uint256 speedup = (volData.currentVolatility - volData.baselineVolatility) * 50 / volData.baselineVolatility;
            speedup = _min(speedup, 50); // Max 50% speedup
            return 100 - speedup; // Return 50-100
        } else if (volData.currentVolatility < volData.baselineVolatility / 2) {
            // Very low volatility: longer intervals (patient execution)
            return 200; // 2x longer intervals
        }

        return 100; // Normal intervals
    }

    /**
     * @notice Get recommended TWAP interval adjustment
     * @param baseInterval Original interval in seconds
     * @param volData Volatility data
     * @return adjustedInterval Optimized interval
     */
    function getAdjustedInterval(
        uint256 baseInterval,
        VolatilityData memory volData
    )
        external
        pure
        returns (uint256 adjustedInterval)
    {
        uint256 multiplier = calculateIntervalMultiplier(volData);
        return (baseInterval * multiplier) / 100;
    }

    /**
     * @notice Check if execution should be paused due to extreme conditions
     * @param volData Volatility data
     * @return shouldPause Whether to pause execution
     */
    function shouldPauseExecution(VolatilityData memory volData) external pure returns (bool shouldPause) {
        return volData.currentVolatility > volData.emergencyThreshold;
    }

    /**
     * @notice Get volatility adjustment factor for external use
     * @param volData Volatility data
     * @return adjustmentFactor Percentage adjustment (0-200)
     */
    function getVolatilityAdjustmentFactor(VolatilityData memory volData)
        external
        pure
        returns (uint256 adjustmentFactor)
    {
        VolatilityMetrics memory metrics = calculateVolatilityMetrics(volData);
        return metrics.adjustmentFactor;
    }

    // ============ UTILITY FUNCTIONS ============

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}
