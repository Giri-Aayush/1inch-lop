// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { stdError } from "forge-std/StdError.sol";
import "../../../src/calculators/EnhancedVolatilityCalculator.sol";
import "../../../src/calculators/EnhancedTWAPVolatilityExecutor.sol";
import "../../../src/calculators/OptionsCalculator.sol";

/**
 * @title BaseMainnetTest
 * @notice Shared test infrastructure for all mainnet fork tests
 * @dev Provides common setup, constants, and helper functions
 */
abstract contract BaseMainnetTest is Test {
    // ============ CONSTANTS ============

    // Real mainnet token addresses
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // Whale addresses for funding tests
    address internal constant WETH_WHALE = 0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E;
    address internal constant USDC_WHALE = 0xaD354CfBAa4A8572DD6Df021514a3931A8329Ef5;
    address internal constant USDT_WHALE = 0x5754284f345afc66a98fbB0a0Afe71e0F007B949;

    // Test constants
    uint256 internal constant TEST_ETH_PRICE = 2000e6; // $2000 per ETH
    uint256 internal constant BASIS_POINTS = 10_000;
    uint256 internal constant ONE_DAY = 86_400;
    uint256 internal constant ONE_WEEK = 7 * ONE_DAY;

    // ============ CONTRACTS ============

    EnhancedVolatilityCalculator internal volatilityCalc;
    EnhancedTWAPVolatilityExecutor internal twapExecutor;
    OptionsCalculator internal optionsCalc;

    // ============ TEST ACCOUNTS ============

    address internal alice = address(0x1111); // Primary maker
    address internal bob = address(0x2222); // Primary taker
    address internal carol = address(0x3333); // Options trader
    address internal dave = address(0x4444); // Additional trader
    address internal eve = address(0x5555); // Protocol fee collector

    // ============ SETUP ============

    function setUp() public virtual {
        // Label addresses for better trace output
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(carol, "Carol");
        vm.label(dave, "Dave");
        vm.label(eve, "Eve");
        vm.label(WETH, "WETH");
        vm.label(USDC, "USDC");
        vm.label(USDT, "USDT");
        vm.label(DAI, "DAI");
        vm.label(WETH_WHALE, "WETH_Whale");
        vm.label(USDC_WHALE, "USDC_Whale");
        vm.label(USDT_WHALE, "USDT_Whale");

        // Deploy contracts
        volatilityCalc = new EnhancedVolatilityCalculator();
        twapExecutor = new EnhancedTWAPVolatilityExecutor(address(volatilityCalc));
        optionsCalc = new OptionsCalculator(eve);

        // Fund test accounts
        _fundTestAccounts();
    }

    // ============ HELPER FUNCTIONS ============

    function _fundTestAccounts() internal {
        // Check whale balances
        uint256 whaleWETH = IERC20(WETH).balanceOf(WETH_WHALE);
        uint256 whaleUSDC = IERC20(USDC).balanceOf(USDC_WHALE);

        vm.assume(whaleWETH >= 100 ether);
        vm.assume(whaleUSDC >= 200_000e6);

        // Fund test accounts with WETH
        vm.startPrank(WETH_WHALE);
        IERC20(WETH).transfer(alice, 30 ether);
        IERC20(WETH).transfer(bob, 20 ether);
        IERC20(WETH).transfer(carol, 15 ether);
        IERC20(WETH).transfer(dave, 10 ether);
        vm.stopPrank();

        // Fund test accounts with USDC
        vm.startPrank(USDC_WHALE);
        IERC20(USDC).transfer(alice, 80_000e6);
        IERC20(USDC).transfer(bob, 60_000e6);
        IERC20(USDC).transfer(carol, 40_000e6);
        IERC20(USDC).transfer(dave, 20_000e6);
        vm.stopPrank();
    }

    // ============ ORDER HELPERS ============

    function _createETHSellOrder(
        uint256 ethAmount,
        uint256 pricePerETH
    )
        internal
        view
        returns (IOrderMixin.Order memory)
    {
        return IOrderMixin.Order({
            salt: uint256(keccak256(abi.encode("sell", ethAmount, pricePerETH, block.timestamp))),
            maker: alice,
            receiver: alice,
            makerAsset: WETH,
            takerAsset: USDC,
            makingAmount: ethAmount,
            takingAmount: (ethAmount * pricePerETH) / 1e18,
            makerTraits: 0
        });
    }

    function _createETHBuyOrder(
        uint256 ethAmount,
        uint256 pricePerETH
    )
        internal
        view
        returns (IOrderMixin.Order memory)
    {
        return IOrderMixin.Order({
            salt: uint256(keccak256(abi.encode("buy", ethAmount, pricePerETH, block.timestamp))),
            maker: alice,
            receiver: alice,
            makerAsset: USDC,
            takerAsset: WETH,
            makingAmount: (ethAmount * pricePerETH) / 1e18,
            takingAmount: ethAmount,
            makerTraits: 0
        });
    }

    function _createMultiAssetOrder(
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount
    )
        internal
        view
        returns (IOrderMixin.Order memory)
    {
        return IOrderMixin.Order({
            salt: uint256(keccak256(abi.encode(makerAsset, takerAsset, makingAmount, takingAmount, block.timestamp))),
            maker: alice,
            receiver: alice,
            makerAsset: makerAsset,
            takerAsset: takerAsset,
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: 0
        });
    }

    // ============ VOLATILITY HELPERS ============

    function _createLowVolatilityData() internal view returns (EnhancedVolatilityCalculator.VolatilityData memory) {
        return EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 200, // 2%
            currentVolatility: 100, // 1% (very low)
            maxExecutionSize: 10 ether,
            minExecutionSize: 0.05 ether,
            volatilityThreshold: 400, // 4%
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 1000 // 10%
         });
    }

    function _createNormalVolatilityData() internal view returns (EnhancedVolatilityCalculator.VolatilityData memory) {
        return EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 300, // 3%
            currentVolatility: 350, // 3.5% (normal)
            maxExecutionSize: 5 ether,
            minExecutionSize: 0.1 ether,
            volatilityThreshold: 500, // 5%
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 1200 // 12%
         });
    }

    function _createHighVolatilityData() internal view returns (EnhancedVolatilityCalculator.VolatilityData memory) {
        return EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 300, // 3%
            currentVolatility: 800, // 8% (high)
            maxExecutionSize: 2 ether,
            minExecutionSize: 0.1 ether,
            volatilityThreshold: 500, // 5%
            lastUpdateTime: block.timestamp,
            conservativeMode: false,
            emergencyThreshold: 1200 // 12%
         });
    }

    function _createExtremeVolatilityData()
        internal
        view
        returns (EnhancedVolatilityCalculator.VolatilityData memory)
    {
        return EnhancedVolatilityCalculator.VolatilityData({
            baselineVolatility: 300, // 3%
            currentVolatility: 1100, // 11% (extreme, near emergency)
            maxExecutionSize: 1 ether,
            minExecutionSize: 0.05 ether,
            volatilityThreshold: 500, // 5%
            lastUpdateTime: block.timestamp,
            conservativeMode: true, // Conservative mode
            emergencyThreshold: 1200 // 12%
         });
    }

    // ============ TWAP HELPERS ============

    function _createShortTWAPData() internal view returns (EnhancedTWAPVolatilityExecutor.TWAPData memory) {
        return EnhancedTWAPVolatilityExecutor.TWAPData({
            startTime: block.timestamp,
            duration: 1800, // 30 minutes
            intervals: 6, // Every 5 minutes
            baseInterval: 300, // 5 minutes
            lastExecutionTime: 0,
            executedAmount: 0,
            randomizeExecution: false,
            adaptiveIntervals: true
        });
    }

    function _createMediumTWAPData() internal view returns (EnhancedTWAPVolatilityExecutor.TWAPData memory) {
        return EnhancedTWAPVolatilityExecutor.TWAPData({
            startTime: block.timestamp,
            duration: 7200, // 2 hours
            intervals: 12, // Every 10 minutes
            baseInterval: 600, // 10 minutes
            lastExecutionTime: 0,
            executedAmount: 0,
            randomizeExecution: true,
            adaptiveIntervals: true
        });
    }

    function _createLongTWAPData() internal view returns (EnhancedTWAPVolatilityExecutor.TWAPData memory) {
        return EnhancedTWAPVolatilityExecutor.TWAPData({
            startTime: block.timestamp,
            duration: 21_600, // 6 hours
            intervals: 24, // Every 15 minutes
            baseInterval: 900, // 15 minutes
            lastExecutionTime: 0,
            executedAmount: 0,
            randomizeExecution: true,
            adaptiveIntervals: true
        });
    }

    function _createCombinedStrategyData(
        EnhancedTWAPVolatilityExecutor.TWAPData memory twapData,
        EnhancedVolatilityCalculator.VolatilityData memory volData
    )
        internal
        pure
        returns (EnhancedTWAPVolatilityExecutor.CombinedStrategyData memory)
    {
        return EnhancedTWAPVolatilityExecutor.CombinedStrategyData({ twap: twapData, volatility: volData });
    }

    // ============ OPTIONS HELPERS ============

    function _createCallOptionData(
        uint256 strikePrice,
        uint256 expiration,
        uint256 premium
    )
        internal
        view
        returns (OptionsCalculator.OptionData memory)
    {
        return OptionsCalculator.OptionData({
            strikePrice: strikePrice,
            expiration: expiration,
            premiumPaid: premium,
            isCall: true,
            optionHolder: bob,
            optionSeller: alice,
            isExercised: false,
            impliedVolatility: 8000, // 80%
            creationTime: block.timestamp,
            underlyingOrderHash: bytes32(0)
        });
    }

    function _createPutOptionData(
        uint256 strikePrice,
        uint256 expiration,
        uint256 premium
    )
        internal
        view
        returns (OptionsCalculator.OptionData memory)
    {
        return OptionsCalculator.OptionData({
            strikePrice: strikePrice,
            expiration: expiration,
            premiumPaid: premium,
            isCall: false,
            optionHolder: carol,
            optionSeller: alice,
            isExercised: false,
            impliedVolatility: 8000, // 80%
            creationTime: block.timestamp,
            underlyingOrderHash: bytes32(0)
        });
    }

    // ============ PRICE HELPERS ============

    function _getRandomETHPrice() internal view returns (uint256) {
        uint256 seed = uint256(keccak256(abi.encode(block.timestamp, block.difficulty)));
        uint256 variation = (seed % 800) + 1600; // $1600-$2400
        return variation * 1e6; // Convert to 6 decimal USDC format
    }

    function _getBullishETHPrice() internal pure returns (uint256) {
        return 2400e6; // $2400 (bullish scenario)
    }

    function _getBearishETHPrice() internal pure returns (uint256) {
        return 1600e6; // $1600 (bearish scenario)
    }

    // ============ TIME HELPERS ============

    function _advanceTime(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }

    function _advanceTimeToExecutionWindow(uint256 expiration) internal {
        vm.warp(expiration - 1800); // 30 minutes before expiry
    }

    function _advanceTimeToExpiry(uint256 expiration) internal {
        vm.warp(expiration + 1);
    }

    // ============ ASSERTION HELPERS ============

    function _assertVolatilityBounds(
        uint256 amount,
        EnhancedVolatilityCalculator.VolatilityData memory volData
    )
        internal
    {
        assertGe(amount, volData.minExecutionSize, "Should respect minimum execution size");
        assertLe(amount, volData.maxExecutionSize, "Should respect maximum execution size");
    }

    function _assertTWAPProgress(uint256 executed, uint256 total, uint256 expectedProgressBPS) internal {
        uint256 actualProgressBPS = (executed * BASIS_POINTS) / total;
        assertApproxEqAbs(actualProgressBPS, expectedProgressBPS, 100, "TWAP progress should be approximately correct");
    }

    function _assertOptionProfitability(
        bytes32 optionId,
        uint256 currentPrice,
        IOrderMixin.Order memory order,
        bool shouldBeProfitable
    )
        internal
    {
        (uint256 profit, bool isProfitable) = optionsCalc.calculateExerciseProfit(optionId, currentPrice, order);
        assertEq(isProfitable, shouldBeProfitable, "Option profitability should match expectation");

        if (shouldBeProfitable) {
            assertGt(profit, 0, "Profitable option should have positive profit");
        } else {
            assertEq(profit, 0, "Unprofitable option should have zero profit");
        }
    }

    // ============ GAS MEASUREMENT ============

    function _measureGas(function() internal func) internal returns (uint256 gasUsed) {
        uint256 gasStart = gasleft();
        func();
        gasUsed = gasStart - gasleft();
    }

    function _assertGasEfficiency(uint256 gasUsed, uint256 maxGas, string memory operation) internal {
        assertLt(gasUsed, maxGas, string(abi.encodePacked(operation, " should be gas efficient")));
    }
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}
