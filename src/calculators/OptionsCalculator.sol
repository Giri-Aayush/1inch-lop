// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IOrderMixin.sol";

/**
 * @title OptionsCalculator
 * @notice Revolutionary options trading on 1inch limit order execution rights
 * @dev Implements call and put options for limit order execution
 * @author 1inch Advanced Strategy Engine
 */
contract OptionsCalculator {
    // ============ STRUCTS ============

    /**
     * @notice Core option data structure
     * @dev Represents an option on a limit order execution right
     */
    struct OptionData {
        uint256 strikePrice; // Price threshold for profitable exercise (in quote token)
        uint256 expiration; // Option expiration timestamp
        uint256 premiumPaid; // Premium paid by option buyer (in quote token)
        bool isCall; // true = call option, false = put option
        address optionHolder; // Address that owns the option
        address optionSeller; // Address that sold the option
        bool isExercised; // Whether option has been exercised
        uint256 impliedVolatility; // Market volatility assumption (basis points)
        uint256 creationTime; // When option was created
        bytes32 underlyingOrderHash; // Hash of the underlying limit order
    }

    /**
     * @notice Option pricing parameters
     */
    struct PricingParams {
        uint256 currentPrice; // Current market price of underlying asset
        uint256 timeToExpiration; // Time remaining until expiration (seconds)
        uint256 volatility; // Implied volatility (basis points)
        uint256 riskFreeRate; // Risk-free interest rate (basis points)
    }

    /**
     * @notice Option Greeks for risk analysis
     */
    struct OptionGreeks {
        int256 delta; // Price sensitivity (basis points)
        int256 gamma; // Delta sensitivity (basis points)
        int256 theta; // Time decay per day (basis points)
        int256 vega; // Volatility sensitivity (basis points)
        uint256 intrinsicValue; // Current intrinsic value
        uint256 timeValue; // Current time value
    }

    /**
     * @notice Option status information
     */
    struct OptionStatus {
        bool isExpired;
        bool isInExerciseWindow;
        bool isInTheMoney;
        uint256 timeToExpiration;
        uint256 intrinsicValue;
        bool canExercise;
    }

    // ============ CONSTANTS ============

    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant SECONDS_PER_YEAR = 365 * 24 * 3600;
    uint256 private constant MIN_TIME_TO_EXPIRATION = 300; // 5 minutes
    uint256 private constant MAX_TIME_TO_EXPIRATION = 30 * 24 * 3600; // 30 days
    uint256 private constant DEFAULT_VOLATILITY = 8000; // 80% annualized
    uint256 private constant EXERCISE_WINDOW = 1800; // 30 minutes before expiration

    // ============ STATE VARIABLES ============

    mapping(bytes32 => OptionData) public options;
    mapping(address => uint256) public collateralBalances;
    uint256 public totalOptions;
    uint256 public protocolFeeRate = 300; // 3% of premium
    address public feeCollector;

    // ============ EVENTS ============

    event OptionCreated(
        bytes32 indexed optionId,
        address indexed holder,
        address indexed seller,
        uint256 strikePrice,
        uint256 expiration,
        uint256 premium,
        bool isCall
    );

    event OptionExercised(
        bytes32 indexed optionId,
        address indexed exerciser,
        uint256 executionPrice,
        uint256 profit
    );

    event OptionExpired(bytes32 indexed optionId, uint256 timeValue);

    event PremiumPaid(
        bytes32 indexed optionId,
        address from,
        address to,
        uint256 amount
    );

    // ============ ERRORS ============

    error OptionNotFound();
    error OptionAlreadyExpired(bytes32 optionId, uint256 expiration);
    error OptionAlreadyExercised();
    error NotOptionHolder();
    error InsufficientCollateral();
    error InvalidStrikePrice();
    error InvalidExpiration();
    error ExerciseNotProfitable();
    error OutsideExerciseWindow();
    error InvalidOptionType();

    // ============ CONSTRUCTOR ============

    constructor(address _feeCollector) {
        feeCollector = _feeCollector;
    }

    // ============ MAIN INTERFACE ============

    /**
     * @notice Calculate making amount for 1inch integration
     * @dev Main entry point for 1inch limit order protocol
     */
    function getMakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata,
        bytes32 orderHash,
        address taker,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external view returns (uint256) {
        OptionData memory option = abi.decode(extraData, (OptionData));

        // Validate option can be exercised
        if (!canExercise(option, taker)) {
            return 0;
        }

        // Calculate profitable execution amount
        return
            calculateExerciseAmount(
                order,
                option,
                takingAmount,
                remainingMakingAmount
            );
    }

    /**
     * @notice Calculate taking amount for 1inch integration
     */
    function getTakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external view returns (uint256) {
        OptionData memory option = abi.decode(extraData, (OptionData));

        if (!canExercise(option, taker)) {
            return 0;
        }

        // Convert making amount to taking amount
        uint256 takingAmount = (makingAmount * order.takingAmount) /
            order.makingAmount;
        return takingAmount;
    }

    // ============ OPTION LIFECYCLE ============

    /**
     * @notice Create a new call option on a limit order
     */
    function createCallOption(
        IOrderMixin.Order calldata order,
        bytes32 orderHash,
        uint256 strikePrice,
        uint256 expiration,
        uint256 premium
    ) external payable returns (bytes32 optionId) {
        _validateOptionParameters(strikePrice, expiration, premium);

        optionId = _generateOptionId(orderHash, msg.sender, block.timestamp);

        OptionData memory option = OptionData({
            strikePrice: strikePrice,
            expiration: expiration,
            premiumPaid: premium,
            isCall: true,
            optionHolder: msg.sender,
            optionSeller: order.maker,
            isExercised: false,
            impliedVolatility: DEFAULT_VOLATILITY,
            creationTime: block.timestamp,
            underlyingOrderHash: orderHash
        });

        options[optionId] = option;
        totalOptions++;

        _processPremiumPayment(optionId, option.optionSeller, premium);

        emit OptionCreated(
            optionId,
            option.optionHolder,
            option.optionSeller,
            strikePrice,
            expiration,
            premium,
            true
        );

        return optionId;
    }

    /**
     * @notice Create a new put option on a limit order
     */
    function createPutOption(
        IOrderMixin.Order calldata order,
        bytes32 orderHash,
        uint256 strikePrice,
        uint256 expiration,
        uint256 premium
    ) external payable returns (bytes32 optionId) {
        _validateOptionParameters(strikePrice, expiration, premium);

        optionId = _generateOptionId(orderHash, msg.sender, block.timestamp);

        OptionData memory option = OptionData({
            strikePrice: strikePrice,
            expiration: expiration,
            premiumPaid: premium,
            isCall: false,
            optionHolder: msg.sender,
            optionSeller: order.maker,
            isExercised: false,
            impliedVolatility: DEFAULT_VOLATILITY,
            creationTime: block.timestamp,
            underlyingOrderHash: orderHash
        });

        options[optionId] = option;
        totalOptions++;

        _processPremiumPayment(optionId, option.optionSeller, premium);

        emit OptionCreated(
            optionId,
            option.optionHolder,
            option.optionSeller,
            strikePrice,
            expiration,
            premium,
            false
        );

        return optionId;
    }

    /**
     * @notice Exercise a call option
     */
    function exerciseCallOption(
        bytes32 optionId,
        IOrderMixin.Order calldata order,
        uint256 currentPrice
    ) internal returns (bool success) {
        OptionData storage option = options[optionId];

        _validateExercise(optionId, option);

        if (currentPrice <= option.strikePrice) {
            revert ExerciseNotProfitable();
        }

        option.isExercised = true;

        uint256 profit = ((currentPrice - option.strikePrice) *
            order.makingAmount) / order.takingAmount;
        profit = profit > option.premiumPaid ? profit - option.premiumPaid : 0;

        emit OptionExercised(optionId, msg.sender, currentPrice, profit);

        return true;
    }

    /**
     * @notice Exercise a put option
     */
    function exercisePutOption(
        bytes32 optionId,
        IOrderMixin.Order calldata order,
        uint256 currentPrice
    ) internal returns (bool success) {
        OptionData storage option = options[optionId];

        _validateExercise(optionId, option);

        if (currentPrice >= option.strikePrice) {
            revert ExerciseNotProfitable();
        }

        option.isExercised = true;

        // For put options on buy orders: profit from forcing purchase at higher price
        uint256 ethAmount = order.takingAmount; // ETH amount in the buy order
        uint256 profit = ((option.strikePrice - currentPrice) * ethAmount) /
            1e18;
        profit = profit > option.premiumPaid ? profit - option.premiumPaid : 0;
        emit OptionExercised(optionId, msg.sender, currentPrice, profit);

        return true;
    }

    /**
     * @notice Universal exercise function
     */
    function exerciseOption(
        bytes32 optionId,
        IOrderMixin.Order calldata order,
        uint256 currentPrice
    ) external returns (bool success) {
        OptionData storage option = options[optionId];

        if (option.isCall) {
            return exerciseCallOption(optionId, order, currentPrice);
        } else {
            return exercisePutOption(optionId, order, currentPrice);
        }
    }

    // ============ OPTION PRICING ============

    function calculateOptionPremium(
        IOrderMixin.Order calldata order,
        PricingParams memory params,
        bool isCall
    ) public pure returns (uint256 premium) {
        if (params.timeToExpiration == 0) {
            return _calculateIntrinsicValue(params.currentPrice, order, isCall);
        }

        uint256 intrinsicValue = _calculateIntrinsicValue(
            params.currentPrice,
            order,
            isCall
        );
        uint256 timeValue = _calculateTimeValue(params, order);

        return intrinsicValue + timeValue;
    }

    function calculateGreeks(
        bytes32 optionId,
        uint256 currentPrice
    ) external view returns (OptionGreeks memory greeks) {
        OptionData memory option = options[optionId];

        if (option.optionHolder == address(0)) {
            revert OptionNotFound();
        }

        uint256 timeToExpiration = option.expiration > block.timestamp
            ? option.expiration - block.timestamp
            : 0;

        greeks.intrinsicValue = option.isCall
            ? (
                currentPrice > option.strikePrice
                    ? currentPrice - option.strikePrice
                    : 0
            )
            : (
                option.strikePrice > currentPrice
                    ? option.strikePrice - currentPrice
                    : 0
            );

        greeks.timeValue = option.premiumPaid > greeks.intrinsicValue
            ? option.premiumPaid - greeks.intrinsicValue
            : 0;

        if (timeToExpiration > 0) {
            greeks.delta = option.isCall ? int256(7000) : int256(-7000);
            greeks.gamma = int256(1000);
            greeks.theta = -int256(
                (greeks.timeValue * 86400) / timeToExpiration
            );
            greeks.vega = int256(option.impliedVolatility / 10);
        }
    }

    // ============ VALIDATION & HELPERS ============

    function canExercise(
        OptionData memory option,
        address exerciser
    ) public view returns (bool) {
        if (option.optionHolder != exerciser) return false;
        if (option.isExercised) return false;
        if (block.timestamp > option.expiration) return false;
        if (block.timestamp < option.expiration - EXERCISE_WINDOW) return false;

        return true;
    }

    function calculateExerciseAmount(
        IOrderMixin.Order calldata order,
        OptionData memory option,
        uint256 requestedTaking,
        uint256 remainingMaking
    ) public pure returns (uint256 executeAmount) {
        uint256 maxExecution = (requestedTaking * order.makingAmount) /
            order.takingAmount;
        return _min(maxExecution, remainingMaking);
    }

    function getOption(
        bytes32 optionId
    ) external view returns (OptionData memory option) {
        option = options[optionId];
        if (option.optionHolder == address(0)) {
            revert OptionNotFound();
        }
    }

    function isProfitableToExercise(
        bytes32 optionId,
        uint256 currentPrice
    ) external view returns (bool isProfitable) {
        OptionData memory option = options[optionId];

        if (option.isCall) {
            return currentPrice > option.strikePrice;
        } else {
            return currentPrice < option.strikePrice;
        }
    }

    function calculateExerciseProfit(
        bytes32 optionId,
        uint256 currentPrice,
        IOrderMixin.Order calldata order
    ) external view returns (uint256 profit, bool isProfitable) {
        OptionData memory option = options[optionId];

        if (option.optionHolder == address(0)) {
            return (0, false);
        }

        if (option.isCall) {
            if (currentPrice > option.strikePrice) {
                uint256 grossProfit = ((currentPrice - option.strikePrice) *
                    order.makingAmount) / order.takingAmount;
                profit = grossProfit > option.premiumPaid
                    ? grossProfit - option.premiumPaid
                    : 0;
                isProfitable = grossProfit > option.premiumPaid;
            }
        } else {
            if (currentPrice < option.strikePrice) {
                // For put options on buy orders:
                // The order maker wants to buy ETH, put holder can force them to buy at a higher price
                // Profit = (Strike - Current) * ETH amount
                uint256 ethAmount = order.takingAmount; // ETH amount in the buy order
                uint256 grossProfit = ((option.strikePrice - currentPrice) *
                    ethAmount) / 1e18;
                profit = grossProfit > option.premiumPaid
                    ? grossProfit - option.premiumPaid
                    : 0;
                isProfitable = grossProfit > option.premiumPaid;
            }
        }
    }

    function getOptionWithStatus(
        bytes32 optionId,
        uint256 currentPrice
    )
        external
        view
        returns (OptionData memory option, OptionStatus memory status)
    {
        option = options[optionId];
        if (option.optionHolder == address(0)) {
            revert OptionNotFound();
        }

        uint256 timeToExpiration = option.expiration > block.timestamp
            ? option.expiration - block.timestamp
            : 0;

        uint256 intrinsicValue;
        if (option.isCall) {
            intrinsicValue = currentPrice > option.strikePrice
                ? currentPrice - option.strikePrice
                : 0;
        } else {
            intrinsicValue = option.strikePrice > currentPrice
                ? option.strikePrice - currentPrice
                : 0;
        }

        status = OptionStatus({
            isExpired: block.timestamp > option.expiration,
            isInExerciseWindow: block.timestamp >=
                option.expiration - EXERCISE_WINDOW &&
                block.timestamp <= option.expiration,
            isInTheMoney: intrinsicValue > 0,
            timeToExpiration: timeToExpiration,
            intrinsicValue: intrinsicValue,
            canExercise: canExercise(option, option.optionHolder) &&
                intrinsicValue > 0
        });
    }

    // ============ INTERNAL FUNCTIONS ============

    function _validateOptionParameters(
        uint256 strikePrice,
        uint256 expiration,
        uint256 premium
    ) internal view {
        if (strikePrice == 0) revert InvalidStrikePrice();
        if (expiration <= block.timestamp + MIN_TIME_TO_EXPIRATION)
            revert InvalidExpiration();
        if (expiration > block.timestamp + MAX_TIME_TO_EXPIRATION)
            revert InvalidExpiration();
        if (premium == 0) revert InvalidStrikePrice();
    }

    function _validateExercise(
        bytes32 optionId,
        OptionData memory option
    ) internal view {
        if (option.optionHolder != msg.sender) revert NotOptionHolder();
        if (option.isExercised) revert OptionAlreadyExercised();
        if (block.timestamp > option.expiration)
            revert OptionAlreadyExpired(optionId, option.expiration);
        if (block.timestamp < option.expiration - EXERCISE_WINDOW)
            revert OutsideExerciseWindow();
    }

    function _generateOptionId(
        bytes32 orderHash,
        address holder,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(orderHash, holder, timestamp));
    }

    function _processPremiumPayment(
        bytes32 optionId,
        address seller,
        uint256 premium
    ) internal {
        uint256 protocolFee = (premium * protocolFeeRate) / BASIS_POINTS;
        uint256 sellerAmount = premium - protocolFee;

        emit PremiumPaid(optionId, msg.sender, seller, sellerAmount);
        emit PremiumPaid(optionId, msg.sender, feeCollector, protocolFee);
    }

    function _calculateIntrinsicValue(
        uint256 currentPrice,
        IOrderMixin.Order calldata order,
        bool isCall
    ) internal pure returns (uint256) {
        uint256 orderPrice = (order.takingAmount * 1e18) / order.makingAmount;

        if (isCall) {
            return currentPrice > orderPrice ? currentPrice - orderPrice : 0;
        } else {
            return orderPrice > currentPrice ? orderPrice - currentPrice : 0;
        }
    }

    function _calculateTimeValue(
        PricingParams memory params,
        IOrderMixin.Order calldata order
    ) internal pure returns (uint256) {
        uint256 timeRatio = (params.timeToExpiration * BASIS_POINTS) /
            SECONDS_PER_YEAR;
        uint256 volatilityComponent = (params.volatility * timeRatio) /
            BASIS_POINTS;

        return (order.takingAmount * volatilityComponent) / BASIS_POINTS / 100;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
