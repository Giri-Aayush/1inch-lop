// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";
import "../src/calculators/EnhancedVolatilityCalculator.sol";
import "../src/calculators/EnhancedTWAPVolatilityExecutor.sol";
import "../src/calculators/OptionsCalculator.sol";

/**
 * @title MainnetForkTest
 * @notice Comprehensive mainnet fork testing following Foundry best practices
 */
contract MainnetForkTest is Test {
    // Constants for real mainnet addresses
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH_WHALE = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;
    address constant USDC_WHALE = 0xaD354CfBAa4A8572DD6Df021514a3931A8329Ef5;
    
    // Test contracts
    EnhancedVolatilityCalculator public volatilityCalc;
    EnhancedTWAPVolatilityExecutor public twapExecutor;
    OptionsCalculator public optionsCalc;
    
    // Test accounts
    address public alice;
    address public bob;
    address public carol;
    
    // Test data
    uint256 constant TEST_ETH_PRICE = 2000e6; // $2000 per ETH
    
    function setUp() public {
        // Initialize test accounts
        alice = address(0x1111);
        bob = address(0x2222);
        carol = address(0x3333);
        
        // Label addresses for better traces
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(carol, "Carol");
        vm.label(WETH, "WETH");
        vm.label(USDC, "USDC");
        vm.label(WETH_WHALE, "WETH_Whale");
        vm.label(USDC_WHALE, "USDC_Whale");
        
        // Deploy our contracts
        volatilityCalc = new EnhancedVolatilityCalculator();
        twapExecutor = new EnhancedTWAPVolatilityExecutor(address(volatilityCalc));
        optionsCalc = new OptionsCalculator(carol);
        
        // Fund test accounts with real tokens
        _fundTestAccounts();
    }
    
    // ============ VOLATILITY TESTS ============
    
    function test_VolatilityValidation_HighVolatility() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        
        // Should not revert for valid high volatility data
        volatilityCalc.validateVolatilityData(volData);
    }
    
    function testRevert_VolatilityValidation_EmergencyThreshold() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        volData.currentVolatility = 1500; // Above emergency threshold of 1200
        
        vm.expectRevert(EnhancedVolatilityCalculator.EmergencyModeTriggered.selector);
        volatilityCalc.validateVolatilityData(volData);
    }
    
    function testRevert_VolatilityValidation_TooHigh() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        volData.currentVolatility = 1600; // 5.33x baseline (over 5x limit)
        volData.emergencyThreshold = 2000; // Set higher to avoid emergency error
        
        vm.expectRevert(EnhancedVolatilityCalculator.VolatilityTooHigh.selector);
        volatilityCalc.validateVolatilityData(volData);
    }
    
    function testRevert_VolatilityValidation_StaleData() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        volData.lastUpdateTime = block.timestamp - 7200; // 2 hours old (stale)
        
        vm.expectRevert(EnhancedVolatilityCalculator.StaleVolatilityData.selector);
        volatilityCalc.validateVolatilityData(volData);
    }
    
    function test_VolatilityAdjustment_HighVolatilityReducesAmount() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        uint256 baseAmount = 2 ether;
        
        uint256 adjustedAmount = volatilityCalc.applyVolatilityAdjustment(baseAmount, volData);
        
        assertLt(adjustedAmount, baseAmount, "High volatility should reduce amount");
        assertGe(adjustedAmount, volData.minExecutionSize, "Should respect minimum size");
        assertLe(adjustedAmount, volData.maxExecutionSize, "Should respect maximum size");
    }
    
    function test_VolatilityAdjustment_LowVolatilityIncreasesAmount() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createLowVolatilityData();
        uint256 baseAmount = 1 ether;
        
        uint256 adjustedAmount = volatilityCalc.applyVolatilityAdjustment(baseAmount, volData);
        
        assertGt(adjustedAmount, baseAmount, "Low volatility should increase amount");
        assertLe(adjustedAmount, volData.maxExecutionSize, "Should respect maximum size");
    }
    
    function test_VolatilityMetrics_HighRiskScore() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        
        EnhancedVolatilityCalculator.VolatilityMetrics memory metrics = 
            volatilityCalc.calculateVolatilityMetrics(volData);
        
        assertGt(metrics.riskScore, 500, "High volatility should have high risk score");
        assertLt(metrics.adjustmentFactor, 100, "High volatility should reduce adjustment factor");
        assertFalse(metrics.shouldPause, "Should not pause below emergency threshold");
    }
    
    // ============ TWAP TESTS ============
    
    function test_TWAPExecution_ValidConfiguration() public {
        IOrderMixin.Order memory order = _createTestOrder();
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory data = _createCombinedStrategyData();
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));
        
        uint256 makingAmount = twapExecutor.getMakingAmount(
            order, "", orderHash, bob, 1 ether, 10 ether, extraData
        );
        
        assertGt(makingAmount, 0, "Should allow execution");
        assertLe(makingAmount, data.volatility.maxExecutionSize, "Should respect volatility limits");
    }
    
    function testRevert_TWAP_NotStarted() public {
        IOrderMixin.Order memory order = _createTestOrder();
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory data = _createCombinedStrategyData();
        data.twap.startTime = block.timestamp + 1000; // Future start time
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));
        
        vm.expectRevert(EnhancedTWAPVolatilityExecutor.TWAPNotStarted.selector);
        twapExecutor.getMakingAmount(order, "", orderHash, bob, 1 ether, 10 ether, extraData);
    }
    
