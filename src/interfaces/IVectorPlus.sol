// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IOrderMixin.sol";
import "../calculators/EnhancedVolatilityCalculator.sol";
import "../calculators/EnhancedTWAPVolatilityExecutor.sol";
import "../calculators/OptionsCalculator.sol";

/**
 * @title IVectorPlusInterface
 * @notice Unified interface for interacting with Vector Plus trading strategies
 * @dev Provides easy access to all Vector Plus functionality
 */
interface IVectorPlusInterface {
    // ============ EVENTS ============

    event StrategyExecuted(
        address indexed user, string strategyType, uint256 amount, uint256 adjustedAmount, bytes32 orderHash
    );

    event OptionCreated(
        bytes32 indexed optionId, address indexed holder, uint256 strikePrice, uint256 expiration, bool isCall
    );

    // ============ STRUCTS ============

    struct ContractAddresses {
        address volatilityCalculator;
        address twapExecutor;
        address optionsCalculator;
    }

    struct StrategyResult {
        uint256 originalAmount;
        uint256 adjustedAmount;
        uint256 riskScore;
        string strategyType;
        bool canExecute;
    }

    // ============ VOLATILITY STRATEGY ============

    /**
     * @notice Calculate volatility-adjusted execution amount
     * @param baseAmount Original execution amount
     * @param volData Volatility configuration
     * @return adjustedAmount Volatility-adjusted amount
     */
    function calculateVolatilityAmount(
        uint256 baseAmount,
        EnhancedVolatilityCalculator.VolatilityData memory volData
    )
        external
        view
        returns (uint256 adjustedAmount);

    /**
     * @notice Get volatility risk score
     * @param volData Volatility configuration
     * @return riskScore Risk score (0-1000)
     */
    function getVolatilityRiskScore(EnhancedVolatilityCalculator.VolatilityData memory volData)
        external
        view
        returns (uint256 riskScore);

    /**
     * @notice Check if execution should be paused due to volatility
     * @param volData Volatility configuration
     * @return shouldPause Whether to pause execution
     */
    function shouldPauseForVolatility(EnhancedVolatilityCalculator.VolatilityData memory volData)
        external
        view
        returns (bool shouldPause);

    // ============ TWAP STRATEGY ============

    /**
     * @notice Calculate TWAP execution amount with volatility integration
     * @param order The limit order
     * @param orderHash Order hash
     * @param requestedAmount Requested execution amount
     * @param remainingAmount Remaining order amount
     * @param combinedData TWAP + volatility configuration
     * @return executionAmount Amount to execute now
     */
    function calculateTWAPAmount(
        IOrderMixin.Order memory order,
        bytes32 orderHash,
        uint256 requestedAmount,
        uint256 remainingAmount,
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory combinedData
    )
        external
        view
        returns (uint256 executionAmount);

    /**
     * @notice Get TWAP execution progress
     * @param order The limit order
     * @param remainingAmount Remaining amount
     * @param combinedData TWAP configuration
     * @return progressBPS Progress in basis points (0-10000)
     */
    function getTWAPProgress(
        IOrderMixin.Order memory order,
        uint256 remainingAmount,
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory combinedData
    )
        external
        view
        returns (uint256 progressBPS);

    /**
     * @notice Get next TWAP execution time
     * @param combinedData TWAP configuration
     * @return nextExecutionTime Timestamp of next execution
     */
    function getNextTWAPExecution(EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory combinedData)
        external
        view
        returns (uint256 nextExecutionTime);

    // ============ OPTIONS STRATEGY ============

    /**
     * @notice Create a call option on order execution rights
     * @param order The underlying limit order
     * @param orderHash Hash of the order
     * @param strikePrice Strike price for exercise
     * @param expiration Expiration timestamp
     * @param premium Premium to pay
     * @return optionId Unique option identifier
     */
    function createCallOption(
        IOrderMixin.Order memory order,
        bytes32 orderHash,
        uint256 strikePrice,
        uint256 expiration,
        uint256 premium
    )
        external
        payable
        returns (bytes32 optionId);

    /**
     * @notice Create a put option on order execution rights
     * @param order The underlying limit order
     * @param orderHash Hash of the order
     * @param strikePrice Strike price for exercise
     * @param expiration Expiration timestamp
     * @param premium Premium to pay
     * @return optionId Unique option identifier
     */
    function createPutOption(
        IOrderMixin.Order memory order,
        bytes32 orderHash,
        uint256 strikePrice,
        uint256 expiration,
        uint256 premium
    )
        external
        payable
        returns (bytes32 optionId);

    /**
     * @notice Exercise an option
     * @param optionId Option to exercise
     * @param order The underlying order
     * @param currentPrice Current market price
     * @return success Whether exercise was successful
     */
    function exerciseOption(
        bytes32 optionId,
        IOrderMixin.Order memory order,
        uint256 currentPrice
    )
        external
        returns (bool success);

    /**
     * @notice Calculate option premium
     * @param order The underlying order
     * @param params Pricing parameters
     * @param isCall Whether it's a call option
     * @return premium Calculated premium
     */
    function calculateOptionPremium(
        IOrderMixin.Order memory order,
        OptionsCalculator.PricingParams memory params,
        bool isCall
    )
        external
        pure
        returns (uint256 premium);

    /**
     * @notice Get option details with current status
     * @param optionId Option identifier
     * @param currentPrice Current market price
     * @return option Option data
     * @return status Current option status
     */
    function getOptionStatus(
        bytes32 optionId,
        uint256 currentPrice
    )
        external
        view
        returns (OptionsCalculator.OptionData memory option, OptionsCalculator.OptionStatus memory status);

    // ============ UTILITY FUNCTIONS ============

    /**
     * @notice Get all contract addresses
     * @return addresses Struct containing all contract addresses
     */
    function getContractAddresses() external view returns (ContractAddresses memory addresses);

    /**
     * @notice Analyze strategy effectiveness for given parameters
     * @param order The limit order
     * @param baseAmount Base execution amount
     * @param volData Volatility configuration
     * @return result Strategy analysis result
     */
    function analyzeStrategy(
        IOrderMixin.Order memory order,
        uint256 baseAmount,
        EnhancedVolatilityCalculator.VolatilityData memory volData
    )
        external
        view
        returns (StrategyResult memory result);

    /**
     * @notice Estimate gas costs for strategy execution
     * @param strategyType Type of strategy ("volatility", "twap", "options")
     * @return gasEstimate Estimated gas cost
     */
    function estimateGasCost(string memory strategyType) external pure returns (uint256 gasEstimate);
}
