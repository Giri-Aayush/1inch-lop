// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./EnhancedVolatilityCalculator.sol";
import "../interfaces/IOrderMixin.sol";

/**
 * @title EnhancedTWAPVolatilityExecutor
 * @notice Advanced TWAP executor with integrated volatility awareness
 * @dev Combines time-weighted execution with dynamic volatility adjustments
 * @author 1inch Advanced Strategy Engine
 */
contract EnhancedTWAPVolatilityExecutor {
    // ============ DEPENDENCIES ============

    EnhancedVolatilityCalculator public immutable volatilityCalculator;

    // ============ STRUCTS ============

    struct TWAPData {
        uint256 startTime; // TWAP execution start time
        uint256 duration; // Total execution duration
        uint256 intervals; // Number of execution intervals
        uint256 baseInterval; // Base time between executions
        uint256 lastExecutionTime; // Last execution timestamp
        uint256 executedAmount; // Total amount already executed
        bool randomizeExecution; // Enable execution randomization
        bool adaptiveIntervals; // Enable volatility-adaptive intervals
    }

    struct CombinedStrategyData {
        TWAPData twap;
        EnhancedVolatilityCalculator.VolatilityData volatility;
    }

    struct ExecutionState {
        uint256 recommendedAmount; // Volatility-adjusted amount
        uint256 adjustedInterval; // Volatility-adjusted interval
        uint256 nextExecutionTime; // When next execution is allowed
        uint256 remainingAmount; // Amount left to execute
        uint256 progressPercentage; // Execution progress (0-10000 bp)
        bool canExecute; // Whether execution is currently allowed
        bool isPaused; // Emergency pause status
    }

    // ============ CONSTANTS ============

    uint256 private constant MAX_RANDOMIZATION = 20; // ±20% randomization
    uint256 private constant BASIS_POINTS = 10_000;

    // ============ ERRORS ============

    error TWAPNotStarted();
    error TWAPExpired();
    error TWAPFullyExecuted();
    error ExecutionTooEarly();
    error EmergencyPaused();
    error InvalidTWAPData();

    // ============ EVENTS ============

    event TWAPExecutionStep(
        bytes32 indexed orderHash, uint256 amount, uint256 totalExecuted, uint256 remainingAmount, uint256 volatility
    );

    event TWAPParametersAdjusted(
        uint256 originalInterval, uint256 adjustedInterval, uint256 volatilityFactor, bool emergencyPause
    );

    // ============ CONSTRUCTOR ============

    constructor(address _volatilityCalculator) {
        volatilityCalculator = EnhancedVolatilityCalculator(_volatilityCalculator);
    }

    // ============ MAIN INTERFACE ============

    /**
     * @notice Calculate making amount with TWAP + volatility logic
     * @dev Main entry point for 1inch integration
     */
    function getMakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata,
        bytes32 orderHash,
        address,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    )
        external
        view
        returns (uint256)
    {
        CombinedStrategyData memory data = abi.decode(extraData, (CombinedStrategyData));

        ExecutionState memory state =
            calculateExecutionState(order, orderHash, takingAmount, remainingMakingAmount, data);

        if (!state.canExecute || state.isPaused) {
            return 0;
        }

        return state.recommendedAmount;
    }

    /**
     * @notice Calculate taking amount with TWAP + volatility logic
     */
    function getTakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata,
        bytes32 orderHash,
        address,
        uint256 makingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    )
        external
        view
        returns (uint256)
    {
        CombinedStrategyData memory data = abi.decode(extraData, (CombinedStrategyData));

        // Convert making amount to taking amount
        uint256 equivalentTakingAmount = (makingAmount * order.takingAmount) / order.makingAmount;

        ExecutionState memory state =
            calculateExecutionState(order, orderHash, equivalentTakingAmount, remainingMakingAmount, data);

        if (!state.canExecute || state.isPaused) {
            return 0;
        }

        // Convert back to taking amount
        return (state.recommendedAmount * order.takingAmount) / order.makingAmount;
    }

    // ============ CORE EXECUTION LOGIC ============

    /**
     * @notice Calculate complete execution state for current market conditions
     * @param order The limit order being executed
     * @param orderHash Unique order identifier
     * @param requestedAmount Amount requested by taker
     * @param remainingAmount Amount left in order
     * @param data Combined TWAP and volatility data
     * @return state Complete execution state analysis
     */
    function calculateExecutionState(
        IOrderMixin.Order calldata order,
        bytes32 orderHash,
        uint256 requestedAmount,
        uint256 remainingAmount,
        CombinedStrategyData memory data
    )
        public
        view
        returns (ExecutionState memory state)
    {
        // Validate inputs
        _validateTWAPData(data.twap);
        volatilityCalculator.validateVolatilityData(data.volatility);

        // Check TWAP timing constraints
        if (block.timestamp < data.twap.startTime) {
            revert TWAPNotStarted();
        }

        if (block.timestamp > data.twap.startTime + data.twap.duration) {
            revert TWAPExpired();
        }

        if (remainingAmount == 0) {
            revert TWAPFullyExecuted();
        }

        // Calculate base execution parameters
        uint256 baseAmountPerInterval = order.makingAmount / data.twap.intervals;

        // Get volatility adjustments
        EnhancedVolatilityCalculator.VolatilityMetrics memory volMetrics =
            volatilityCalculator.calculateVolatilityMetrics(data.volatility);

        // Check for emergency pause
        state.isPaused = volMetrics.shouldPause;
        if (state.isPaused) {
            return state; // Early return with paused state
        }

        // Calculate adjusted interval
        if (data.twap.adaptiveIntervals) {
            state.adjustedInterval = (data.twap.baseInterval * volMetrics.intervalMultiplier) / 100;
        } else {
            state.adjustedInterval = data.twap.baseInterval;
        }

        // Check timing constraints
        state.nextExecutionTime = data.twap.lastExecutionTime + state.adjustedInterval;
        state.canExecute = block.timestamp >= state.nextExecutionTime;

        if (!state.canExecute) {
            return state; // Early return if timing not met
        }

        // Calculate recommended amount
        uint256 baseAmount = _min(baseAmountPerInterval, remainingAmount);

        // Apply volatility adjustment
        state.recommendedAmount = volatilityCalculator.applyVolatilityAdjustment(baseAmount, data.volatility);

        // Apply randomization if enabled
        if (data.twap.randomizeExecution) {
            state.recommendedAmount = _applyRandomization(state.recommendedAmount, orderHash);
        }

        // Ensure we don't exceed remaining amount
        state.recommendedAmount = _min(state.recommendedAmount, remainingAmount);

        // Calculate progress
        state.remainingAmount = remainingAmount;
        state.progressPercentage = ((order.makingAmount - remainingAmount) * BASIS_POINTS) / order.makingAmount;
    }

    // ============ UTILITY FUNCTIONS ============

    /**
     * @notice Apply deterministic randomization to execution amount
     * @param amount Base amount to randomize
     * @param orderHash Order hash for deterministic seed
     * @return randomizedAmount Amount with randomization applied
     */
    function _applyRandomization(uint256 amount, bytes32 orderHash) internal view returns (uint256 randomizedAmount) {
        // Create deterministic "randomness" using order hash and timestamp
        uint256 seed = uint256(keccak256(abi.encodePacked(orderHash, block.timestamp / 300))); // 5-min windows
        uint256 randomFactor = (seed % (MAX_RANDOMIZATION * 2 + 1)) + (100 - MAX_RANDOMIZATION);

        return (amount * randomFactor) / 100;
    }

    /**
     * @notice Validate TWAP data integrity
     * @param twapData TWAP parameters to validate
     */
    function _validateTWAPData(TWAPData memory twapData) internal pure {
        if (twapData.duration == 0 || twapData.intervals == 0) {
            revert InvalidTWAPData();
        }

        if (twapData.baseInterval == 0) {
            revert InvalidTWAPData();
        }

        if (twapData.startTime + twapData.duration < twapData.startTime) {
            revert InvalidTWAPData(); // Overflow check
        }
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @notice Get current execution progress for an order
     * @param order The limit order
     * @param remainingAmount Amount left to execute
     * @param extraData Combined strategy data
     * @return progress Execution progress (0-10000 basis points)
     */
    function getExecutionProgress(
        IOrderMixin.Order calldata order,
        uint256 remainingAmount,
        bytes calldata extraData
    )
        external
        view
        returns (uint256 progress)
    {
        CombinedStrategyData memory data = abi.decode(extraData, (CombinedStrategyData));
        return ((order.makingAmount - remainingAmount) * BASIS_POINTS) / order.makingAmount;
    }

    /**
     * @notice Get recommended next execution time
     * @param extraData Combined strategy data
     * @return nextTime Timestamp of next recommended execution
     */
    function getNextExecutionTime(bytes calldata extraData) external view returns (uint256 nextTime) {
        CombinedStrategyData memory data = abi.decode(extraData, (CombinedStrategyData));

        uint256 adjustedInterval = volatilityCalculator.getAdjustedInterval(data.twap.baseInterval, data.volatility);

        return data.twap.lastExecutionTime + adjustedInterval;
    }

    /**
     * @notice Check if order execution should be paused
     * @param extraData Combined strategy data
     * @return shouldPause Whether execution should be paused
     */
    function shouldPauseExecution(bytes calldata extraData) external view returns (bool shouldPause) {
        CombinedStrategyData memory data = abi.decode(extraData, (CombinedStrategyData));
        return volatilityCalculator.shouldPauseExecution(data.volatility);
    }

    /**
     * @notice Get comprehensive execution analysis
     * @param order The limit order
     * @param orderHash Order identifier
     * @param remainingAmount Amount left to execute
     * @param extraData Combined strategy data
     * @return state Complete execution state
     */
    function getExecutionAnalysis(
        IOrderMixin.Order calldata order,
        bytes32 orderHash,
        uint256 remainingAmount,
        bytes calldata extraData
    )
        external
        view
        returns (ExecutionState memory state)
    {
        CombinedStrategyData memory data = abi.decode(extraData, (CombinedStrategyData));

        return calculateExecutionState(
            order,
            orderHash,
            0, // No specific requested amount
            remainingAmount,
            data
        );
    }

    // ============ INTERNAL UTILITIES ============

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}
