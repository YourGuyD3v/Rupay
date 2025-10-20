// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import {Rupay} from "../../src/Rupay.sol";

contract TestRupay is Test {
    Rupay rupay;
    address owner;
    address user1;
    address user2;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.startPrank(owner);
        rupay = new Rupay();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function testInitialOwner() public view {
        assertEq(rupay.owner(), owner, "Owner should be deployer");
    }

    function testTokenMetadata() public view {
        assertEq(rupay.name(), "Rupay");
        assertEq(rupay.symbol(), "RUP");
        assertEq(rupay.decimals(), 18);
    }

    function testInitialSupplyIsZero() public view {
        assertEq(rupay.totalSupply(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                                MINT TESTS
    //////////////////////////////////////////////////////////////*/

    function testMintByOwnerSucceeds() public {
        vm.startPrank(owner);
        bool success = rupay.mint(user1, 1000 ether);
        vm.stopPrank();

        assertTrue(success);
        assertEq(rupay.balanceOf(user1), 1000 ether);
        assertEq(rupay.totalSupply(), 1000 ether);
    }

    function testMintNonOwnerReverts() public {
        vm.expectRevert();
        rupay.mint(user1, 1 ether);
    }

    function testMintToZeroAddressReverts() public {
        vm.startPrank(owner);
        vm.expectRevert(Rupay.Rupay__NotZeroAddress.selector);
        rupay.mint(address(0), 1 ether);
        vm.stopPrank();
    }

    function testMintZeroAmountReverts() public {
        vm.startPrank(owner);
        vm.expectRevert(Rupay.Rupay__AmountMustBeMoreThanZero.selector);
        rupay.mint(user1, 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                BURN TESTS
    //////////////////////////////////////////////////////////////*/

    function testBurnByOwnerSucceeds() public {
        vm.startPrank(owner);
        rupay.mint(owner, 1000 ether);
        rupay.burn(400 ether);
        vm.stopPrank();

        assertEq(rupay.balanceOf(owner), 600 ether);
        assertEq(rupay.totalSupply(), 600 ether);
    }

    function testBurnMoreThanBalanceReverts() public {
        vm.startPrank(owner);
        rupay.mint(owner, 100 ether);
        vm.expectRevert(Rupay.Rupay__BurnAmountExceedsBalance.selector);
        rupay.burn(200 ether);
        vm.stopPrank();
    }

    function testBurnZeroAmountReverts() public {
        vm.startPrank(owner);
        rupay.mint(owner, 100 ether);
        vm.expectRevert(Rupay.Rupay__AmountMustBeMoreThanZero.selector);
        rupay.burn(0);
        vm.stopPrank();
    }

    function testBurnNonOwnerReverts() public {
        vm.startPrank(owner);
        rupay.mint(owner, 100 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert();
        rupay.burn(10 ether);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                BLOCKED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function testBurnFromAlwaysReverts() public {
        vm.expectRevert(Rupay.Rupay__BlockFunction.selector);
        rupay.burnFrom(user1, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                                TRANSFER TESTS
    //////////////////////////////////////////////////////////////*/

    function testTransferBasic() public {
        vm.startPrank(owner);
        rupay.mint(owner, 100 ether);
        rupay.transfer(user1, 40 ether);
        vm.stopPrank();

        assertEq(rupay.balanceOf(user1), 40 ether);
        assertEq(rupay.balanceOf(owner), 60 ether);
    }

    function testTransferToZeroAddressReverts() public {
        vm.startPrank(owner);
        rupay.mint(owner, 100 ether);
        vm.expectRevert(); // standard ERC20 revert
        rupay.transfer(address(0), 10 ether);
        vm.stopPrank();
    }
}
