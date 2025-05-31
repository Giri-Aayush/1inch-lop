// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAmountGetter.sol";

/**
 * @title SimpleVolatilityCalculator
 * @notice Volatility-adaptive calculator for 1inch Limit Orders
 * @dev Simple implementation following 1inch patterns
 */
contract SimpleVolatilityCalculator is IAmountGetter {
    
    struct VolatilityData {
        uint256 baselineVolatility;    // Normal volatility (BPS)
        uint256 currentVolatility;     // Current volatility (BPS)
        uint256 maxExecutionSize;      // Max execution size
        uint256 minExecutionSize;      // Min execution size
        uint256 lastUpdateTime;        // Last update timestamp
        bool conservativeMode;         // Conservative mode flag
    }

    error StaleVolatilityData();
    error VolatilityTooHigh();
    error InvalidVolatilityData();

    uint256 private constant STALE_THRESHOLD = 3600; // 1 hour

    function getMakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata,
        bytes32,
        address,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external view returns (uint256) {
        VolatilityData memory vol = abi.decode(extraData, (VolatilityData));
        
        // Validate data
        if (block.timestamp > vol.lastUpdateTime + STALE_THRESHOLD) revert StaleVolatilityData();
        if (vol.currentVolatility > vol.baselineVolatility * 5) revert VolatilityTooHigh();
        if (vol.maxExecutionSize < vol.minExecutionSize) revert InvalidVolatilityData();
        
        // Calculate base amount
        uint256 baseAmount = (takingAmount * order.makingAmount) / order.takingAmount;
        
        // Apply volatility adjustment
        uint256 adjustedAmount = _applyVolatilityAdjustment(baseAmount, vol);
        
        // Enforce bounds
        if (adjustedAmount > vol.maxExecutionSize) adjustedAmount = vol.maxExecutionSize;
        if (adjustedAmount < vol.minExecutionSize) adjustedAmount = vol.minExecutionSize;
        if (adjustedAmount > remainingMakingAmount) adjustedAmount = remainingMakingAmount;
        
        return adjustedAmount;
    }

    function getTakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata,
        bytes32,
        address,
        uint256 makingAmount,
        uint256,
        bytes calldata extraData
    ) external view returns (uint256) {
        VolatilityData memory vol = abi.decode(extraData, (VolatilityData));
        
        // Basic validation
        if (block.timestamp > vol.lastUpdateTime + STALE_THRESHOLD) revert StaleVolatilityData();
        
        // Calculate proportional taking amount
        uint256 baseTakingAmount = (makingAmount * order.takingAmount) / order.makingAmount;
        
        // Apply volatility premium for high volatility
        if (vol.currentVolatility > vol.baselineVolatility * 2) {
            // Require more taking tokens during high volatility
            uint256 premium = (baseTakingAmount * 5) / 100; // 5% premium
            baseTakingAmount += premium;
        }
        
        return baseTakingAmount;
    }

    function _applyVolatilityAdjustment(
        uint256 amount,
        VolatilityData memory vol
    ) internal pure returns (uint256) {
        if (vol.currentVolatility <= vol.baselineVolatility) {
            // Low volatility: increase execution size
            return (amount * 120) / 100; // 20% increase
        } else if (vol.currentVolatility > vol.baselineVolatility * 2) {
            // High volatility: reduce execution size
            uint256 reductionFactor = vol.conservativeMode ? 50 : 70; // 50% or 30% reduction
            return (amount * reductionFactor) / 100;
        } else {
            // Normal volatility
            return vol.conservativeMode ? (amount * 90) / 100 : amount; // 10% reduction if conservative
        }
    }
}
