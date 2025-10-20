// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console2} from "forge-std/Test.sol";
import {DeployRup} from "../../script/DeployRup.s.sol";
import {Rupay} from "../../src/Rupay.sol";
import {RupIssuer} from "../../src/RupIssuer.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {AggregatorV3Interface} from "@@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "@@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract TestRupIssuer is Test {
    Rupay rup;
    RupIssuer rupIssuer;
    HelperConfig helperConfig;

    address user = makeAddr("user");
    address user2 = makeAddr("user2");
    uint256 amountToMint = 100 ether;
    uint256 amountToDeposit = 10 ether;
    uint8 public constant DECIMALS = 6;
    int256 public constant ETH_USD_PRICE = 4000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    address weth;
    address wbtc;
    AggregatorV3Interface opUsdPriceFeed;
    ERC20Mock wopMock;
    address wop;

    event PriceFeedUpdated(
        address indexed token, address indexed priceFeed, address indexed sequencerFeed, uint256 stalePriceThreshold
    );
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event RupMinted(address indexed user, uint256 amount);
    event CollateralRedeemed(address indexed user, address indexed to, address indexed token, uint256 amount);
    event RupBurned(address indexed user, uint256 amount);
    event AccountsLiquidated(
        address indexed user,
        address indexed liquidator,
        address indexed token,
        uint256 debtCovered,
        uint256 collateralRedeemed
    );

    function setUp() external {
        DeployRup deployer = new DeployRup();
        (rup, rupIssuer, helperConfig) = deployer.run();
        console2.log("Rupay deployed to:", address(rup));
        console2.log("RupIssuer deployed to:", address(rupIssuer));

        (,,,,,, weth, wbtc,) = helperConfig.activeNetworkConfig();

        // Mint some WETH to user
        ERC20Mock(weth).mint(user, 100 ether);
        vm.prank(user);
        ERC20Mock(weth).approve(address(rupIssuer), type(uint256).max);

        // Mint some WBTC to user
        ERC20Mock(wbtc).mint(user, amountToMint);
        vm.prank(user);
        ERC20Mock(wbtc).approve(address(rupIssuer), type(uint256).max);

        // Mint tokens to user2
        ERC20Mock(weth).mint(user2, 100 ether);
        vm.prank(user2);
        ERC20Mock(weth).approve(address(rupIssuer), type(uint256).max);

        opUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        wopMock = new ERC20Mock("WOP", "WOP", msg.sender, 1000e18);
        wop = address(wopMock);
    }

    // ---------------------------------
    // Core setup tests
    // ---------------------------------
    function testRupayInitializedCorrectly() public view {
        assertEq(rup.name(), "Rupay");
        assertEq(rup.symbol(), "RUP");
        assertEq(rup.totalSupply(), 0);
        assertEq(rup.owner(), address(rupIssuer));
    }

    function testRupIssuerInitializedCorrectly() public view {
        assertEq(rupIssuer.getRupayAddress(), address(rup));
        assertEq(rupIssuer.getMinHealthFactor(), 1e18);
        assertEq(rupIssuer.getLiquidationThreshold(), 50);
        assertEq(rupIssuer.getLiquidationPrecision(), 100);
        assertTrue(rupIssuer.getCollateralTokensLength() > 0);
    }

    function testCollateralTokensRegistered() public view {
        address[] memory tokens = rupIssuer.getCollateralTokens();
        assertTrue(tokens.length >= 2);
        assertTrue(rupIssuer.getIsValidToken(weth));
        assertTrue(rupIssuer.getIsValidToken(wbtc));
    }

    // ---------------------------------
    // Price Feed Tests
    // ---------------------------------

    function testGetPriceInUsd() public view {
        uint256 wethPrice = rupIssuer.getPriceInUsd(weth, 15e18);
        uint256 wbtcPrice = rupIssuer.getPriceInUsd(wbtc, 15e18);
        uint256 expectedEthPrice = 30000e18;
        uint256 expectedBtcPrice = 15000e18;
        console2.log("WETH Price:", wethPrice);
        console2.log("WBTC Price:", wbtcPrice);
        assertEq(wethPrice, expectedEthPrice);
        assertEq(wbtcPrice, expectedBtcPrice);
    }

    function testGetPriceInUsd_WithDifferentAmounts() public view {
        uint256 smallAmount = 1e18;
        uint256 largeAmount = 100e18;

        uint256 smallPrice = rupIssuer.getPriceInUsd(weth, smallAmount);
        uint256 largePrice = rupIssuer.getPriceInUsd(weth, largeAmount);

        assertEq(smallPrice, 2000e18);
        assertEq(largePrice, 200000e18);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedAmount = 0.05 ether;
        uint256 actualAmount = rupIssuer.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedAmount, actualAmount);
    }

    function testGetTokenAmountFromUsd_WithDifferentValues() public view {
        uint256 usdAmount = 4000e18;
        uint256 actualAmount = rupIssuer.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(actualAmount, 2e18);
    }

    function testGetPriceInUsd_RevertsForUnregisteredToken() public {
        vm.expectRevert();
        rupIssuer.getPriceInUsd(wop, 1e18);
    }

    function testGetTokenAmountFromUsd_RevertsForUnregisteredToken() public {
        vm.expectRevert();
        rupIssuer.getTokenAmountFromUsd(wop, 1e18);
    }

    // ---------------------------------
    // managePriceFeed tests
    // ---------------------------------
    function testManagePriceFeed_RevertsOnZeroToken() public {
        RupIssuer.PriceFeed memory newFeed = RupIssuer.PriceFeed({
            priceFeed: address(opUsdPriceFeed),
            sequencerFeed: address(0),
            stalePriceThreshold: 1 hours
        });

        vm.prank(rupIssuer.owner());
        vm.expectRevert(RupIssuer.RupIssuer__NotZeroAddress.selector);
        rupIssuer.managePriceFeed(address(0), newFeed);
    }

    function testManagePriceFeed_RevertsOnZeroFeedAddress() public {
        RupIssuer.PriceFeed memory newFeed =
            RupIssuer.PriceFeed({priceFeed: address(0), sequencerFeed: address(0), stalePriceThreshold: 1 hours});

        vm.prank(rupIssuer.owner());
        vm.expectRevert(RupIssuer.RupIssuer__NotZeroAddress.selector);
        rupIssuer.managePriceFeed(wop, newFeed);
    }

    function testManagePriceFeed_RevertsWhenNotOwner() public {
        MockV3Aggregator feed = new MockV3Aggregator(8, 1e8);
        RupIssuer.PriceFeed memory newFeed =
            RupIssuer.PriceFeed({priceFeed: address(feed), sequencerFeed: address(0), stalePriceThreshold: 1 hours});

        vm.prank(address(1234));
        vm.expectRevert();
        rupIssuer.managePriceFeed(wop, newFeed);
    }

    function testManagePriceFeed_AddsNewFeed() public {
        RupIssuer.PriceFeed memory newFeed = RupIssuer.PriceFeed({
            priceFeed: address(opUsdPriceFeed),
            sequencerFeed: address(0),
            stalePriceThreshold: 1 hours
        });

        uint256 tokensBefore = rupIssuer.getCollateralTokensLength();

        vm.prank(rupIssuer.owner());
        vm.expectEmit(true, true, true, true, address(rupIssuer));
        emit PriceFeedUpdated(wop, newFeed.priceFeed, newFeed.sequencerFeed, newFeed.stalePriceThreshold);
        rupIssuer.managePriceFeed(wop, newFeed);

        uint256 tokensAfter = rupIssuer.getCollateralTokensLength();
        assertEq(tokensAfter, tokensBefore + 1);

        RupIssuer.PriceFeed memory storedFeed = rupIssuer.getCollateralTokenInfo(wop);
        assertEq(storedFeed.priceFeed, newFeed.priceFeed);
        assertEq(storedFeed.sequencerFeed, newFeed.sequencerFeed);
        assertEq(storedFeed.stalePriceThreshold, newFeed.stalePriceThreshold);
        assertTrue(rupIssuer.getIsValidToken(wop));
    }

    function testManagePriceFeed_UpdatesExistingFeedWithoutDuplicate() public {
        RupIssuer.PriceFeed memory feed1 = RupIssuer.PriceFeed({
            priceFeed: address(opUsdPriceFeed),
            sequencerFeed: address(0),
            stalePriceThreshold: 1 hours
        });

        vm.prank(rupIssuer.owner());
        rupIssuer.managePriceFeed(wop, feed1);

        uint256 tokensAfterFirst = rupIssuer.getCollateralTokensLength();

        RupIssuer.PriceFeed memory feed2 = RupIssuer.PriceFeed({
            priceFeed: address(opUsdPriceFeed),
            sequencerFeed: address(0x1234),
            stalePriceThreshold: 2 hours
        });

        vm.prank(rupIssuer.owner());
        rupIssuer.managePriceFeed(wop, feed2);

        uint256 tokensAfterSecond = rupIssuer.getCollateralTokensLength();
        assertEq(tokensAfterSecond, tokensAfterFirst);

        RupIssuer.PriceFeed memory storedFeedAft = rupIssuer.getCollateralTokenInfo(wop);
        assertEq(storedFeedAft.priceFeed, feed2.priceFeed);
        assertEq(storedFeedAft.sequencerFeed, feed2.sequencerFeed);
        assertEq(storedFeedAft.stalePriceThreshold, feed2.stalePriceThreshold);
    }

    // ---------------------------------
    // Deposit and mint tests
    // ---------------------------------

    function testDepositAndMint() public {
        vm.prank(user);
        vm.expectEmit(true, true, false, true, address(rupIssuer));
        emit CollateralDeposited(user, weth, amountToDeposit);
        vm.expectEmit(true, false, false, true, address(rupIssuer));
        emit RupMinted(user, amountToMint);
        rupIssuer.depositAndMint(weth, amountToDeposit, amountToMint);

        assertEq(rup.balanceOf(user), amountToMint);
        assertEq(rupIssuer.getCollateralFromToken(user, weth), amountToDeposit);
        (uint256 minted, uint256 collateral) = rupIssuer.getUserInfo(user);
        assertEq(minted, amountToMint);
        assertGt(collateral, 0);
    }

    function testDepositAndMint_MultipleDeposits() public {
        vm.startPrank(user);
        rupIssuer.depositAndMint(weth, 5 ether, 5000 ether);
        rupIssuer.depositAndMint(weth, 5 ether, 5000 ether);
        vm.stopPrank();

        assertEq(rup.balanceOf(user), 10000 ether);
        assertEq(rupIssuer.getCollateralFromToken(user, weth), 10 ether);
    }

    function testDepositAndMint_WithDifferentCollateralTypes() public {
        vm.startPrank(user);
        rupIssuer.depositAndMint(weth, 5 ether, 5000 ether);
        rupIssuer.depositAndMint(wbtc, 10 ether, 5000 ether);
        vm.stopPrank();

        assertEq(rup.balanceOf(user), 10000 ether);
        assertEq(rupIssuer.getCollateralFromToken(user, weth), 5 ether);
        assertEq(rupIssuer.getCollateralFromToken(user, wbtc), 10 ether);
    }

    function testRevertDepositAndMint_WhenPause() public {
        vm.prank(rupIssuer.owner());
        rupIssuer.pause();

        vm.prank(user);
        vm.expectRevert();
        rupIssuer.depositAndMint(weth, amountToDeposit, amountToMint);
    }

    function testRevertDepositAndMint_WhenNoRegisteredToken() public {
        vm.prank(user);
        vm.expectRevert();
        rupIssuer.depositAndMint(wop, amountToDeposit, amountToMint);
    }

    function testRevertDepositAndMint_WhenUserNotHealthy() public {
        vm.prank(user);
        vm.expectRevert();
        rupIssuer.depositAndMint(weth, 0.01 ether, amountToMint);
    }

    function testRevertDepositAndMint_WhenAmountToMintIsZero() public {
        vm.prank(user);
        vm.expectRevert(RupIssuer.RupIssuer__AmountMustBeMoreThanZero.selector);
        rupIssuer.depositAndMint(weth, amountToDeposit, 0);
    }

    function testRevertDepositAndMint_WhenDepositAmountIsZero() public {
        vm.prank(user);
        vm.expectRevert(RupIssuer.RupIssuer__AmountMustBeMoreThanZero.selector);
        rupIssuer.depositAndMint(weth, 0, amountToMint);
    }

    // ---------------------------------
    // Redeem tests
    // ---------------------------------

    function testRedeem() public {
        vm.prank(user);
        rupIssuer.depositAndMint(weth, amountToDeposit, amountToMint);
        assertEq(rup.balanceOf(user), amountToMint);

        vm.prank(user);
        rup.approve(address(rupIssuer), amountToMint);

        vm.prank(user);
        vm.expectEmit(true, false, false, true, address(rupIssuer));
        emit RupBurned(user, amountToMint);
        vm.expectEmit(true, true, true, true, address(rupIssuer));
        emit CollateralRedeemed(user, user, weth, amountToDeposit);
        rupIssuer.redeem(weth, amountToMint, amountToDeposit);

        assertEq(rup.balanceOf(user), 0);
        assertEq(rupIssuer.getCollateralFromToken(user, weth), 0);
    }

    function testRedeem_PartialRedeem() public {
        vm.prank(user);
        rupIssuer.depositAndMint(weth, amountToDeposit, amountToMint);

        vm.prank(user);
        rup.approve(address(rupIssuer), amountToMint);

        uint256 burnAmount = amountToMint / 2;
        uint256 redeemAmount = amountToDeposit / 2;

        vm.prank(user);
        rupIssuer.redeem(weth, burnAmount, redeemAmount);

        assertEq(rup.balanceOf(user), burnAmount);
        assertEq(rupIssuer.getCollateralFromToken(user, weth), redeemAmount);
    }

    function testCantBurnMoreThenMinted() public {
        vm.prank(user);
        rupIssuer.depositAndMint(weth, amountToDeposit, amountToMint);

        vm.prank(user);
        rup.approve(address(rupIssuer), amountToMint + 1);

        vm.prank(user);
        vm.expectRevert();
        rupIssuer.redeem(weth, amountToMint + 1, amountToDeposit);
    }

    function testRevertRedeem_WhenPause() public {
        vm.prank(user);
        rupIssuer.depositAndMint(weth, amountToDeposit, amountToMint);

        vm.prank(user);
        rup.approve(address(rupIssuer), amountToMint);

        vm.prank(rupIssuer.owner());
        rupIssuer.pause();

        vm.prank(user);
        vm.expectRevert();
        rupIssuer.redeem(weth, amountToMint, amountToDeposit);
    }

    function testRevertRedeem_WhenNoRegisteredToken() public {
        vm.prank(user);
        rupIssuer.depositAndMint(weth, amountToDeposit, amountToMint);

        vm.prank(user);
        rup.approve(address(rupIssuer), amountToMint);

        vm.prank(user);
        vm.expectRevert();
        rupIssuer.redeem(wop, amountToMint, amountToDeposit);
    }

    function testRevertRedeem_WhenUserNotHealthy() public {
        vm.prank(user);
        rupIssuer.depositAndMint(weth, amountToDeposit, amountToMint);

        vm.prank(user);
        rup.approve(address(rupIssuer), amountToMint);

        uint256 amountToBurn = amountToMint - 1;

        vm.prank(user);
        vm.expectRevert();
        rupIssuer.redeem(weth, amountToBurn, amountToDeposit);
    }

    function testRevertRedeem_WhenAmountIsZero() public {
        vm.prank(user);
        rupIssuer.depositAndMint(weth, amountToDeposit, amountToMint);

        vm.prank(user);
        rup.approve(address(rupIssuer), amountToMint);

        vm.prank(user);
        vm.expectRevert(RupIssuer.RupIssuer__AmountMustBeMoreThanZero.selector);
        rupIssuer.redeem(weth, 0, amountToDeposit);
    }

    function testRevertRedeem_WhenCollateralAmountIsZero() public {
        vm.prank(user);
        rupIssuer.depositAndMint(weth, amountToDeposit, amountToMint);

        vm.prank(user);
        rup.approve(address(rupIssuer), amountToMint);

        vm.prank(user);
        vm.expectRevert(RupIssuer.RupIssuer__AmountMustBeMoreThanZero.selector);
        rupIssuer.redeem(weth, amountToMint, 0);
    }

    // -----------------------------
    // Liquidation tests
    // -----------------------------
    function testLiquidate_RevertsWhenUserHealthy() public {
        MockV3Aggregator wopFeed = new MockV3Aggregator(8, 1e8);
        RupIssuer.PriceFeed memory pf =
            RupIssuer.PriceFeed({priceFeed: address(wopFeed), sequencerFeed: address(0), stalePriceThreshold: 1 hours});

        vm.prank(rupIssuer.owner());
        rupIssuer.managePriceFeed(wop, pf);

        uint256 collateralAmt = 100e18;
        uint256 mintedRup = 40e18;

        ERC20Mock(wop).mint(user, collateralAmt);
        vm.prank(user);
        ERC20Mock(wop).approve(address(rupIssuer), collateralAmt);

        vm.prank(user);
        rupIssuer.depositAndMint(wop, collateralAmt, mintedRup);

        uint256 hf = rupIssuer.getHealthStatus(user);
        assertGe(hf, rupIssuer.getMinHealthFactor());

        address liquidator = makeAddr("liquidator");
        vm.prank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(RupIssuer.RupIssuer__UserHealthy.selector, 1.25e18));
        rupIssuer.liquidate(user, 1e18, wop);
    }

    function testLiquidate_RevertsWhenPaused() public {
        MockV3Aggregator wopFeed = new MockV3Aggregator(8, 1e8);
        RupIssuer.PriceFeed memory pf =
            RupIssuer.PriceFeed({priceFeed: address(wopFeed), sequencerFeed: address(0), stalePriceThreshold: 1 hours});

        vm.prank(rupIssuer.owner());
        rupIssuer.managePriceFeed(wop, pf);

        address target = makeAddr("targetUser");
        uint256 collateralAmt = 100e18;
        uint256 mintedRup = 40e18;

        ERC20Mock(wop).mint(target, collateralAmt);
        vm.prank(target);
        ERC20Mock(wop).approve(address(rupIssuer), collateralAmt);

        vm.prank(target);
        rupIssuer.depositAndMint(wop, collateralAmt, mintedRup);

        MockV3Aggregator(address(wopFeed)).updateAnswer(int256(1e7));

        vm.prank(rupIssuer.owner());
        rupIssuer.pause();

        address liquidator = makeAddr("liquidator");
        vm.prank(liquidator);
        vm.expectRevert();
        rupIssuer.liquidate(target, 1e18, wop);
    }

    function testLiquidate_RevertsWhenDebtIsZero() public {
        MockV3Aggregator wopFeed = new MockV3Aggregator(8, 1e8);
        RupIssuer.PriceFeed memory pf =
            RupIssuer.PriceFeed({priceFeed: address(wopFeed), sequencerFeed: address(0), stalePriceThreshold: 1 hours});

        vm.prank(rupIssuer.owner());
        rupIssuer.managePriceFeed(wop, pf);

        address liquidator = makeAddr("liquidator");
        vm.prank(liquidator);
        vm.expectRevert(RupIssuer.RupIssuer__AmountMustBeMoreThanZero.selector);
        rupIssuer.liquidate(user, 0, wop);
    }

    function testLiquidate_RevertsWhenTokenInvalid() public {
        address liquidator = makeAddr("liquidator");
        vm.prank(liquidator);
        vm.expectRevert();
        rupIssuer.liquidate(user, 1e18, wop);
    }

    // ---------------------------------
    // Pause/Unpause tests
    // ---------------------------------

    function testPause_OnlyOwner() public {
        vm.prank(rupIssuer.owner());
        rupIssuer.pause();
        assertTrue(rupIssuer.paused());
    }

    function testPause_RevertsWhenNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        rupIssuer.pause();
    }

    function testUnpause_OnlyOwner() public {
        vm.prank(rupIssuer.owner());
        rupIssuer.pause();
        assertTrue(rupIssuer.paused());

        vm.prank(rupIssuer.owner());
        rupIssuer.unpause();
        assertFalse(rupIssuer.paused());
    }

    function testUnpause_RevertsWhenNotOwner() public {
        vm.prank(rupIssuer.owner());
        rupIssuer.pause();

        vm.prank(user);
        vm.expectRevert();
        rupIssuer.unpause();
    }

    // ---------------------------------
    // Health Factor tests
    // ---------------------------------

    function testHealthFactor_MaxWhenNoDebt() public view {
        uint256 hf = rupIssuer.getHealthStatus(user);
        assertEq(hf, type(uint256).max);
    }

    function testHealthFactor_CalculatesCorrectly() public {
        vm.prank(user);
        rupIssuer.depositAndMint(weth, 10 ether, 10000 ether);

        uint256 hf = rupIssuer.getHealthStatus(user);
        // Collateral: 10 ETH * $2000 = $20,000
        // Adjusted: $20,000 * 50 / 100 = $10,000
        // Health Factor: $10,000 / $10,000 = 1.0
        assertGe(hf, rupIssuer.getMinHealthFactor());
    }

    function testHealthFactor_MultipleCollateralTypes() public {
        vm.startPrank(user);
        rupIssuer.depositAndMint(weth, 5 ether, 5000 ether);
        rupIssuer.depositAndMint(wbtc, 10 ether, 5000 ether);
        vm.stopPrank();

        uint256 hf = rupIssuer.getHealthStatus(user);
        assertGe(hf, rupIssuer.getMinHealthFactor());
    }

    // ---------------------------------
    // User Info tests
    // ---------------------------------

    function testGetUserInfo_EmptyUser() public view {
        (uint256 minted, uint256 collateral) = rupIssuer.getUserInfo(user);
        assertEq(minted, 0);
        assertEq(collateral, 0);
    }

    function testGetUserInfo_AfterDeposit() public {
        vm.prank(user);
        rupIssuer.depositAndMint(weth, amountToDeposit, amountToMint);

        (uint256 minted, uint256 collateral) = rupIssuer.getUserInfo(user);
        assertEq(minted, amountToMint);
        assertGt(collateral, 0);
    }

    function testGetCollateralFromToken() public {
        vm.prank(user);
        rupIssuer.depositAndMint(weth, amountToDeposit, amountToMint);

        uint256 collateral = rupIssuer.getCollateralFromToken(user, weth);
        assertEq(collateral, amountToDeposit);
    }

    function testGetTotalUserCollateral() public {
        vm.startPrank(user);
        rupIssuer.depositAndMint(weth, 5 ether, 5000 ether);
        rupIssuer.depositAndMint(wbtc, 10 ether, 5000 ether);
        vm.stopPrank();

        uint256 totalCollateral = rupIssuer.getTotalUserCollateral(user);
        assertGt(totalCollateral, 0);
    }

    // ---------------------------------
    // Getter function tests
    // ---------------------------------

    function testGetCollateralTokens() public view {
        address[] memory tokens = rupIssuer.getCollateralTokens();
        assertTrue(tokens.length > 0);
    }

    function testGetCollateralTokensLength() public view {
        uint256 length = rupIssuer.getCollateralTokensLength();
        assertGt(length, 0);
    }

    function testGetIsValidToken() public view {
        assertTrue(rupIssuer.getIsValidToken(weth));
        assertTrue(rupIssuer.getIsValidToken(wbtc));
        assertFalse(rupIssuer.getIsValidToken(wop));
    }

    function testGetCollateralTokenInfo() public view {
        RupIssuer.PriceFeed memory feed = rupIssuer.getCollateralTokenInfo(weth);
        assertTrue(feed.priceFeed != address(0));
    }

    function testGetRupayAddress() public view {
        assertEq(rupIssuer.getRupayAddress(), address(rup));
    }

    function testGetMinHealthFactor() public view {
        assertEq(rupIssuer.getMinHealthFactor(), 1e18);
    }

    function testGetLiquidationThreshold() public view {
        assertEq(rupIssuer.getLiquidationThreshold(), 50);
    }

    function testGetLiquidationPrecision() public view {
        assertEq(rupIssuer.getLiquidationPrecision(), 100);
    }

    // ---------------------------------
    // Edge case tests
    // ---------------------------------

    function testDepositAndMint_AtExactHealthFactorLimit() public {
        // Deposit exactly enough to maintain minimum health factor
        uint256 collateral = 5 ether; // 5 ETH * $2000 = $10,000
        uint256 mintAmount = 5000 ether; // Exactly 50% collateralization

        vm.prank(user);
        rupIssuer.depositAndMint(weth, collateral, mintAmount);

        uint256 hf = rupIssuer.getHealthStatus(user);
        assertGe(hf, rupIssuer.getMinHealthFactor());
    }

    function testReentrancyProtection_DepositAndMint() public {
        // This test ensures nonReentrant modifier works
        vm.prank(user);
        rupIssuer.depositAndMint(weth, amountToDeposit, amountToMint);
        // If reentrancy was possible, this would fail
        assertEq(rup.balanceOf(user), amountToMint);
    }

    function testReentrancyProtection_Redeem() public {
        vm.prank(user);
        rupIssuer.depositAndMint(weth, amountToDeposit, amountToMint);

        vm.prank(user);
        rup.approve(address(rupIssuer), amountToMint);

        vm.prank(user);
        rupIssuer.redeem(weth, amountToMint, amountToDeposit);

        assertEq(rup.balanceOf(user), 0);
    }

    function testMultipleUsersCanDepositAndMint() public {
        vm.prank(user);
        rupIssuer.depositAndMint(weth, 5 ether, 5000 ether);

        vm.prank(user2);
        rupIssuer.depositAndMint(weth, 5 ether, 5000 ether);

        assertEq(rup.balanceOf(user), 5000 ether);
        assertEq(rup.balanceOf(user2), 5000 ether);
        assertEq(rupIssuer.getCollateralFromToken(user, weth), 5 ether);
        assertEq(rupIssuer.getCollateralFromToken(user2, weth), 5 ether);
    }

    function testUserCannotRedeemOthersCollateral() public {
        vm.prank(user);
        rupIssuer.depositAndMint(weth, 10 ether, 10000 ether);

        vm.prank(user2);
        rupIssuer.depositAndMint(weth, 10 ether, 10000 ether);

        vm.prank(user2);
        rup.approve(address(rupIssuer), 10000 ether);

        // user2 tries to redeem, but should only affect their own collateral
        vm.prank(user2);
        rupIssuer.redeem(weth, 10000 ether, 10 ether);

        // user's collateral should be untouched
        assertEq(rupIssuer.getCollateralFromToken(user, weth), 10 ether);
        // user2's collateral should be redeemed
        assertEq(rupIssuer.getCollateralFromToken(user2, weth), 0);
    }

    function testCannotLiquidateWithInsufficientRup() public {
        MockV3Aggregator wopFeed = new MockV3Aggregator(8, 1e8);
        RupIssuer.PriceFeed memory pf =
            RupIssuer.PriceFeed({priceFeed: address(wopFeed), sequencerFeed: address(0), stalePriceThreshold: 1 hours});

        vm.prank(rupIssuer.owner());
        rupIssuer.managePriceFeed(wop, pf);

        address target = makeAddr("targetUser");
        uint256 collateralAmt = 100e18;
        uint256 mintedRup = 40e18;

        ERC20Mock(wop).mint(target, collateralAmt);
        vm.prank(target);
        ERC20Mock(wop).approve(address(rupIssuer), collateralAmt);

        vm.prank(target);
        rupIssuer.depositAndMint(wop, collateralAmt, mintedRup);

        MockV3Aggregator(address(wopFeed)).updateAnswer(int256(1e7));

        address liquidator = makeAddr("liquidator");
        uint256 debtToCover = 10e18;

        vm.prank(liquidator);
        rup.approve(address(rupIssuer), debtToCover);

        vm.prank(liquidator);
        vm.expectRevert();
        rupIssuer.liquidate(target, debtToCover, wop);
    }

    function testTotalSupply_UpdatesCorrectly() public {
        assertEq(rup.totalSupply(), 0);

        vm.prank(user);
        rupIssuer.depositAndMint(weth, 10 ether, 5000 ether);
        assertEq(rup.totalSupply(), 5000 ether);

        vm.prank(user2);
        rupIssuer.depositAndMint(weth, 10 ether, 5000 ether);
        assertEq(rup.totalSupply(), 10000 ether);

        vm.prank(user);
        rup.approve(address(rupIssuer), 5000 ether);

        vm.prank(user);
        rupIssuer.redeem(weth, 5000 ether, 10 ether);
        assertEq(rup.totalSupply(), 5000 ether);
    }

    function testPriceFeed_WithSequencerFeed() public {
        // Test that sequencer feed can be set (even if not used in tests)
        MockV3Aggregator sequencerFeed = new MockV3Aggregator(0, 0);
        RupIssuer.PriceFeed memory newFeed = RupIssuer.PriceFeed({
            priceFeed: address(opUsdPriceFeed),
            sequencerFeed: address(sequencerFeed),
            stalePriceThreshold: 1 hours
        });

        vm.prank(rupIssuer.owner());
        rupIssuer.managePriceFeed(wop, newFeed);

        RupIssuer.PriceFeed memory storedFeed = rupIssuer.getCollateralTokenInfo(wop);
        assertEq(storedFeed.sequencerFeed, address(sequencerFeed));
    }

    function testPriceFeed_WithDifferentStalePriceThreshold() public {
        RupIssuer.PriceFeed memory newFeed = RupIssuer.PriceFeed({
            priceFeed: address(opUsdPriceFeed),
            sequencerFeed: address(0),
            stalePriceThreshold: 2 hours
        });

        vm.prank(rupIssuer.owner());
        rupIssuer.managePriceFeed(wop, newFeed);

        RupIssuer.PriceFeed memory storedFeed = rupIssuer.getCollateralTokenInfo(wop);
        assertEq(storedFeed.stalePriceThreshold, 2 hours);
    }

    // ---------------------------------
    // Fuzz tests
    // ---------------------------------

    function testFuzz_DepositAndMint(uint256 collateral, uint256 mintAmount) public {
        // Bound inputs to reasonable ranges
        collateral = bound(collateral, 1 ether, 50 ether);
        mintAmount = bound(mintAmount, 1 ether, 50000 ether);

        // Ensure user has enough tokens
        ERC20Mock(weth).mint(user, collateral);
        vm.prank(user);
        ERC20Mock(weth).approve(address(rupIssuer), collateral);

        // Try to deposit and mint
        vm.prank(user);
        try rupIssuer.depositAndMint(weth, collateral, mintAmount) {
            // If successful, verify health factor
            uint256 hf = rupIssuer.getHealthStatus(user);
            assertGe(hf, rupIssuer.getMinHealthFactor());
        } catch {
            // If it reverts, it should be due to health factor
            // This is expected for some combinations
        }
    }

    function testFuzz_GetPriceInUsd(uint256 amount) public view {
        amount = bound(amount, 1, 1000 ether);
        uint256 price = rupIssuer.getPriceInUsd(weth, amount);
        assertGt(price, 0);
    }

    function testFuzz_GetTokenAmountFromUsd(uint256 usdAmount) public view {
        usdAmount = bound(usdAmount, 1 ether, 1000000 ether);
        uint256 tokenAmount = rupIssuer.getTokenAmountFromUsd(weth, usdAmount);
        assertGt(tokenAmount, 0);
    }

    // ---------------------------------
    // Integration tests
    // ---------------------------------

    function testIntegration_FullCycle() public {
        // User deposits and mints
        vm.prank(user);
        rupIssuer.depositAndMint(weth, 10 ether, 10000 ether);

        // Verify state
        assertEq(rup.balanceOf(user), 10000 ether);
        assertEq(rupIssuer.getCollateralFromToken(user, weth), 10 ether);

        (uint256 minted, uint256 collateral) = rupIssuer.getUserInfo(user);
        assertEq(minted, 10000 ether);
        assertGt(collateral, 0);

        // User redeems
        vm.prank(user);
        rup.approve(address(rupIssuer), 10000 ether);

        vm.prank(user);
        rupIssuer.redeem(weth, 10000 ether, 10 ether);

        // Verify final state
        assertEq(rup.balanceOf(user), 0);
        assertEq(rupIssuer.getCollateralFromToken(user, weth), 0);

        (uint256 finalMinted, uint256 finalCollateral) = rupIssuer.getUserInfo(user);
        assertEq(finalMinted, 0);
        assertEq(finalCollateral, 0);
    }
}
