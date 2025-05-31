
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/calculators/TWAPCalculator.sol";
import "../../src/interfaces/IOrderMixin.sol";

contract TWAPCalculatorTest is Test {
    TWAPCalculator public calculator;
    
    function setUp() public {
        calculator = new TWAPCalculator();
    }
    
    function testBasicTWAPCalculation() public view {
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1,
            maker: address(0x123),
            receiver: address(0x456),
            makerAsset: address(0x789),
            takerAsset: address(0xABC),
            makingAmount: 1000e18,
            takingAmount: 2000e18,
            makerTraits: 0
        });
        
        TWAPCalculator.TWAPData memory twapData = TWAPCalculator.TWAPData({
            startTime: block.timestamp,
            duration: 3600,
            intervals: 12,
            executedIntervals: 0,
            randomizeExecution: false,
            minExecutionGap: 60,
            maxSlippageBPS: 100
        });
        
        bytes memory extraData = abi.encode(twapData);
        
        uint256 makingAmount = calculator.getMakingAmount(
            order,
            "",
            bytes32(0),
            address(0),
            200e18,
            1000e18,
            extraData
        );
        
        assertTrue(makingAmount > 0, "Making amount should be positive");
        assertTrue(makingAmount <= 200e18, "Making amount should not exceed proportional amount");
    }
    
    function testTWAPWithRandomization() public view {
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1,
            maker: address(0x123),
            receiver: address(0x456),
            makerAsset: address(0x789),
            takerAsset: address(0xABC),
            makingAmount: 1000e18,
            takingAmount: 2000e18,
            makerTraits: 0
        });
        
        TWAPCalculator.TWAPData memory twapData = TWAPCalculator.TWAPData({
            startTime: block.timestamp,
            duration: 3600,
            intervals: 12,
            executedIntervals: 0,
            randomizeExecution: true,
            minExecutionGap: 60,
            maxSlippageBPS: 100
        });
        
        bytes memory extraData = abi.encode(twapData);
        
        uint256 makingAmount1 = calculator.getMakingAmount(
            order, "", bytes32(uint256(1)), address(0), 200e18, 1000e18, extraData
        );
        
        uint256 makingAmount2 = calculator.getMakingAmount(
            order, "", bytes32(uint256(2)), address(0), 200e18, 1000e18, extraData
        );
        
        assertTrue(makingAmount1 > 0, "First amount should be positive");
        assertTrue(makingAmount2 > 0, "Second amount should be positive");
    }
    
function testTWAPExecutionExpired() public {
    IOrderMixin.Order memory order = IOrderMixin.Order({
        salt: 1,
        maker: address(0x123),
        receiver: address(0x456),
        makerAsset: address(0x789),
        takerAsset: address(0xABC),
        makingAmount: 1000e18,
        takingAmount: 2000e18,
        makerTraits: 0
    });

    // Warp time beyond TWAP end
    vm.warp(10000); // Simulate block.timestamp = 10000

    TWAPCalculator.TWAPData memory twapData = TWAPCalculator.TWAPData({
        startTime: 5000,
        duration: 1000, // Ends at 6000
        intervals: 10,
        executedIntervals: 5,
        randomizeExecution: false,
        minExecutionGap: 60,
        maxSlippageBPS: 100
    });

    bytes memory extraData = abi.encode(twapData);

    // Expect the function to revert with TWAPExecutionExpired
    vm.expectRevert(TWAPCalculator.TWAPExecutionExpired.selector);
    calculator.getMakingAmount(
        order,
        "",
        bytes32(0),
        address(0),
        100e18,
        0,
        extraData
    );
}

    function testGetTWAPStatus() public view {
        TWAPCalculator.TWAPData memory twapData = TWAPCalculator.TWAPData({
            startTime: block.timestamp,
            duration: 3600,
            intervals: 12,
            executedIntervals: 2,
            randomizeExecution: false,
            minExecutionGap: 60,
            maxSlippageBPS: 100
        });
        
        (bool isActive, , uint256 remainingIntervals, uint256 nextExecutionTime) = 
            calculator.getTWAPStatus(twapData);
            
        assertTrue(isActive, "TWAP should be active");
        assertEq(remainingIntervals, 10, "Should have 10 remaining intervals");
        assertTrue(nextExecutionTime > block.timestamp, "Next execution should be in the future");
    }
    
    function testInvalidTWAPData() public {
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1,
            maker: address(0x123),
            receiver: address(0x456),
            makerAsset: address(0x789),
            takerAsset: address(0xABC),
            makingAmount: 1000e18,
            takingAmount: 2000e18,
            makerTraits: 0
        });
        
        TWAPCalculator.TWAPData memory twapData = TWAPCalculator.TWAPData({
            startTime: block.timestamp,
            duration: 3600,
            intervals: 0, // Invalid!
            executedIntervals: 0,
            randomizeExecution: false,
            minExecutionGap: 60,
            maxSlippageBPS: 100
        });
        
        bytes memory extraData = abi.encode(twapData);
        
        vm.expectRevert(TWAPCalculator.InvalidTWAPData.selector);
        calculator.getMakingAmount(
            order, "", bytes32(0), address(0), 200e18, 1000e18, extraData
        );
    }
    
}
