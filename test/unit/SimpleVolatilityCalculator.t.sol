// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/calculators/SimpleVolatilityCalculator.sol";

contract SimpleVolatilityCalculatorTest is Test {
    SimpleVolatilityCalculator public calculator;

    function setUp() public {
        calculator = new SimpleVolatilityCalculator();
        vm.warp(10_000); // Set reasonable timestamp
    }

    function testLowVolatilityIncrease() public view {
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1,
            maker: address(0x1),
            receiver: address(0x1),
            makerAsset: address(0x2),
            takerAsset: address(0x3),
            makingAmount: 1000e18,
            takingAmount: 2000e18,
            makerTraits: 0
        });

        SimpleVolatilityCalculator.VolatilityData memory volData = SimpleVolatilityCalculator.VolatilityData({
            baselineVolatility: 200, // 2%
            currentVolatility: 150, // 1.5% (low)
            maxExecutionSize: 500e18,
            minExecutionSize: 10e18,
            lastUpdateTime: block.timestamp,
            conservativeMode: false
        });

        bytes memory extraData = abi.encode(volData);

        uint256 amount =
            calculator.getMakingAmount(order, "", bytes32(0), address(0), 100e18, order.makingAmount, extraData);

        // Should increase amount for low volatility
        // Base: (100e18 * 1000e18) / 2000e18 = 50e18
        // With 20% increase: 60e18
        assertEq(amount, 60e18, "Should increase for low volatility");
    }

    function testHighVolatilityReduction() public view {
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1,
            maker: address(0x1),
            receiver: address(0x1),
            makerAsset: address(0x2),
            takerAsset: address(0x3),
            makingAmount: 1000e18,
            takingAmount: 2000e18,
            makerTraits: 0
        });

        SimpleVolatilityCalculator.VolatilityData memory volData = SimpleVolatilityCalculator.VolatilityData({
            baselineVolatility: 200, // 2%
            currentVolatility: 600, // 6% (high)
            maxExecutionSize: 500e18,
            minExecutionSize: 10e18,
            lastUpdateTime: block.timestamp,
            conservativeMode: false
        });

        bytes memory extraData = abi.encode(volData);

        uint256 amount =
            calculator.getMakingAmount(order, "", bytes32(0), address(0), 100e18, order.makingAmount, extraData);

        // Should reduce amount for high volatility
        // Base: 50e18, with 30% reduction: 35e18
        assertEq(amount, 35e18, "Should reduce for high volatility");
    }

    function testStaleData() public {
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1,
            maker: address(0x1),
            receiver: address(0x1),
            makerAsset: address(0x2),
            takerAsset: address(0x3),
            makingAmount: 1000e18,
            takingAmount: 2000e18,
            makerTraits: 0
        });

        SimpleVolatilityCalculator.VolatilityData memory volData = SimpleVolatilityCalculator.VolatilityData({
            baselineVolatility: 200,
            currentVolatility: 300,
            maxExecutionSize: 500e18,
            minExecutionSize: 10e18,
            lastUpdateTime: block.timestamp - 7200, // 2 hours ago (stale)
            conservativeMode: false
        });

        bytes memory extraData = abi.encode(volData);

        vm.expectRevert(SimpleVolatilityCalculator.StaleVolatilityData.selector);
        calculator.getMakingAmount(order, "", bytes32(0), address(0), 100e18, order.makingAmount, extraData);
    }
}
