// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title Rupay
 * @author Shurjeel Khan
 * @notice This is a ERC20 token contract with minting and burning functionalities, controlled by the RupayIssuer (owner).
 */
contract Rupay is ERC20Burnable, Ownable {
    error Rupay__NotZeroAddress();
    error Rupay__AmountMustBeMoreThanZero();
    error Rupay__BurnAmountExceedsBalance();
    error Rupay__BlockFunction();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() ERC20("Rupay", "RUP") Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                            MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     * @return bool Returns true if the operation is successful
     */
    function mint(address to, uint256 amount) public onlyOwner returns (bool) {
        // @audit is there a need to return bool here?
        if (to == address(0)) {
            revert Rupay__NotZeroAddress();
        }

        if (amount <= 0) {
            revert Rupay__AmountMustBeMoreThanZero();
        }
        _mint(to, amount);
        return true;
    }

    /**
     * @param amount The amount of tokens to mint
     */
    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (amount <= 0) {
            revert Rupay__AmountMustBeMoreThanZero();
        }

        if (balance < amount) {
            revert Rupay__BurnAmountExceedsBalance();
        }
        super.burn(amount);
    }

    function burnFrom(address, uint256) public pure override {
        revert Rupay__BlockFunction();
    }
}
