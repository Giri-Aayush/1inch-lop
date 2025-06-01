// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/calculators/SimpleTWAPCalculator.sol";
import "../../src/calculators/SimpleVolatilityCalculator.sol";

/**
 * @title OneinchIntegrationTest
 * @notice Integration test simulating exactly how 1inch calls our calculators
 */
contract OneinchIntegrationTest is Test {
    SimpleTWAPCalculator public twapCalculator;
    SimpleVolatilityCalculator public volatilityCalculator;

    // Test addresses
    address constant MAKER = address(0x1234);
    address constant TAKER = address(0x5678);
    address constant USDC = address(0xa0B86A33e6441C8E0B5E26E4C6B1e2bbf1f6E7b2);
    address constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() public {
        twapCalculator = new SimpleTWAPCalculator();
        volatilityCalculator = new SimpleVolatilityCalculator();
        vm.warp(1_685_000_000); // Set realistic timestamp
    }

    /**
     * @notice Test TWAP calculator as 1inch would call it
     */
    function testOneinchTWAPIntegration() public {
        console.log("=== Testing TWAP Calculator with 1inch Integration ===");

        // Create order
        IOrderMixin.Order memory order = _createTestOrder(1_000_000e6, 400e18);

        // Create TWAP data
        SimpleTWAPCalculator.TWAPData memory twapData = SimpleTWAPCalculator.TWAPData({
            startTime: block.timestamp,
            duration: 21_600, // 6 hours
            intervals: 36, // 10 min intervals
            randomizeExecution: true
        });

        // Test the integration
        bytes memory extraData = abi.encode(twapData);
        bytes32 orderHash = keccak256("test");

        uint256 allowedAmount = twapCalculator.getMakingAmount(
            order,
            "",
            orderHash,
            TAKER,
            15e18, // Requesting 15 ETH
            order.makingAmount,
            extraData
        );

        // Validate results
        uint256 expectedPerInterval = order.makingAmount / twapData.intervals;

        console.log("Expected per interval:", expectedPerInterval);
        console.log("Allowed amount:", allowedAmount);

        assertTrue(allowedAmount > 0, "Should allow execution");
        assertTrue(allowedAmount <= expectedPerInterval * 115 / 100, "Should not exceed 115% of interval");
        assertTrue(allowedAmount >= expectedPerInterval * 85 / 100, "Should be at least 85% of interval");

        console.log(" TWAP Integration Test Passed");
    }

    /**
     * @notice Test Volatility calculator as 1inch would call it
     */
    function testOneinchVolatilityIntegration() public {
        console.log("\n=== Testing Volatility Calculator with 1inch Integration ===");

        // Create order
        IOrderMixin.Order memory order = _createTestOrder(500_000e6, 200e18);

        // High volatility scenario
        SimpleVolatilityCalculator.VolatilityData memory volData = SimpleVolatilityCalculator.VolatilityData({
            baselineVolatility: 200, // 2%
            currentVolatility: 450, // 4.5% (high)
            maxExecutionSize: 50_000e6,
            minExecutionSize: 5000e6,
            lastUpdateTime: block.timestamp,
            conservativeMode: true
        });

        bytes memory extraData = abi.encode(volData);

        uint256 allowedAmount = volatilityCalculator.getMakingAmount(
            order,
            "",
            keccak256("test"),
            TAKER,
            20e18, // Want 20 ETH
            order.makingAmount,
            extraData
        );

        uint256 baseAmount = (20e18 * order.makingAmount) / order.takingAmount;

        console.log("Base amount:", baseAmount);
        console.log("Volatility-adjusted amount:", allowedAmount);

        assertTrue(allowedAmount < baseAmount, "High volatility should reduce size");
        assertTrue(allowedAmount >= volData.minExecutionSize, "Should respect min size");

        console.log(" Volatility Integration Test Passed");
    }

    /**
     * @notice Test sequential TWAP executions
     */
    function testSequentialTWAPExecutions() public {
        console.log("\n=== Testing Sequential TWAP Executions ===");

        IOrderMixin.Order memory order = _createTestOrder(100_000e6, 40e18);

        SimpleTWAPCalculator.TWAPData memory twapData = SimpleTWAPCalculator.TWAPData({
            startTime: block.timestamp,
            duration: 3600, // 1 hour
            intervals: 12, // 5 min intervals
            randomizeExecution: false
        });

        bytes memory extraData = abi.encode(twapData);
        uint256 expectedPerInterval = order.makingAmount / twapData.intervals;
        uint256 remainingAmount = order.makingAmount;

        console.log("Expected per interval:", expectedPerInterval);

        // Simulate 3 executions
        for (uint256 i = 0; i < 3; i++) {
            vm.warp(block.timestamp + 300); // Move 5 minutes forward

            uint256 allowedAmount = twapCalculator.getMakingAmount(
                order, "", keccak256(abi.encode("test", i)), TAKER, 0, remainingAmount, extraData
            );

            console.log("Execution", i + 1, "allowed:", allowedAmount);

            assertTrue(allowedAmount > 0, "Should allow execution");
            assertTrue(allowedAmount <= remainingAmount, "Should not exceed remaining");

            remainingAmount -= allowedAmount;
        }

        console.log(" Sequential TWAP Test Passed");
    }

    /**
     * @notice Test expired order handling
     */
    function testExpiredOrderHandling() public {
        console.log("\n=== Testing Expired Order Handling ===");

        IOrderMixin.Order memory order = _createTestOrder(50_000e6, 20e18);

        SimpleTWAPCalculator.TWAPData memory twapData = SimpleTWAPCalculator.TWAPData({
            startTime: block.timestamp,
            duration: 1800, // 30 minutes
            intervals: 6,
            randomizeExecution: false
        });

        bytes memory extraData = abi.encode(twapData);

        // Move past expiration
        vm.warp(block.timestamp + 3600); // 1 hour later

        console.log("Testing expired order revert...");

        vm.expectRevert(SimpleTWAPCalculator.TWAPExpired.selector);
        twapCalculator.getMakingAmount(order, "", keccak256("expired"), TAKER, 0, order.makingAmount, extraData);

        console.log(" Expired Order Test Passed");
    }

    // Helper function to create test orders
    function _createTestOrder(
        uint256 makingAmount,
        uint256 takingAmount
    )
        internal
        pure
        returns (IOrderMixin.Order memory)
    {
        return IOrderMixin.Order({
            salt: 1_234_567_890,
            maker: MAKER,
            receiver: MAKER,
            makerAsset: USDC,
            takerAsset: WETH,
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: 0
        });
    }
}
