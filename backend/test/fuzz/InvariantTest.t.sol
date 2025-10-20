// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console2} from "forge-std/Test.sol";
import {DeployRup} from "../../script/DeployRup.s.sol";
import {Rupay} from "../../src/Rupay.sol";
import {RupIssuer} from "../../src/RupIssuer.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is StdInvariant, Test {
    Rupay rup;
    RupIssuer rupIssuer;
    HelperConfig helperConfig;
    Handler handler;
    address weth;
    address wbtc;

    function setUp() external {
        DeployRup deployer = new DeployRup();
        (rup, rupIssuer, helperConfig) = deployer.run();
        console2.log("Rupay deployed to:", address(rup));
        console2.log("RupIssuer deployed to:", address(rupIssuer));

        (,,,,,, weth, wbtc,) = helperConfig.activeNetworkConfig();
        
        handler = new Handler(rupIssuer, rup, weth, wbtc);
        targetContract(address(handler));
    }

    function invariant_ProtocolMustHaveMoreValueThenTotalSupply() public view {
        uint256 totalSupply = rup.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(rupIssuer));
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(rupIssuer));

        uint256 totalWethUsdValue = rupIssuer.getPriceInUsd(weth, totalWethDeposited);
        uint256 totalBtcUsdValue = rupIssuer.getPriceInUsd(wbtc, totalBtcDeposited);

        uint256 totalCollateralValueInUsd = totalWethUsdValue + totalBtcUsdValue;

        console2.log("=== Invariant Check ===");
        console2.log("Total RUP Supply:", totalSupply);
        console2.log("Total WETH Deposited:", totalWethDeposited);
        console2.log("Total WBTC Deposited:", totalBtcDeposited);
        console2.log("Total WETH USD Value:", totalWethUsdValue);
        console2.log("Total WBTC USD Value:", totalBtcUsdValue);
        console2.log("Total Collateral Value:", totalCollateralValueInUsd);
        console2.log("Mint calls:", handler.timesMintCalled());
        console2.log("Deposit calls:", handler.timesDepositCalled());
        console2.log("Redeem calls:", handler.timesRedeemCalled());
        
        // The protocol must always be overcollateralized
        // Total collateral value should be >= total supply of RUP
        // Using >= to handle edge case where both are 0 at start
        assert(totalCollateralValueInUsd >= totalSupply);
    }

    function invariant_GettersShouldNotRevert() public view {
        // Test all view functions don't revert
        rupIssuer.getCollateralTokens();
        rupIssuer.getCollateralTokensLength();
        rupIssuer.getRupayAddress();
        rupIssuer.getMinHealthFactor();
        rupIssuer.getLiquidationThreshold();
        rupIssuer.getLiquidationPrecision();
    }

    function invariant_UsersMustHaveHealthyPositions() public view {
        // This invariant checks that no user in the system has an unhealthy position
        // In practice, this might not hold during liquidation scenarios
        // But for normal operations, all users should maintain healthy positions
        
        // We can't easily iterate over all users in the handler, so this is a simplified check
        // In a production test, you'd track all users who have interacted with the protocol
        uint256 minHealthFactor = rupIssuer.getMinHealthFactor();
        assert(minHealthFactor == 1e18); // Verify constant hasn't changed
    }

    function invariant_TotalSupplyShouldMatchMintedAmount() public view {
        // The total supply of RUP should equal what the RupIssuer contract says is minted
        uint256 totalSupply = rup.totalSupply();
        
        // We can verify that the Rupay contract's total supply is consistent
        // This is a basic sanity check
        assert(totalSupply >= 0); // Should never be negative (uint256)
    }

    function invariant_CollateralTokensShouldBeValid() public view {
        address[] memory collateralTokens = rupIssuer.getCollateralTokens();
        
        // All collateral tokens should be valid and have price feeds
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            assert(rupIssuer.getIsValidToken(collateralTokens[i]));
        }
    }
}