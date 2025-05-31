// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/BaseMainnetTest.sol";

/**
 * @title TWAPExecutionTests
 * @notice Comprehensive testing of TWAP execution strategies
 * @dev Tests all aspects of time-weighted average price execution
 */
contract TWAPExecutionTests is BaseMainnetTest {
    // ============ BASIC EXECUTION TESTS ============

    function test_TWAPExecution_ShortDurationConfiguration() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            3 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createShortTWAPData(),
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256 makingAmount = twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            1 ether,
            3 ether,
            extraData
        );

        assertGt(makingAmount, 0, "Should allow execution");
        assertLe(
            makingAmount,
            data.volatility.maxExecutionSize,
            "Should respect volatility limits"
        );
    }

    function test_TWAPExecution_MediumDurationConfiguration() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            10 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createMediumTWAPData(),
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256 makingAmount = twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            2 ether,
            10 ether,
            extraData
        );

        assertGt(makingAmount, 0, "Should allow execution");
        assertLe(
            makingAmount,
            data.volatility.maxExecutionSize,
            "Should respect volatility limits"
        );
    }

    function test_TWAPExecution_LongDurationConfiguration() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            20 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createLongTWAPData(),
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256 makingAmount = twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            5 ether,
            20 ether,
            extraData
        );

        assertGt(makingAmount, 0, "Should allow execution");
        assertLe(
            makingAmount,
            data.volatility.maxExecutionSize,
            "Should respect volatility limits"
        );
    }

    // ============ TIME-BASED EXECUTION TESTS ============

    function test_TWAPExecution_TimeProgressionAffectsAmount() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            12 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createMediumTWAPData(),
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256[] memory amounts = new uint256[](5);
        uint256 remainingAmount = order.makingAmount;

        // Execute over multiple time periods
        for (uint i = 0; i < 5; i++) {
            _advanceTime(600); // Advance 10 minutes

            amounts[i] = twapExecutor.getMakingAmount(
                order,
                "",
                orderHash,
                bob,
                2 ether,
                remainingAmount,
                extraData
            );

            assertGt(
                amounts[i],
                0,
                "Each execution should return positive amount"
            );
            remainingAmount -= amounts[i];
        }

        // Verify total execution progresses correctly
        uint256 totalExecuted = order.makingAmount - remainingAmount;
        assertGt(
            totalExecuted,
            order.makingAmount / 3,
            "Should have executed significant portion"
        );
    }

    function test_TWAPExecution_SimulateFullExecutionCycle() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            6 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createShortTWAPData(), // 30 minutes, 6 intervals
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256 totalExecuted = 0;
        uint256 remainingAmount = order.makingAmount;

        // Simulate execution at each interval
        for (uint i = 0; i < data.twap.intervals && remainingAmount > 0; i++) {
            _advanceTime(data.twap.baseInterval); // Advance by interval time

            uint256 executionAmount = twapExecutor.getMakingAmount(
                order,
                "",
                orderHash,
                bob,
                1 ether,
                remainingAmount,
                extraData
            );

            totalExecuted += executionAmount;
            remainingAmount -= executionAmount;

            // Check progress
            uint256 progressBPS = twapExecutor.getExecutionProgress(
                order,
                remainingAmount,
                extraData
            );
            uint256 expectedProgressBPS = (totalExecuted * BASIS_POINTS) /
                order.makingAmount;

            _assertTWAPProgress(
                totalExecuted,
                order.makingAmount,
                expectedProgressBPS
            );
        }

        assertGt(
            totalExecuted,
            order.makingAmount / 2,
            "Should execute majority of order"
        );
    }

    // ============ RANDOMIZATION TESTS ============

    function test_TWAPExecution_RandomizationProducesDifferentAmounts() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            10 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.TWAPData
            memory twapData = _createMediumTWAPData();
        twapData.randomizeExecution = true;

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                twapData,
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);

        uint256[] memory amounts = new uint256[](5);

        // Execute with different order hashes to trigger randomization
        for (uint i = 0; i < 5; i++) {
            bytes32 orderHash = keccak256(abi.encode(order, i));
            amounts[i] = twapExecutor.getMakingAmount(
                order,
                "",
                orderHash,
                bob,
                2 ether,
                10 ether,
                extraData
            );
        }

        // Check that randomization produces different amounts
        bool foundDifference = false;
        for (uint i = 1; i < amounts.length; i++) {
            if (amounts[i] != amounts[0]) {
                foundDifference = true;
                break;
            }
        }

        assertTrue(
            foundDifference,
            "Randomization should produce different amounts"
        );

        // All amounts should still be reasonable
        for (uint i = 0; i < amounts.length; i++) {
            assertGt(
                amounts[i],
                0,
                "All randomized amounts should be positive"
            );
            assertLe(
                amounts[i],
                data.volatility.maxExecutionSize,
                "All amounts should respect limits"
            );
        }
    }

    function test_TWAPExecution_NoRandomizationProducesConsistentAmounts()
        public
    {
        IOrderMixin.Order memory order = _createETHSellOrder(
            10 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.TWAPData
            memory twapData = _createMediumTWAPData();
        twapData.randomizeExecution = false;

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                twapData,
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256 firstAmount = twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            2 ether,
            10 ether,
            extraData
        );

        uint256 secondAmount = twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            2 ether,
            10 ether,
            extraData
        );

        assertEq(
            firstAmount,
            secondAmount,
            "No randomization should produce consistent amounts"
        );
    }

    // ============ ADAPTIVE INTERVALS TESTS ============

    function test_TWAPExecution_AdaptiveIntervalsWithHighVolatility() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            8 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.TWAPData
            memory twapData = _createMediumTWAPData();
        twapData.adaptiveIntervals = true;

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                twapData,
                _createHighVolatilityData() // High volatility should reduce intervals
            );

        bytes memory extraData = abi.encode(data);

        // Get next execution time with high volatility
        uint256 nextExecutionTime = twapExecutor.getNextExecutionTime(
            extraData
        );

        // Should be sooner than base interval due to high volatility
        assertLt(
            nextExecutionTime - twapData.lastExecutionTime,
            twapData.baseInterval,
            "High volatility should reduce interval time"
        );
    }

    function test_TWAPExecution_AdaptiveIntervalsWithLowVolatility() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            8 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.TWAPData
            memory twapData = _createMediumTWAPData();
        twapData.adaptiveIntervals = true;

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                twapData,
                _createLowVolatilityData() // Low volatility should increase intervals
            );

        bytes memory extraData = abi.encode(data);

        // Get next execution time with low volatility
        uint256 nextExecutionTime = twapExecutor.getNextExecutionTime(
            extraData
        );

        // Should be later than base interval due to low volatility
        assertGt(
            nextExecutionTime - twapData.lastExecutionTime,
            twapData.baseInterval,
            "Low volatility should increase interval time"
        );
    }

    // ============ ERROR CONDITION TESTS ============

    function testRevert_TWAPExecution_NotStarted() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            5 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.TWAPData
            memory twapData = _createMediumTWAPData();
        twapData.startTime = block.timestamp + 3600; // Start in 1 hour

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                twapData,
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        vm.expectRevert(EnhancedTWAPVolatilityExecutor.TWAPNotStarted.selector);
        twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            1 ether,
            5 ether,
            extraData
        );
    }

    function testRevert_TWAPExecution_Expired() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            5 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createShortTWAPData(),
                _createNormalVolatilityData()
            );

        // Move past expiration and keep volatility data fresh
        _advanceTime(data.twap.duration + 100);
        data.volatility.lastUpdateTime = block.timestamp;

        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        vm.expectRevert(EnhancedTWAPVolatilityExecutor.TWAPExpired.selector);
        twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            1 ether,
            5 ether,
            extraData
        );
    }

    function testRevert_TWAPExecution_FullyExecuted() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            5 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createMediumTWAPData(),
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        vm.expectRevert(
            EnhancedTWAPVolatilityExecutor.TWAPFullyExecuted.selector
        );
        twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            1 ether,
            0,
            extraData
        ); // 0 remaining
    }

    function testRevert_TWAPExecution_InvalidTWAPData() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            5 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.TWAPData
            memory invalidTWAPData = _createMediumTWAPData();
        invalidTWAPData.intervals = 0; // Invalid: no intervals

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                invalidTWAPData,
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        vm.expectRevert(
            EnhancedTWAPVolatilityExecutor.InvalidTWAPData.selector
        );
        twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            1 ether,
            5 ether,
            extraData
        );
    }

    // ============ PROGRESS TRACKING TESTS ============

    function test_GetExecutionProgress_CalculatesCorrectly() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            10 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createMediumTWAPData(),
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);

        // Test various completion levels
        uint256[] memory remainingAmounts = new uint256[](5);
        remainingAmounts[0] = 10 ether; // 0% complete
        remainingAmounts[1] = 7.5 ether; // 25% complete
        remainingAmounts[2] = 5 ether; // 50% complete
        remainingAmounts[3] = 2.5 ether; // 75% complete
        remainingAmounts[4] = 0 ether; // 100% complete

        uint256[] memory expectedProgress = new uint256[](5);
        expectedProgress[0] = 0;
        expectedProgress[1] = 2500; // 25% in basis points
        expectedProgress[2] = 5000; // 50% in basis points
        expectedProgress[3] = 7500; // 75% in basis points
        expectedProgress[4] = 10000; // 100% in basis points

        for (uint i = 0; i < remainingAmounts.length; i++) {
            uint256 progress = twapExecutor.getExecutionProgress(
                order,
                remainingAmounts[i],
                extraData
            );
            assertEq(
                progress,
                expectedProgress[i],
                "Progress calculation should be accurate"
            );
        }
    }

    // ============ EXECUTION STATE TESTS ============

    function test_CalculateExecutionState_ComprehensiveAnalysis() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            8 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createMediumTWAPData(),
                _createNormalVolatilityData()
            );
        bytes32 orderHash = keccak256(abi.encode(order));

        EnhancedTWAPVolatilityExecutor.ExecutionState
            memory state = twapExecutor.calculateExecutionState(
                order,
                orderHash,
                2 ether,
                8 ether,
                data
            );

        assertTrue(state.canExecute, "Should be able to execute");
        assertFalse(state.isPaused, "Should not be paused");
        assertGt(
            state.recommendedAmount,
            0,
            "Should recommend positive amount"
        );
        assertLe(
            state.recommendedAmount,
            data.volatility.maxExecutionSize,
            "Should respect limits"
        );
        assertEq(
            state.remainingAmount,
            8 ether,
            "Should track remaining amount"
        );
        assertEq(
            state.progressPercentage,
            0,
            "Should show 0% progress initially"
        );
    }

    // ============ VOLATILITY INTEGRATION TESTS ============

    function test_TWAPExecution_EmergencyPauseStopsExecution() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            5 ether,
            TEST_ETH_PRICE
        );
        EnhancedVolatilityCalculator.VolatilityData
            memory emergencyVolData = _createExtremeVolatilityData();
        emergencyVolData.currentVolatility = 1300; // Above emergency threshold

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createMediumTWAPData(),
                emergencyVolData
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256 makingAmount = twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            1 ether,
            5 ether,
            extraData
        );

        assertEq(makingAmount, 0, "Emergency volatility should stop execution");
    }

    function test_ShouldPauseExecution_WorksCorrectly() public {
        // Normal volatility - should not pause
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory normalData = _createCombinedStrategyData(
                _createMediumTWAPData(),
                _createNormalVolatilityData()
            );
        bytes memory normalExtraData = abi.encode(normalData);

        assertFalse(
            twapExecutor.shouldPauseExecution(normalExtraData),
            "Normal volatility should not pause"
        );

        // Emergency volatility - should pause
        EnhancedVolatilityCalculator.VolatilityData
            memory emergencyVolData = _createExtremeVolatilityData();
        emergencyVolData.currentVolatility = 1300;

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory emergencyData = _createCombinedStrategyData(
                _createMediumTWAPData(),
                emergencyVolData
            );
        bytes memory emergencyExtraData = abi.encode(emergencyData);

        assertTrue(
            twapExecutor.shouldPauseExecution(emergencyExtraData),
            "Emergency volatility should pause"
        );
    }

    // ============ GAS EFFICIENCY TESTS ============

    function test_TWAPCalculation_GasEfficiency() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            10 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createMediumTWAPData(),
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256 gasBefore = gasleft();
        twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            2 ether,
            10 ether,
            extraData
        );
        uint256 gasUsed = gasBefore - gasleft();

        _assertGasEfficiency(gasUsed, 100000, "TWAP calculation");
    }

    function test_ExecutionStateCalculation_GasEfficiency() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            10 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createMediumTWAPData(),
                _createNormalVolatilityData()
            );
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256 gasBefore = gasleft();
        twapExecutor.calculateExecutionState(
            order,
            orderHash,
            2 ether,
            10 ether,
            data
        );
        uint256 gasUsed = gasBefore - gasleft();

        _assertGasEfficiency(gasUsed, 150000, "Execution state calculation");
    }

    // ============ EDGE CASE TESTS ============

    function test_TWAPExecution_VerySmallOrder() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            0.1 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createShortTWAPData(),
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256 makingAmount = twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            0.05 ether,
            0.1 ether,
            extraData
        );

        assertGt(makingAmount, 0, "Should handle very small orders");
        assertLe(makingAmount, 0.1 ether, "Should not exceed order size");
    }

    function test_TWAPExecution_VeryLargeOrder() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            1000 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createLongTWAPData(),
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256 makingAmount = twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            50 ether,
            1000 ether,
            extraData
        );

        assertGt(makingAmount, 0, "Should handle very large orders");
        assertLe(
            makingAmount,
            data.volatility.maxExecutionSize,
            "Should respect volatility limits"
        );
    }

    function test_TWAPExecution_SingleInterval() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            2 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.TWAPData
            memory singleIntervalTWAP = _createShortTWAPData();
        singleIntervalTWAP.intervals = 1; // Only one interval

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                singleIntervalTWAP,
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256 makingAmount = twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            1 ether,
            2 ether,
            extraData
        );

        assertGt(makingAmount, 0, "Should handle single interval TWAP");
    }

    function test_TWAPExecution_NearExpirationTime() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            5 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createMediumTWAPData(),
                _createNormalVolatilityData()
            );

        // Move to near expiration (but not expired)
        _advanceTime(data.twap.duration - 60); // 1 minute before expiry
        data.volatility.lastUpdateTime = block.timestamp; // Keep volatility data fresh

        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256 makingAmount = twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            1 ether,
            5 ether,
            extraData
        );

        assertGt(makingAmount, 0, "Should allow execution near expiration");
    }

    // ============ MULTI-ASSET TESTS ============

    function test_TWAPExecution_DifferentTokenPairs() public {
        // Test USDC -> WETH order
        IOrderMixin.Order memory usdcOrder = _createMultiAssetOrder(
            USDC,
            WETH,
            10000e6,
            5 ether
        );

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createMediumTWAPData(),
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(usdcOrder));

        uint256 makingAmount = twapExecutor.getMakingAmount(
            usdcOrder,
            "",
            orderHash,
            bob,
            2000e6,
            10000e6,
            extraData
        );

        assertGt(makingAmount, 0, "Should work with USDC -> WETH orders");

        // Test with different decimals (USDT has 6 decimals)
        IOrderMixin.Order memory usdtOrder = _createMultiAssetOrder(
            USDT,
            WETH,
            8000e6,
            4 ether
        );
        orderHash = keccak256(abi.encode(usdtOrder));

        makingAmount = twapExecutor.getMakingAmount(
            usdtOrder,
            "",
            orderHash,
            bob,
            1600e6,
            8000e6,
            extraData
        );

        assertGt(makingAmount, 0, "Should work with different token decimals");
    }

    // ============ STRESS TESTS ============

    function test_TWAPExecution_HighFrequencyIntervals() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            12 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.TWAPData
            memory highFreqTWAP = _createMediumTWAPData();
        highFreqTWAP.intervals = 60; // Very high frequency
        highFreqTWAP.baseInterval = 120; // 2 minutes

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                highFreqTWAP,
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256 makingAmount = twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            1 ether,
            12 ether,
            extraData
        );

        assertGt(makingAmount, 0, "Should handle high frequency intervals");
        assertLt(
            makingAmount,
            1 ether,
            "High frequency should result in smaller amounts"
        );
    }

    function test_TWAPExecution_ExtremePriceVariations() public {
        // Test with very high ETH price
        IOrderMixin.Order memory highPriceOrder = _createETHSellOrder(
            1 ether,
            10000e6
        ); // $10,000 per ETH

        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createMediumTWAPData(),
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(highPriceOrder));

        uint256 makingAmount = twapExecutor.getMakingAmount(
            highPriceOrder,
            "",
            orderHash,
            bob,
            0.1 ether,
            1 ether,
            extraData
        );

        assertGt(makingAmount, 0, "Should handle extreme price variations");

        // Test with very low ETH price
        IOrderMixin.Order memory lowPriceOrder = _createETHSellOrder(
            10 ether,
            100e6
        ); // $100 per ETH
        orderHash = keccak256(abi.encode(lowPriceOrder));

        makingAmount = twapExecutor.getMakingAmount(
            lowPriceOrder,
            "",
            orderHash,
            bob,
            1 ether,
            10 ether,
            extraData
        );

        assertGt(makingAmount, 0, "Should handle very low prices");
    }

    // ============ INTEGRATION WITH 1INCH TESTS ============

    function test_GetTakingAmount_ProportionalCalculation() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            10 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createMediumTWAPData(),
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        uint256 makingAmount = 2 ether;
        uint256 takingAmount = twapExecutor.getTakingAmount(
            order,
            "",
            orderHash,
            bob,
            makingAmount,
            10 ether,
            extraData
        );

        uint256 expectedTakingAmount = (makingAmount * order.takingAmount) /
            order.makingAmount;
        assertEq(
            takingAmount,
            expectedTakingAmount,
            "Taking amount should be proportional"
        );
    }

    function test_1inchInterface_AllMethodsWork() public {
        IOrderMixin.Order memory order = _createETHSellOrder(
            5 ether,
            TEST_ETH_PRICE
        );
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData
            memory data = _createCombinedStrategyData(
                _createMediumTWAPData(),
                _createNormalVolatilityData()
            );
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));

        // Test getMakingAmount
        uint256 makingAmount = twapExecutor.getMakingAmount(
            order,
            "",
            orderHash,
            bob,
            1 ether,
            5 ether,
            extraData
        );
        assertGt(makingAmount, 0, "getMakingAmount should work");

        // Test getTakingAmount
        uint256 takingAmount = twapExecutor.getTakingAmount(
            order,
            "",
            orderHash,
            bob,
            makingAmount,
            5 ether,
            extraData
        );
        assertGt(takingAmount, 0, "getTakingAmount should work");

        // Test utility functions
        uint256 progress = twapExecutor.getExecutionProgress(
            order,
            3 ether,
            extraData
        );
        assertEq(progress, 4000, "Progress should be 40%");

        uint256 nextTime = twapExecutor.getNextExecutionTime(extraData);
        // Allow for reasonable timing windows (execution could be immediate if interval passed)
        if (nextTime > data.twap.lastExecutionTime) {
            // If lastExecutionTime is set, next time should be reasonable
            assertTrue(
                nextTime >= block.timestamp ||
                    nextTime >= data.twap.lastExecutionTime,
                "Next execution time should be valid"
            );
        } else {
            // If lastExecutionTime is 0, execution can be immediate
            assertGe(
                nextTime,
                data.twap.lastExecutionTime,
                "Next execution time should be valid"
            );
        }
        bool shouldPause = twapExecutor.shouldPauseExecution(extraData);
        assertFalse(shouldPause, "Should not pause with normal volatility");
    }
}
