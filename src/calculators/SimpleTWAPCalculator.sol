// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAmountGetter.sol";

/**
 * @title SimpleTWAPCalculator
 * @notice Time-Weighted Average Price calculator for 1inch Limit Orders
 * @dev Simple implementation following 1inch patterns
 */
contract SimpleTWAPCalculator is IAmountGetter {
    struct TWAPData {
        uint256 startTime;
        uint256 duration;
        uint256 intervals;
        bool randomizeExecution;
    }

    error TWAPNotStarted();
    error TWAPExpired();
    error InvalidTWAPData();

    function getMakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata,
        bytes32 orderHash,
        address,
        uint256,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    )
        external
        view
        returns (uint256)
    {
        TWAPData memory twap = abi.decode(extraData, (TWAPData));

        // Validate timing
        if (block.timestamp < twap.startTime) revert TWAPNotStarted();
        if (block.timestamp >= twap.startTime + twap.duration) revert TWAPExpired();
        if (twap.intervals == 0) revert InvalidTWAPData();

        // Calculate base amount per interval
        uint256 baseAmount = order.makingAmount / twap.intervals;

        // Apply randomization if enabled
        if (twap.randomizeExecution) {
            uint256 seed = uint256(keccak256(abi.encode(orderHash, block.timestamp))) % 100;
            // ±10% randomization
            uint256 variance = (baseAmount * 10) / 100;
            if (seed > 50) {
                baseAmount += (variance * (seed - 50)) / 50;
            } else {
                // Prevent underflow
                uint256 reduction = (variance * (50 - seed)) / 50;
                if (reduction < baseAmount) {
                    baseAmount -= reduction;
                } else {
                    baseAmount = baseAmount / 2; // Fallback to half amount
                }
            }
        }

        // Don't exceed remaining amount
        return baseAmount > remainingMakingAmount ? remainingMakingAmount : baseAmount;
    }

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
        // Simple proportional calculation
        if (order.makingAmount == 0) return 0;
        return (makingAmount * order.takingAmount) / order.makingAmount;
    }
}
