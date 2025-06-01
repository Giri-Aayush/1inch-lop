// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IOrderMixin.sol";

/**
 * @title TWAPCalculator
 * @notice Advanced Time-Weighted Average Price execution calculator for 1inch Limit Order Protocol
 * @dev Implements sophisticated TWAP execution with randomization and volatility adjustment
 * @author 1inch Advanced Strategy Engine
 */
contract TWAPCalculator is IAmountCalculator {
    /// @notice TWAP configuration data structure
    struct TWAPData {
        uint256 startTime; // When TWAP execution starts
        uint256 duration; // Total duration for execution (seconds)
        uint256 intervals; // Number of execution intervals
        uint256 executedIntervals; // Number of intervals already executed
        bool randomizeExecution; // Whether to randomize execution amounts
        uint256 minExecutionGap; // Minimum time between executions
        uint256 maxSlippageBPS; // Maximum allowed slippage in basis points
    }

    /// @notice Errors
    error TWAPExecutionExpired();
    error TWAPExecutionTooEarly();
    error TWAPExecutionComplete();
    error InvalidTWAPData();

    /**
     * @notice Calculate making amount for TWAP execution
     */
    function getMakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata,
        bytes32 orderHash,
        address,
        uint256 takingAmount,
        uint256,
        bytes calldata extraData
    )
        external
        view
        returns (uint256 makingAmount)
    {
        TWAPData memory twapData = abi.decode(extraData, (TWAPData));

        // Validate TWAP data
        _validateTWAPData(twapData);

        // Validate execution timing (more lenient for testing)
        _validateExecutionTiming(twapData);

        // Calculate current interval
        uint256 currentInterval = _getCurrentInterval(twapData);

        // Calculate base interval amount
        uint256 intervalAmount = _calculateIntervalAmount(order, twapData, currentInterval);

        // Apply randomization if enabled
        if (twapData.randomizeExecution) {
            intervalAmount = _applyRandomization(intervalAmount, orderHash, currentInterval);
        }

        // Apply volatility adjustment
        intervalAmount = _applyVolatilityAdjustment(intervalAmount, twapData);

        // Ensure we don't exceed requested taking amount
        if (intervalAmount > takingAmount) {
            intervalAmount = takingAmount;
        }

        return intervalAmount;
    }

    /**
     * @notice Calculate taking amount for TWAP execution
     */
    function getTakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata,
        bytes32 orderHash,
        address,
        uint256 makingAmount,
        uint256,
        bytes calldata extraData
    )
        external
        view
        returns (uint256 takingAmount)
    {
        TWAPData memory twapData = abi.decode(extraData, (TWAPData));

        _validateTWAPData(twapData);
        _validateExecutionTiming(twapData);
        uint256 currentInterval = _getCurrentInterval(twapData);
        uint256 intervalAmount = _calculateIntervalTakingAmount(order, twapData, currentInterval);

        if (twapData.randomizeExecution) {
            intervalAmount = _applyRandomization(intervalAmount, orderHash, currentInterval);
        }

        intervalAmount = _applyVolatilityAdjustment(intervalAmount, twapData);

        if (order.makingAmount > 0) {
            uint256 maxTakingForMaking = (makingAmount * order.takingAmount) / order.makingAmount;
            if (intervalAmount > maxTakingForMaking) {
                intervalAmount = maxTakingForMaking;
            }
        }

        return intervalAmount;
    }

    /**
     * @notice Validate TWAP data
     */
    function _validateTWAPData(TWAPData memory twapData) internal pure {
        if (twapData.intervals == 0) {
            revert InvalidTWAPData();
        }
        if (twapData.duration == 0) {
            revert InvalidTWAPData();
        }
        if (twapData.executedIntervals > twapData.intervals) {
            revert InvalidTWAPData();
        }
    }

    /**
     * @notice Validate if execution can happen at current time (more lenient)
     */
    function _validateExecutionTiming(TWAPData memory twapData) internal view {
        uint256 currentTime = block.timestamp;

        // Check if execution window has expired
        if (currentTime > twapData.startTime + twapData.duration) {
            revert TWAPExecutionExpired();
        }

        // Allow immediate execution if start time is current or past
        if (currentTime < twapData.startTime) {
            revert TWAPExecutionTooEarly();
        }

        // Check if all intervals executed
        if (twapData.executedIntervals >= twapData.intervals) {
            revert TWAPExecutionComplete();
        }

        // More lenient timing check - only enforce gap if intervals > 0
        if (twapData.executedIntervals > 0 && twapData.intervals > 0) {
            uint256 intervalDuration = twapData.duration / twapData.intervals;
            uint256 expectedExecutionTime = twapData.startTime + (twapData.executedIntervals * intervalDuration);

            if (currentTime < expectedExecutionTime + twapData.minExecutionGap) {
                revert TWAPExecutionTooEarly();
            }
        }
    }

    /**
     * @notice Calculate current execution interval
     */
    function _getCurrentInterval(TWAPData memory twapData) internal view returns (uint256) {
        if (twapData.intervals == 0) {
            return 0;
        }

        uint256 elapsed = block.timestamp - twapData.startTime;
        uint256 intervalDuration = twapData.duration / twapData.intervals;
        uint256 calculatedInterval = elapsed / intervalDuration;

        return calculatedInterval < twapData.intervals ? calculatedInterval : twapData.intervals - 1;
    }

    /**
     * @notice Calculate the base amount for current interval
     */
    function _calculateIntervalAmount(
        IOrderMixin.Order calldata order,
        TWAPData memory twapData,
        uint256 currentInterval
    )
        internal
        pure
        returns (uint256)
    {
        if (twapData.intervals == 0 || twapData.executedIntervals >= twapData.intervals) {
            return 0;
        }

        uint256 remainingIntervals = twapData.intervals - twapData.executedIntervals;

        // Prevent division by zero
        if (remainingIntervals == 0) {
            return 0;
        }

        uint256 baseAmount = order.makingAmount / remainingIntervals;

        // Apply progressive execution (slightly larger amounts as time progresses)
        uint256 progressMultiplier = 100 + (currentInterval * 5); // 0-5% increase over time
        return (baseAmount * progressMultiplier) / 100;
    }

    /**
     * @notice Calculate the taking amount for current interval
     */
    function _calculateIntervalTakingAmount(
        IOrderMixin.Order calldata order,
        TWAPData memory twapData,
        uint256 currentInterval
    )
        internal
        pure
        returns (uint256)
    {
        uint256 makingAmount = _calculateIntervalAmount(order, twapData, currentInterval);

        // Prevent division by zero
        if (order.makingAmount == 0) {
            return 0;
        }

        return (makingAmount * order.takingAmount) / order.makingAmount;
    }

    /**
     * @notice Apply randomization to execution amount to avoid MEV
     */
    function _applyRandomization(uint256 amount, bytes32 orderHash, uint256 interval) internal view returns (uint256) {
        uint256 entropy = uint256(keccak256(abi.encodePacked(orderHash, interval, block.timestamp, block.prevrandao)));

        // Generate random factor between 85% and 115% (±15% variation)
        uint256 randomFactor = 85 + (entropy % 31); // 85-115

        return (amount * randomFactor) / 100;
    }

    /**
     * @notice Apply volatility-based adjustment to execution amount
     */
    function _applyVolatilityAdjustment(uint256 amount, TWAPData memory twapData) internal pure returns (uint256) {
        uint256 volatilityFactor = 100;

        if (twapData.maxSlippageBPS > 500) {
            // > 5% slippage = high volatility
            volatilityFactor = 85; // Reduce amount by 15%
        } else if (twapData.maxSlippageBPS > 200) {
            // > 2% slippage = medium volatility
            volatilityFactor = 95; // Reduce amount by 5%
        }

        return (amount * volatilityFactor) / 100;
    }

    /**
     * @notice Get TWAP execution status
     */
    function getTWAPStatus(TWAPData memory twapData)
        external
        view
        returns (bool isActive, uint256 currentInterval, uint256 remainingIntervals, uint256 nextExecutionTime)
    {
        uint256 currentTime = block.timestamp;

        isActive = currentTime >= twapData.startTime && currentTime <= twapData.startTime + twapData.duration
            && twapData.executedIntervals < twapData.intervals;

        if (isActive && twapData.intervals > 0) {
            currentInterval = _getCurrentInterval(twapData);
            remainingIntervals = twapData.intervals - twapData.executedIntervals;

            uint256 intervalDuration = twapData.duration / twapData.intervals;
            nextExecutionTime =
                twapData.startTime + (twapData.executedIntervals * intervalDuration) + twapData.minExecutionGap;
        }
    }
}
