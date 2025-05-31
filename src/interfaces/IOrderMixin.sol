// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IOrderMixin
 * @notice Interface for 1inch Limit Order Protocol order structure
 */
interface IOrderMixin {
    struct Order {
        uint256 salt;           // Order salt and extension hash
        address maker;          // Order maker address
        address receiver;       // Order receiver address
        address makerAsset;     // Maker asset address
        address takerAsset;     // Taker asset address
        uint256 makingAmount;   // Making amount
        uint256 takingAmount;   // Taking amount
        uint256 makerTraits;    // Maker traits
    }
}

/**
 * @title IAmountCalculator
 * @notice Interface for amount calculation contracts
 */
interface IAmountCalculator {
    /**
     * @notice Calculate making amount based on taking amount
     */
    function getMakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external view returns (uint256 makingAmount);

    /**
     * @notice Calculate taking amount based on making amount
     */
    function getTakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external view returns (uint256 takingAmount);
}
