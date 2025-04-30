// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title MockERC20
 * @dev A simple ERC20 token that can be minted for testing purposes
 */
contract MockERC20 is ERC20, Ownable {
    constructor(string memory name, string memory symbol, uint256 initialSupply)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`
     * Can only be called by the owner
     */
    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }
}
