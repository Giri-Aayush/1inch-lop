// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/calculators/SimpleTWAPCalculator.sol";

contract SimpleTWAPCalculatorTest is Test {
    SimpleTWAPCalculator public calculator;
    
    function setUp() public {
        calculator = new SimpleTWAPCalculator();
        // Set a reasonable timestamp
        vm.warp(10000);
    }
    
    function testBasicTWAP() public view {
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

        SimpleTWAPCalculator.TWAPData memory twapData = SimpleTWAPCalculator.TWAPData({
            startTime: block.timestamp,
            duration: 3600,
            intervals: 10,
            randomizeExecution: false
        });

        bytes memory extraData = abi.encode(twapData);
        
        uint256 amount = calculator.getMakingAmount(
            order, "", bytes32(0), address(0), 0, order.makingAmount, extraData
        );
        
        // Should return 1/10th of total (100e18)
        assertEq(amount, 100e18, "Should return interval amount");
    }
    
    function testTWAPExpired() public {
        // Warp to a later time to ensure no underflow
        vm.warp(20000);
        
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1, maker: address(0x1), receiver: address(0x1),
            makerAsset: address(0x2), takerAsset: address(0x3),
            makingAmount: 1000e18, takingAmount: 2000e18, makerTraits: 0
        });

        SimpleTWAPCalculator.TWAPData memory twapData = SimpleTWAPCalculator.TWAPData({
            startTime: 10000, // Fixed timestamp in the past
            duration: 3600,   // 1 hour duration (expired)
            intervals: 10,
            randomizeExecution: false
        });

        bytes memory extraData = abi.encode(twapData);
        
        vm.expectRevert(SimpleTWAPCalculator.TWAPExpired.selector);
        calculator.getMakingAmount(
            order, "", bytes32(0), address(0), 0, order.makingAmount, extraData
        );
    }
}
