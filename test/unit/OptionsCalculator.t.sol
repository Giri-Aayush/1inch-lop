
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
    
    function testProfitableCallExercise() public {
        console.log("\n=== Testing Profitable Call Option Exercise ===");
        
        // Setup: Alice sells 10 ETH for 21,000 USDC ($2,100/ETH)
        IOrderMixin.Order memory order = _createSellOrder(10e18, 21000e6);
        bytes32 orderHash = keccak256("profitable_test");
        
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
        
        // Check if exercise is profitable
        bool isProfitable = optionsCalc.isProfitableToExercise(optionId, currentPrice);
        assertTrue(isProfitable, "Exercise should be profitable");
        
        // Move to exercise window (30 minutes before expiration)
        vm.warp(block.timestamp + 7 days - 1800);
        
        // Bob exercises the option
        vm.prank(BOB);
        bool success = optionsCalc.exerciseCallOption(optionId, order, currentPrice);
        assertTrue(success, "Exercise should succeed");
        
        // Verify option is marked as exercised
        OptionsCalculator.OptionData memory option = optionsCalc.getOption(optionId);
        assertTrue(option.isExercised, "Option should be marked as exercised");
        
        console.log(" Call option exercised successfully");
        console.log("Expected profit: $", (currentPrice - 2050e6) * 10 / 1e6 - 50, "USDC");
    }
    
    function testUnprofitableCallExpiry() public {
        console.log("\n=== Testing Unprofitable Call Option Expiry ===");
        
        IOrderMixin.Order memory order = _createSellOrder(5e18, 10000e6);
        bytes32 orderHash = keccak256("unprofitable_test");
        
        // Bob buys call option
        vm.prank(BOB);
        bytes32 optionId = optionsCalc.createCallOption(
            order,
            orderHash,
            2100e6, // Strike: $2,100
            block.timestamp + 3 days,
            30e6     // Premium: $30
        );
        
        // ETH price stays low at $2,000
        uint256 currentPrice = 2000e6;
        
        bool isProfitable = optionsCalc.isProfitableToExercise(optionId, currentPrice);
        assertFalse(isProfitable, "Exercise should not be profitable");
        
        console.log("Current ETH Price:", currentPrice / 1e6, "USDC");
        console.log("Strike Price:", 2100, "USDC");
        console.log("Not profitable to exercise - Bob loses premium");
        
        console.log(" Option correctly identified as unprofitable");
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
    
    function testOptionPremiumCalculation() public view {
        console.log("\n=== Testing Option Premium Calculation ===");
        
        IOrderMixin.Order memory order = _createSellOrder(1e18, 2000e6); // 1 ETH for 2000 USDC
        
        OptionsCalculator.PricingParams memory params = OptionsCalculator.PricingParams({
            currentPrice: 2100e6,    // Current: $2,100
            timeToExpiration: 7 days,
            volatility: 8000,        // 80% volatility
            riskFreeRate: 500        // 5% risk-free rate
        });
        
        uint256 callPremium = optionsCalc.calculateOptionPremium(order, params, true);
        uint256 putPremium = optionsCalc.calculateOptionPremium(order, params, false);
        
        console.log("Call Premium:", callPremium / 1e6, "USDC");
        console.log("Put Premium:", putPremium / 1e6, "USDC");
        
        assertTrue(callPremium > 0, "Call premium should be positive");
        assertTrue(putPremium >= 0, "Put premium should be non-negative");
        
        // Call should be more valuable when current > strike
        assertTrue(callPremium > putPremium, "Call should be more valuable than put when ITM");
        
        console.log(" Premium calculation working correctly");
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
        optionsCalc.exerciseCallOption(optionId, order, 2100e6);
        
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
        optionsCalc.exerciseCallOption(optionId, order, 2100e6);
        
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
        optionsCalc.exerciseCallOption(optionId, order, 2000e6); // Price below strike
        
        console.log(" Unprofitable exercise correctly prevented");
    }
    
    function testMultipleOptionsOnSameOrder() public {
        console.log("\n=== Testing Multiple Options on Same Order ===");
        
        IOrderMixin.Order memory order = _createSellOrder(10e18, 20000e6);
        bytes32 orderHash = keccak256("multi_options_test");
        
        // Bob creates first option
        vm.prank(BOB);
        bytes32 option1 = optionsCalc.createCallOption(
            order,
            orderHash,
            2100e6,
            block.timestamp + 7 days,
            50e6
        );
        
        // Carol creates second option on same order
        vm.prank(CAROL);
        bytes32 option2 = optionsCalc.createCallOption(
            order,
            orderHash,
            2200e6,
            block.timestamp + 14 days,
            75e6
        );
        
        assertTrue(option1 != option2, "Option IDs should be different");
        
        OptionsCalculator.OptionData memory opt1 = optionsCalc.getOption(option1);
        OptionsCalculator.OptionData memory opt2 = optionsCalc.getOption(option2);
        
        assertEq(opt1.optionHolder, BOB, "Bob should hold first option");
        assertEq(opt2.optionHolder, CAROL, "Carol should hold second option");
        assertEq(opt1.strikePrice, 2100e6, "First option strike should be 2100");
        assertEq(opt2.strikePrice, 2200e6, "Second option strike should be 2200");
        
        console.log(" Multiple options created successfully");
        console.log("Bob's strike:", opt1.strikePrice / 1e6, "USDC");
        console.log("Carol's strike:", opt2.strikePrice / 1e6, "USDC");
    }
    
    // Helper function to create sell orders
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
}