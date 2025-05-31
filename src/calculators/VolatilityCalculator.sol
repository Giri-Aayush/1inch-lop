// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IOrderMixin.sol";

/**
 * @title VolatilityCalculator
 * @notice Dynamic order execution based on market volatility
 * @dev Adjusts execution size and timing based on volatility metrics
 * @author 1inch Advanced Strategy Engine
 */
contract VolatilityCalculator is IAmountCalculator {
    struct VolatilityData {
        uint256 baselineVolatility;     // Expected normal volatility (basis points)
        uint256 currentVolatility;      // Current market volatility
        uint256 maxExecutionSize;       // Maximum single execution size
        uint256 minExecutionSize;       // Minimum single execution size
        uint256 volatilityThreshold;    // Volatility threshold for adjustments
        uint256 lastUpdateTime;         // Last volatility update timestamp
        bool conservativeMode;          // Whether to use conservative sizing
    }

    /// @notice Errors
    error VolatilityTooHigh();
    error InvalidVolatilityData();

    /**
     * @notice Calculate making amount based on volatility
     */
    function getMakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata,
        bytes32,
        address,
        uint256 takingAmount,
        uint256,
        bytes calldata extraData
    ) external view returns (uint256) {
        VolatilityData memory volData = abi.decode(extraData, (VolatilityData));
        
        _validateVolatilityData(volData);
        
        uint256 baseAmount = (takingAmount * order.makingAmount) / order.takingAmount;
        uint256 adjustedAmount = _applyVolatilityAdjustment(baseAmount, volData);
        
        return adjustedAmount;
    }

    /**
     * @notice Calculate taking amount based on volatility
     */
    function getTakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata,
        bytes32,
        address,
        uint256 makingAmount,
        uint256,
        bytes calldata extraData
    ) external view returns (uint256) {
        VolatilityData memory volData = abi.decode(extraData, (VolatilityData));
        
        _validateVolatilityData(volData);
        
        uint256 baseAmount = (makingAmount * order.takingAmount) / order.makingAmount;
        uint256 adjustedAmount = _applyVolatilityAdjustment(baseAmount, volData);
        
        return adjustedAmount;
    }

    /**
     * @notice Validate volatility data
     */
    function _validateVolatilityData(VolatilityData memory volData) internal view {
        if (volData.maxExecutionSize < volData.minExecutionSize) {
            revert InvalidVolatilityData();
        }
        
        if (volData.currentVolatility > volData.volatilityThreshold * 3) {
            revert VolatilityTooHigh();
        }
        
        // Check if data is stale (older than 1 hour)
        if (block.timestamp > volData.lastUpdateTime + 3600) {
            revert InvalidVolatilityData();
        }
    }

    /**
     * @notice Apply volatility-based adjustments
     */
    function _applyVolatilityAdjustment(
        uint256 amount,
        VolatilityData memory volData
    ) internal pure returns (uint256) {
        if (volData.currentVolatility <= volData.baselineVolatility) {
            // Low volatility: can execute larger amounts
            uint256 increasedAmount = _min(amount * 120 / 100, volData.maxExecutionSize);
            return increasedAmount;
        } else if (volData.currentVolatility > volData.volatilityThreshold) {
            // High volatility: execute smaller amounts
            uint256 reduction = (volData.currentVolatility - volData.baselineVolatility) * 50 / volData.baselineVolatility;
            reduction = _min(reduction, 50); // Max 50% reduction
            
            uint256 adjustedAmount = amount * (100 - reduction) / 100;
            return _max(adjustedAmount, volData.minExecutionSize);
        }
        
        // Normal volatility: apply conservative mode if enabled
        if (volData.conservativeMode) {
            return amount * 90 / 100; // 10% reduction
        }
        
        return amount;
    }

    /**
     * @notice Get volatility adjustment factor
     */
    function getVolatilityAdjustmentFactor(VolatilityData memory volData)
        external
        pure
        returns (uint256 adjustmentFactor)
    {
        if (volData.currentVolatility <= volData.baselineVolatility) {
            return 120; // 20% increase
        } else if (volData.currentVolatility > volData.volatilityThreshold) {
            uint256 reduction = (volData.currentVolatility - volData.baselineVolatility) * 50 / volData.baselineVolatility;
            reduction = _min(reduction, 50);
            return 100 - reduction;
        }
        
        return volData.conservativeMode ? 90 : 100;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}
