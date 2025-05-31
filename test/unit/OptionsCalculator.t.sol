
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/calculators/OptionsCalculator.sol";

contract OptionsCalculatorTest is Test {
    OptionsCalculator public optionsCalc;
    
    // Test addresses
    address constant ALICE = address(0x1); // Option seller (order maker)
    address constant BOB = address(0x2);   // Option buyer
    address constant CAROL = address(0x3); // Another trader
    address constant FEE_COLLECTOR = address(0x4);
    
    // Test tokens
    address constant WETH = address(0x10);
    address constant USDC = address(0x20);
    
    function setUp() public {
        optionsCalc = new OptionsCalculator(FEE_COLLECTOR);
        vm.warp(1685000000); // Set base timestamp
    }
    
    function testCreateCallOption() public {
        console.log("=== Testing Call Option Creation ===");
        
        IOrderMixin.Order memory order = _createSellOrder(10e18, 21000e6); // Sell 10 ETH for 21,000 USDC
        bytes32 orderHash = keccak256("test_order");
        
        uint256 strikePrice = 2050e6; // $2,050 USDC per ETH
        uint256 expiration = block.timestamp + 7 days;
        uint256 premium = 50e6; // $50 USDC premium
        
        vm.prank(BOB);
        bytes32 optionId = optionsCalc.createCallOption(
            order,
            orderHash,
            strikePrice,
            expiration,
            premium
        );
        
        OptionsCalculator.OptionData memory option = optionsCalc.getOption(optionId);
        
        assertEq(option.strikePrice, strikePrice, "Strike price should match");
        assertEq(option.expiration, expiration, "Expiration should match");
        assertEq(option.premiumPaid, premium, "Premium should match");
        assertTrue(option.isCall, "Should be a call option");
        assertEq(option.optionHolder, BOB, "Bob should be the holder");
        assertEq(option.optionSeller, ALICE, "Alice should be the seller");
        assertFalse(option.isExercised, "Should not be exercised initially");
        
        console.log(" Call option created successfully");
        console.log("Option ID:", vm.toString(optionId));
        console.log("Strike Price:", strikePrice / 1e6, "USDC");
        console.log("Premium Paid:", premium / 1e6, "USDC");
    }
    
    function testCreatePutOption() public {
        console.log("\n=== Testing Put Option Creation ===");
        
        IOrderMixin.Order memory order = _createBuyOrder(5e18, 9500e6); // Buy 5 ETH for 9,500 USDC ($1,900/ETH)
        bytes32 orderHash = keccak256("put_test_order");
        
        uint256 strikePrice = 1950e6; // $1,950 USDC per ETH
        uint256 expiration = block.timestamp + 14 days;
        uint256 premium = 75e6; // $75 USDC premium
        
        vm.prank(CAROL);
        bytes32 optionId = optionsCalc.createPutOption(
            order,
            orderHash,
            strikePrice,
            expiration,
            premium
        );
        
        OptionsCalculator.OptionData memory option = optionsCalc.getOption(optionId);
        
        assertEq(option.strikePrice, strikePrice, "Strike price should match");
        assertEq(option.expiration, expiration, "Expiration should match");
        assertEq(option.premiumPaid, premium, "Premium should match");
        assertFalse(option.isCall, "Should be a put option");
        assertEq(option.optionHolder, CAROL, "Carol should be the holder");
        assertEq(option.optionSeller, ALICE, "Alice should be the seller");
        
        console.log(" Put option created successfully");
        console.log("Option ID:", vm.toString(optionId));
        console.log("Strike Price:", strikePrice / 1e6, "USDC");
        console.log("Premium Paid:", premium / 1e6, "USDC");
    }
    
    function testProfitableCallExercise() public {
        console.log("\n=== Testing Profitable Call Option Exercise ===");
        
        // Setup: Alice sells 10 ETH for 21,000 USDC ($2,100/ETH)
        IOrderMixin.Order memory order = _createSellOrder(10e18, 21000e6);
        bytes32 orderHash = keccak256("profitable_call_test");
        
        // Bob buys call option with strike at $2,050
        vm.prank(BOB);
        bytes32 optionId = optionsCalc.createCallOption(
            order,
            orderHash,
            2050e6, // Strike: $2,050
            block.timestamp + 7 days,
            50e6    // Premium: $50
        );
        
        // ETH price rises to $2,200
        uint256 currentPrice = 2200e6;
        
        console.log("Current ETH Price:", currentPrice / 1e6, "USDC");
        console.log("Strike Price:", 2050, "USDC");
        console.log("Order Price:", 2100, "USDC");
        
        // Check profitability
        (uint256 profit, bool isProfitable) = optionsCalc.calculateExerciseProfit(optionId, currentPrice, order);
        assertTrue(isProfitable, "Exercise should be profitable");
        console.log("Calculated profit:", profit / 1e6, "USDC");
        
        // Move to exercise window
        vm.warp(block.timestamp + 7 days - 1800);
        
        // Bob exercises the option using universal function
        vm.prank(BOB);
        bool success = optionsCalc.exerciseOption(optionId, order, currentPrice);
        assertTrue(success, "Exercise should succeed");
        
        // Verify option is marked as exercised
        OptionsCalculator.OptionData memory option = optionsCalc.getOption(optionId);
        assertTrue(option.isExercised, "Option should be marked as exercised");
        
        console.log(" Call option exercised successfully");
    }
    
    function testProfitablePutExercise() public {
        console.log("\n=== Testing Profitable Put Option Exercise ===");
        
        // Setup: Alice buys 5 ETH for 9,500 USDC ($1,900/ETH)
        IOrderMixin.Order memory order = _createBuyOrder(5e18, 9500e6);
        bytes32 orderHash = keccak256("profitable_put_test");
        
        // Carol buys put option with strike at $1,950
        vm.prank(CAROL);
        bytes32 optionId = optionsCalc.createPutOption(
            order,
            orderHash,
            1950e6, // Strike: $1,950
            block.timestamp + 7 days,
            30e6    // Premium: $30
        );
        
        // ETH price drops to $1,750
        uint256 currentPrice = 1750e6;
        
        console.log("Current ETH Price:", currentPrice / 1e6, "USDC");
        console.log("Strike Price:", 1950, "USDC");
        console.log("Order Price:", 1900, "USDC");
        
        // Check profitability
        (uint256 profit, bool isProfitable) = optionsCalc.calculateExerciseProfit(optionId, currentPrice, order);
        assertTrue(isProfitable, "Put exercise should be profitable");
        console.log("Calculated profit:", profit / 1e6, "USDC");
        
        // Move to exercise window
        vm.warp(block.timestamp + 7 days - 1800);
        
        // Carol exercises the put option using universal function
        vm.prank(CAROL);
        bool success = optionsCalc.exerciseOption(optionId, order, currentPrice);
        assertTrue(success, "Put exercise should succeed");
        
        // Verify option is marked as exercised
        OptionsCalculator.OptionData memory option = optionsCalc.getOption(optionId);
        assertTrue(option.isExercised, "Option should be marked as exercised");
        
        console.log(" Put option exercised successfully");
    }
    
    function testUniversalExerciseFunction() public {
        console.log("\n=== Testing Universal Exercise Function ===");
        
        // Create both call and put options
        IOrderMixin.Order memory sellOrder = _createSellOrder(1e18, 2000e6);
        IOrderMixin.Order memory buyOrder = _createBuyOrder(1e18, 1800e6);
        
        vm.prank(BOB);
        bytes32 callOptionId = optionsCalc.createCallOption(
            sellOrder,
            keccak256("call_universal"),
            1950e6,
            block.timestamp + 7 days,
            25e6
        );
        
        vm.prank(CAROL);
        bytes32 putOptionId = optionsCalc.createPutOption(
            buyOrder,
            keccak256("put_universal"),
            1850e6,
            block.timestamp + 7 days,
            25e6
        );
        
        // Move to exercise window
        vm.warp(block.timestamp + 7 days - 1800);
        
        // Test universal exercise for call (price rises)
        vm.prank(BOB);
        bool callSuccess = optionsCalc.exerciseOption(callOptionId, sellOrder, 2100e6);
        assertTrue(callSuccess, "Universal call exercise should work");
        
        // Test universal exercise for put (price drops)
        vm.prank(CAROL);
        bool putSuccess = optionsCalc.exerciseOption(putOptionId, buyOrder, 1700e6);
        assertTrue(putSuccess, "Universal put exercise should work");
        
        console.log(" Universal exercise function working correctly");
        console.log("Call option exercised:", callSuccess);
        console.log("Put option exercised:", putSuccess);
    }
    
    function testOptionStatusTracking() public {
        console.log("\n=== Testing Option Status Tracking ===");
        
        IOrderMixin.Order memory order = _createSellOrder(1e18, 2000e6);
        bytes32 orderHash = keccak256("status_test");
        
        vm.prank(BOB);
        bytes32 optionId = optionsCalc.createCallOption(
            order,
            orderHash,
            1900e6,
            block.timestamp + 7 days,
            50e6
        );
        
        // Test different scenarios
        uint256 currentPrice = 2100e6; // In the money
        
        (OptionsCalculator.OptionData memory option, OptionsCalculator.OptionStatus memory status) = 
            optionsCalc.getOptionWithStatus(optionId, currentPrice);
        
        assertFalse(status.isExpired, "Should not be expired yet");
        assertTrue(status.isInTheMoney, "Should be in the money");
        assertFalse(status.isInExerciseWindow, "Should not be in exercise window yet");
        assertTrue(status.intrinsicValue > 0, "Should have intrinsic value");
        
        console.log(" Option status tracking working correctly");
        console.log("Intrinsic Value:", status.intrinsicValue / 1e6, "USDC");
        console.log("Time to Expiration:", status.timeToExpiration / 86400, "days");
        console.log("In the Money:", status.isInTheMoney);
        console.log("Can Exercise:", status.canExercise);
    }
    
    function testCallAndPutPricing() public view {
        console.log("\n=== Testing Call and Put Option Pricing ===");
        
        IOrderMixin.Order memory order = _createSellOrder(1e18, 2000e6);
        
        OptionsCalculator.PricingParams memory params = OptionsCalculator.PricingParams({
            currentPrice: 2100e6,    // Current: $2,100
            timeToExpiration: 14 days,
            volatility: 6000,        // 60% volatility
            riskFreeRate: 500        // 5% risk-free rate
        });
        
        uint256 callPremium = optionsCalc.calculateOptionPremium(order, params, true);
        uint256 putPremium = optionsCalc.calculateOptionPremium(order, params, false);
        
        console.log("Call Premium:", callPremium / 1e6, "USDC");
        console.log("Put Premium:", putPremium / 1e6, "USDC");
        
        assertTrue(callPremium > 0, "Call premium should be positive");
        assertTrue(putPremium >= 0, "Put premium should be non-negative");
        
        // When current > order price, call should be more valuable
        assertTrue(callPremium >= putPremium, "Call should be more valuable when ITM");
        
        console.log(" Call and Put pricing working correctly");
    }
    
    function testOptionGreeksCalculation() public {
        console.log("\n=== Testing Option Greeks Calculation ===");
        
        IOrderMixin.Order memory order = _createSellOrder(1e18, 2100e6);
        bytes32 orderHash = keccak256("greeks_test");
        
        // Create a real option first
        vm.prank(BOB);
        bytes32 optionId = optionsCalc.createCallOption(
            order,
            orderHash,
            2000e6, // Strike: $2,000
            block.timestamp + 7 days,
            100e6   // Premium: $100
        );
        
        // Calculate Greeks with current price higher than strike
        uint256 currentPrice = 2200e6; // $2,200
        OptionsCalculator.OptionGreeks memory greeks = optionsCalc.calculateGreeks(optionId, currentPrice);
        
        console.log("Intrinsic Value:", greeks.intrinsicValue / 1e6, "USDC");
        console.log("Time Value:", greeks.timeValue / 1e6, "USDC");
        console.log("Delta:", greeks.delta);
        console.log("Theta:", greeks.theta);
        
        // Intrinsic value should be positive for in-the-money call
        assertTrue(greeks.intrinsicValue > 0, "Call option should have intrinsic value when ITM");
        assertTrue(greeks.delta > 0, "Call option should have positive delta");
        
        console.log(" Greeks calculated successfully");
    }
    
    function testMultipleOptionsStrategies() public {
        console.log("\n=== Testing Multiple Options Strategies (Straddle) ===");
        
        IOrderMixin.Order memory sellOrder = _createSellOrder(10e18, 20000e6); // $2,000/ETH
        IOrderMixin.Order memory buyOrder = _createBuyOrder(10e18, 18000e6);   // $1,800/ETH
        
        // Straddle strategy: Buy both call and put
        vm.prank(BOB);
        bytes32 callOption = optionsCalc.createCallOption(
            sellOrder,
            keccak256("straddle_call"),
            2100e6, // Call strike: $2,100
            block.timestamp + 30 days,
            100e6   // Premium: $100
        );
        
        vm.prank(BOB);
        bytes32 putOption = optionsCalc.createPutOption(
            buyOrder,
            keccak256("straddle_put"),
            1700e6, // Put strike: $1,700
            block.timestamp + 30 days,
            80e6    // Premium: $80
        );
        
        assertTrue(callOption != putOption, "Options should have different IDs");
        
        OptionsCalculator.OptionData memory call = optionsCalc.getOption(callOption);
        OptionsCalculator.OptionData memory put = optionsCalc.getOption(putOption);
        
        assertTrue(call.isCall, "First option should be call");
        assertFalse(put.isCall, "Second option should be put");
        assertEq(call.optionHolder, BOB, "Bob should hold both options");
        assertEq(put.optionHolder, BOB, "Bob should hold both options");
        
        console.log(" Straddle strategy created successfully");
        console.log("Call Strike:", call.strikePrice / 1e6, "USDC");
        console.log("Put Strike:", put.strikePrice / 1e6, "USDC");
        console.log("Total Premium Paid:", (call.premiumPaid + put.premiumPaid) / 1e6, "USDC");
    }
    
    function testOneinchIntegration() public {
        console.log("\n=== Testing 1inch Integration ===");
        
        IOrderMixin.Order memory order = _createSellOrder(10e18, 20000e6);
        bytes32 orderHash = keccak256("integration_test");
        
        // Create option data for exercise window test
        OptionsCalculator.OptionData memory option = OptionsCalculator.OptionData({
            strikePrice: 2050e6,
            expiration: block.timestamp + 7 days,
            premiumPaid: 100e6,
            isCall: true,
            optionHolder: BOB,
            optionSeller: ALICE,
            isExercised: false,
            impliedVolatility: 8000,
            creationTime: block.timestamp,
            underlyingOrderHash: orderHash
        });
        
        bytes memory extraData = abi.encode(option);
        
        // Test getMakingAmount outside exercise window
        uint256 makingAmount = optionsCalc.getMakingAmount(
            order,
            "",
            orderHash,
            BOB,           // Bob is the taker (option holder)
            5e18,          // Wants 5 ETH
            10e18,         // 10 ETH remaining
            extraData
        );
        
        console.log("Making Amount (outside window):", makingAmount / 1e18, "ETH");
        assertEq(makingAmount, 0, "Should return 0 outside exercise window");
        
        // Move to exercise window
        vm.warp(block.timestamp + 7 days - 1800);
        
        uint256 makingAmountInWindow = optionsCalc.getMakingAmount(
            order,
            "",
            orderHash,
            BOB,
            5e18,
            10e18,
            extraData
        );
        
        console.log("Making Amount (in window):", makingAmountInWindow / 1e18, "ETH");
        assertTrue(makingAmountInWindow > 0, "Should allow execution in exercise window");
        
        console.log(" 1inch integration working correctly");
    }
    
    function testCannotExerciseEarly() public {
        IOrderMixin.Order memory order = _createSellOrder(1e18, 2000e6);
        bytes32 orderHash = keccak256("early_test");
        
        vm.prank(BOB);
        bytes32 optionId = optionsCalc.createCallOption(
            order,
            orderHash,
            1900e6,
            block.timestamp + 7 days,
            50e6
        );
        
        // Try to exercise immediately (should fail - not in exercise window)
        vm.prank(BOB);
        vm.expectRevert(OptionsCalculator.OutsideExerciseWindow.selector);
        optionsCalc.exerciseOption(optionId, order, 2100e6);
        
        console.log(" Early exercise correctly prevented");
    }
    
    function testCannotExerciseAfterExpiry() public {
        IOrderMixin.Order memory order = _createSellOrder(1e18, 2000e6);
        bytes32 orderHash = keccak256("expiry_test");
        
        vm.prank(BOB);
        bytes32 optionId = optionsCalc.createCallOption(
            order,
            orderHash,
            1900e6,
            block.timestamp + 1 days,
            50e6
        );
        
        // Move past expiration
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(BOB);
        vm.expectRevert();  // Will revert with OptionAlreadyExpired
        optionsCalc.exerciseOption(optionId, order, 2100e6);
        
        console.log(" Post-expiry exercise correctly prevented");
    }
    
    function testCannotExerciseUnprofitable() public {
        IOrderMixin.Order memory order = _createSellOrder(1e18, 2000e6);
        bytes32 orderHash = keccak256("unprofitable_exercise");
        
        vm.prank(BOB);
        bytes32 optionId = optionsCalc.createCallOption(
            order,
            orderHash,
            2100e6, // Strike: $2,100
            block.timestamp + 7 days,
            50e6
        );
        
        // Move to exercise window
        vm.warp(block.timestamp + 7 days - 1800);
        
        // Try to exercise when price is below strike (unprofitable)
        vm.prank(BOB);
        vm.expectRevert(OptionsCalculator.ExerciseNotProfitable.selector);
        optionsCalc.exerciseOption(optionId, order, 2000e6); // Price below strike
        
        console.log(" Unprofitable exercise correctly prevented");
    }
    
    // Helper functions
    function _createSellOrder(uint256 makingAmount, uint256 takingAmount) 
        internal pure returns (IOrderMixin.Order memory) 
    {
        return IOrderMixin.Order({
            salt: 1,
            maker: ALICE,
            receiver: ALICE,
            makerAsset: WETH,    // Selling ETH
            takerAsset: USDC,    // For USDC
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: 0
        });
    }
    
    function _createBuyOrder(uint256 makingAmount, uint256 takingAmount) 
        internal pure returns (IOrderMixin.Order memory) 
    {
        return IOrderMixin.Order({
            salt: 2,
            maker: ALICE,
            receiver: ALICE,
            makerAsset: USDC,    // Paying USDC
            takerAsset: WETH,    // To get ETH
            makingAmount: takingAmount,  // Flipped: paying USDC amount
            takingAmount: makingAmount,  // Flipped: getting ETH amount
            makerTraits: 0
        });
    }
}


