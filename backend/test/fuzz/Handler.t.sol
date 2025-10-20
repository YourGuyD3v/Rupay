// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console2} from "forge-std/Test.sol";
import {RupIssuer} from "../../src/RupIssuer.sol";
import {Rupay} from "../../src/Rupay.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract Handler is Test {
    RupIssuer rupIssuer;
    Rupay rup;
    IERC20 weth;
    IERC20 wbtc;

    uint256 public timesMintCalled;
    uint256 public timesDepositCalled;
    uint256 public timesRedeemCalled;

    uint256 constant MAX_DEPOSIT = type(uint96).max;
    
    constructor(RupIssuer _rupIssuer, Rupay _rup, address _weth, address _wbtc) {
        rupIssuer = _rupIssuer;
        rup = _rup;
        weth = IERC20(_weth);
        wbtc = IERC20(_wbtc);
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        address collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT);

        vm.startPrank(msg.sender);
        
        // Mint the specific collateral token to the user
        ERC20Mock(collateral).mint(msg.sender, amountCollateral);
        
        // Approve RupIssuer to spend the collateral tokens
        ERC20Mock(collateral).approve(address(rupIssuer), amountCollateral);
        
        // Deposit collateral without minting RUP
        rupIssuer.depositAndMint(collateral, amountCollateral, 0);
        timesDepositCalled++;
        
        vm.stopPrank();
    }

    function mintRup(uint256 amountToMint) public {
        (uint256 totalRupMinted, uint256 totalCollateral) = rupIssuer.getUserInfo(msg.sender);
        
        // User needs collateral first
        if (totalCollateral == 0) return;
        
        // Calculate max RUP that can be minted (50% of collateral value for 200% collateralization)
        uint256 maxRupToMint = (totalCollateral * 50) / 100;
        
        // If already minted too much, can't mint more
        if (maxRupToMint <= totalRupMinted) return;
        
        uint256 availableToMint = maxRupToMint - totalRupMinted;
        
        if (availableToMint == 0) return;
        
        amountToMint = bound(amountToMint, 1, availableToMint);
        
        vm.startPrank(msg.sender);
        
        // Mint RUP without depositing more collateral
        rupIssuer.depositAndMint(address(weth), 0, amountToMint);
        timesMintCalled++;
        
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        address collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateral = rupIssuer.getCollateralFromToken(msg.sender, collateral);
        
        if (maxCollateral == 0) return;
        
        amountCollateral = bound(amountCollateral, 1, maxCollateral);

        vm.startPrank(msg.sender);
        
        // Try to redeem without burning (might fail due to health factor)
        try rupIssuer.redeem(collateral, 0, amountCollateral) {
            timesRedeemCalled++;
        } catch {
            // If redeem fails due to health factor, just continue
        }
        
        vm.stopPrank();
    }

    function depositAndMintRup(uint256 collateralSeed, uint256 amountCollateral, uint256 amountToMint) public {
        address collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT);
        
        vm.startPrank(msg.sender);
        
        // Mint tokens to sender
        ERC20Mock(collateral).mint(msg.sender, amountCollateral);
        
        // Approve the RupIssuer contract
        ERC20Mock(collateral).approve(address(rupIssuer), amountCollateral);
        
        // Calculate max mintable amount based on collateral (50% of value)
        uint256 collateralValueInUsd = rupIssuer.getPriceInUsd(collateral, amountCollateral);
        uint256 maxMintable = (collateralValueInUsd * 50) / 100;
        
        if (maxMintable == 0) {
            vm.stopPrank();
            return;
        }
        
        amountToMint = bound(amountToMint, 0, maxMintable);
        
        rupIssuer.depositAndMint(collateral, amountCollateral, amountToMint);
        timesDepositCalled++;
        if (amountToMint > 0) {
            timesMintCalled++;
        }
        
        vm.stopPrank();
    }

    function burnAndRedeem(uint256 collateralSeed, uint256 amountToBurn, uint256 amountCollateral) public {
        address collateral = _getCollateralFromSeed(collateralSeed);
        
        (uint256 totalRupMinted,) = rupIssuer.getUserInfo(msg.sender);
        uint256 maxCollateral = rupIssuer.getCollateralFromToken(msg.sender, collateral);
        
        if (totalRupMinted == 0 || maxCollateral == 0) return;
        
        amountToBurn = bound(amountToBurn, 0, totalRupMinted);
        amountCollateral = bound(amountCollateral, 0, maxCollateral);
        
        vm.startPrank(msg.sender);
        
        // Approve RupIssuer to burn RUP tokens
        if (amountToBurn > 0) {
            rup.approve(address(rupIssuer), amountToBurn);
        }
        
        try rupIssuer.redeem(collateral, amountToBurn, amountCollateral) {
            timesRedeemCalled++;
        } catch {
            // If redeem fails, just continue
        }
        
        vm.stopPrank();
    }

    // Helper functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (address) {
        if (collateralSeed % 2 == 0) {
            return address(weth);
        }
        return address(wbtc);
    }
}