function testRevert_TWAP_Expired() public {
    IOrderMixin.Order memory order = _createTestOrder();
    EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory data = _createCombinedStrategyData();
    
    // Move past expiration AND keep data fresh
    vm.warp(data.twap.startTime + data.twap.duration + 1);
    
    // Update volatility data timestamp to be recent (not stale)
    data.volatility.lastUpdateTime = block.timestamp;
    
    bytes memory extraData = abi.encode(data);
    bytes32 orderHash = keccak256(abi.encode(order));
    
    vm.expectRevert(EnhancedTWAPVolatilityExecutor.TWAPExpired.selector);
    twapExecutor.getMakingAmount(order, "", orderHash, bob, 1 ether, 10 ether, extraData);
}
    
    function testRevert_TWAP_FullyExecuted() public {
        IOrderMixin.Order memory order = _createTestOrder();
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory data = _createCombinedStrategyData();
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));
        
        vm.expectRevert(EnhancedTWAPVolatilityExecutor.TWAPFullyExecuted.selector);
        twapExecutor.getMakingAmount(order, "", orderHash, bob, 1 ether, 0, extraData); // 0 remaining
    }
    
    function test_TWAP_ProgressTracking() public {
        IOrderMixin.Order memory order = _createTestOrder();
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory data = _createCombinedStrategyData();
        bytes memory extraData = abi.encode(data);
        
        uint256 remainingAmount = 3 ether; // 70% executed (10 - 7 = 3)
        uint256 progress = twapExecutor.getExecutionProgress(order, remainingAmount, extraData);
        
        assertEq(progress, 7000, "Should show 70% progress (7000 basis points)");
    }
    
    function test_TWAP_TimeBasedExecution() public {
        IOrderMixin.Order memory order = _createTestOrder();
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory data = _createCombinedStrategyData();
        bytes memory extraData = abi.encode(data);
        bytes32 orderHash = keccak256(abi.encode(order));
        
        uint256 totalExecuted = 0;
        uint256 remainingAmount = order.makingAmount;
        
        // Simulate 3 executions over time
        for (uint i = 0; i < 3; i++) {
            vm.warp(block.timestamp + 600); // +10 minutes
            
            uint256 execution = twapExecutor.getMakingAmount(
                order, "", orderHash, bob, 1 ether, remainingAmount, extraData
            );
            
            assertGt(execution, 0, "Should allow execution");
            totalExecuted += execution;
            remainingAmount -= execution;
        }
        
        assertGt(totalExecuted, 0, "Should have executed some amount");
        assertLt(remainingAmount, order.makingAmount, "Should have reduced remaining amount");
    }
    
    // ============ OPTIONS TESTS ============
    
    function test_OptionsCreation_CallOption() public {
        IOrderMixin.Order memory order = _createTestOrder();
        bytes32 orderHash = keccak256(abi.encode(order));
        
        vm.prank(bob);
        bytes32 optionId = optionsCalc.createCallOption(
            order, orderHash, 2100e6, block.timestamp + 7 days, 100e6
        );
        
        OptionsCalculator.OptionData memory option = optionsCalc.getOption(optionId);
        
        assertEq(option.optionHolder, bob, "Bob should be option holder");
        assertEq(option.optionSeller, alice, "Alice should be option seller");
        assertTrue(option.isCall, "Should be call option");
        assertEq(option.strikePrice, 2100e6, "Strike price should match");
        assertFalse(option.isExercised, "Should not be exercised initially");
    }
    
    function test_OptionsCreation_PutOption() public {
        IOrderMixin.Order memory buyOrder = _createBuyOrder();
        bytes32 orderHash = keccak256(abi.encode(buyOrder));
        
        vm.prank(carol);
        bytes32 optionId = optionsCalc.createPutOption(
            buyOrder, orderHash, 1900e6, block.timestamp + 14 days, 75e6
        );
        
        OptionsCalculator.OptionData memory option = optionsCalc.getOption(optionId);
        
        assertEq(option.optionHolder, carol, "Carol should be option holder");
        assertEq(option.optionSeller, alice, "Alice should be option seller");
        assertFalse(option.isCall, "Should be put option");
        assertEq(option.strikePrice, 1900e6, "Strike price should match");
    }
    
    function testRevert_Options_InvalidStrikePrice() public {
        IOrderMixin.Order memory order = _createTestOrder();
        bytes32 orderHash = keccak256(abi.encode(order));
        
        vm.prank(bob);
        vm.expectRevert(OptionsCalculator.InvalidStrikePrice.selector);
        optionsCalc.createCallOption(order, orderHash, 0, block.timestamp + 7 days, 100e6); // Invalid strike
    }
    
    function testRevert_Options_InvalidExpiration() public {
        IOrderMixin.Order memory order = _createTestOrder();
        bytes32 orderHash = keccak256(abi.encode(order));
        
        vm.prank(bob);
        vm.expectRevert(OptionsCalculator.InvalidExpiration.selector);
        optionsCalc.createCallOption(order, orderHash, 2100e6, block.timestamp + 100, 100e6); // Too short
    }
    
    function test_OptionsProfitability_CallInTheMoney() public {
        IOrderMixin.Order memory order = _createTestOrder();
        bytes32 orderHash = keccak256(abi.encode(order));
        
        vm.prank(bob);
        bytes32 optionId = optionsCalc.createCallOption(
            order, orderHash, 2100e6, block.timestamp + 7 days, 100e6
        );
        
        uint256 highPrice = 2200e6; // Above strike
        (uint256 profit, bool isProfitable) = optionsCalc.calculateExerciseProfit(optionId, highPrice, order);
        
        assertTrue(isProfitable, "Should be profitable when price > strike");
        assertGt(profit, 0, "Should have positive profit");
    }
    
    function test_OptionsProfitability_CallOutOfMoney() public {
        IOrderMixin.Order memory order = _createTestOrder();
        bytes32 orderHash = keccak256(abi.encode(order));
        
        vm.prank(bob);
        bytes32 optionId = optionsCalc.createCallOption(
            order, orderHash, 2100e6, block.timestamp + 7 days, 100e6
        );
        
        uint256 lowPrice = 2000e6; // Below strike
        (uint256 profit, bool isProfitable) = optionsCalc.calculateExerciseProfit(optionId, lowPrice, order);
        
        assertFalse(isProfitable, "Should not be profitable when price < strike");
        assertEq(profit, 0, "Should have zero profit");
    }
    
    function test_OptionsExercise_InWindow() public {
        IOrderMixin.Order memory order = _createTestOrder();
        bytes32 orderHash = keccak256(abi.encode(order));
        
        vm.prank(bob);
        bytes32 optionId = optionsCalc.createCallOption(
            order, orderHash, 2100e6, block.timestamp + 7 days, 100e6
        );
        
        // Move to exercise window (30 min before expiry)
        vm.warp(block.timestamp + 7 days - 1800);
        
        OptionsCalculator.OptionData memory option = optionsCalc.getOption(optionId);
        bool canExercise = optionsCalc.canExercise(option, bob);
        
        assertTrue(canExercise, "Should be able to exercise in window");
        
        vm.prank(bob);
        bool success = optionsCalc.exerciseOption(optionId, order, 2200e6);
        assertTrue(success, "Exercise should succeed");
        
        // Verify option is marked as exercised
        OptionsCalculator.OptionData memory exercisedOption = optionsCalc.getOption(optionId);
        assertTrue(exercisedOption.isExercised, "Should be marked as exercised");
    }
    
    function testRevert_OptionsExercise_OutsideWindow() public {
        IOrderMixin.Order memory order = _createTestOrder();
        bytes32 orderHash = keccak256(abi.encode(order));
        
        vm.prank(bob);
        bytes32 optionId = optionsCalc.createCallOption(
            order, orderHash, 2100e6, block.timestamp + 7 days, 100e6
        );
        
        // Try to exercise immediately (outside window)
        vm.prank(bob);
        vm.expectRevert(OptionsCalculator.OutsideExerciseWindow.selector);
        optionsCalc.exerciseOption(optionId, order, 2200e6);
    }
    
    function testRevert_OptionsExercise_Unprofitable() public {
        IOrderMixin.Order memory order = _createTestOrder();
        bytes32 orderHash = keccak256(abi.encode(order));
        
        vm.prank(bob);
        bytes32 optionId = optionsCalc.createCallOption(
            order, orderHash, 2100e6, block.timestamp + 7 days, 100e6
        );
        
        // Move to exercise window
        vm.warp(block.timestamp + 7 days - 1800);
        
        // Try to exercise at unprofitable price
        vm.prank(bob);
        vm.expectRevert(OptionsCalculator.ExerciseNotProfitable.selector);
        optionsCalc.exerciseOption(optionId, order, 2000e6); // Below strike
    }
    
    // ============ INTEGRATION TESTS ============
    
    function test_Integration_1inchCompatibility() public {
        IOrderMixin.Order memory order = _createTestOrder();
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        bytes memory extraData = abi.encode(volData);
        
        // Test getMakingAmount interface
        uint256 makingAmount = volatilityCalc.getMakingAmount(
            order, "", keccak256("test"), bob, 0.5 ether, 1 ether, extraData
        );
        
        // Test getTakingAmount interface
        uint256 takingAmount = volatilityCalc.getTakingAmount(
            order, "", keccak256("test"), bob, 0.5 ether, 1 ether, extraData
        );
        
        assertGt(makingAmount, 0, "Should return valid making amount");
        assertGt(takingAmount, 0, "Should return valid taking amount");
    }
    
    function test_Integration_GasEfficiency() public {
        EnhancedVolatilityCalculator.VolatilityData memory volData = _createHighVolatilityData();
        uint256 gasUsed;
        
        // Test volatility adjustment gas
        uint256 gasStart = gasleft();
        volatilityCalc.applyVolatilityAdjustment(1 ether, volData);
        gasUsed = gasStart - gasleft();
        
        assertLt(gasUsed, 50000, "Volatility calculation should be gas efficient");
        
        // Test TWAP calculation gas
        IOrderMixin.Order memory order = _createTestOrder();
        EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory combined = _createCombinedStrategyData();
        
        gasStart = gasleft();
        twapExecutor.getMakingAmount(
            order, "", keccak256("test"), bob, 0.5 ether, 1 ether, abi.encode(combined)
        );
        gasUsed = gasStart - gasleft();
        
        assertLt(gasUsed, 100000, "TWAP calculation should be gas efficient");
    }
    
    // ============ HELPER FUNCTIONS ============
    
    function _fundTestAccounts() internal {
        // Check whale balances
        uint256 whaleWETH = IERC20(WETH).balanceOf(WETH_WHALE);
        uint256 whaleUSDC = IERC20(USDC).balanceOf(USDC_WHALE);
        
        vm.assume(whaleWETH >= 50 ether);
        vm.assume(whaleUSDC >= 100000e6);
        
        // Fund test accounts
        vm.startPrank(WETH_WHALE);
        IERC20(WETH).transfer(alice, 20 ether);
        IERC20(WETH).transfer(bob, 10 ether);
        vm.stopPrank();
        
        vm.startPrank(USDC_WHALE);
        IERC20(USDC).transfer(alice, 50000e6);
        IERC20(USDC).transfer(bob, 25000e6);
        vm.stopPrank();
    }
    
    function _createHighVolatilityData() internal view returns (EnhancedVolatilityCalculator.VolatilityData memory) {
        return EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 300,
            currentVolatility: 800,
            maxExecutionSize: 5 ether,
            minExecutionSize: 0.1 ether,
            volatilityThreshold: 500,
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 1200
        });
    }
    
    function _createLowVolatilityData() internal view returns (EnhancedVolatilityCalculator.VolatilityData memory) {
        return EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 300,
            currentVolatility: 150, // Low volatility
            maxExecutionSize: 5 ether,
            minExecutionSize: 0.1 ether,
            volatilityThreshold: 500,
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 1200
        });
    }
    
    function _createTestOrder() internal view returns (IOrderMixin.Order memory) {
        return IOrderMixin.Order({
            salt: 1,
            maker: alice,
            receiver: alice,
            makerAsset: WETH,
            takerAsset: USDC,
            makingAmount: 10 ether,
            takingAmount: TEST_ETH_PRICE * 10,
            makerTraits: 0
        });
    }
    
    function _createBuyOrder() internal view returns (IOrderMixin.Order memory) {
        return IOrderMixin.Order({
            salt: 2,
            maker: alice,
            receiver: alice,
            makerAsset: USDC,
            takerAsset: WETH,
            makingAmount: 9500e6, // Paying 9500 USDC
            takingAmount: 5 ether, // To get 5 ETH
            makerTraits: 0
        });
    }
    
    function _createCombinedStrategyData() internal view returns (EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory) {
        return EnhancedTWAPVolatilityExecutor.CombinedStrategyData({
            twap: EnhancedTWAPVolatilityExecutor.TWAPData({
                startTime: block.timestamp,
                duration: 7200, // 2 hours
                intervals: 12,
                baseInterval: 600, // 10 minutes
                lastExecutionTime: 0,
                executedAmount: 0,
                randomizeExecution: true,
                adaptiveIntervals: true
            }),
            volatility: _createHighVolatilityData()
        });
    }
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}