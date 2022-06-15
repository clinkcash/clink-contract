// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// @title Ftn
contract Fontana is ERC20Permit, Ownable {

    uint256 public constant MAX_SUPPLY = 10 * 1e27;

    constructor() payable ERC20("Fontana token", "FTN") ERC20Permit("Fontana token") {
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(MAX_SUPPLY >= (totalSupply() + amount), "FTN: Don't go over MAX");
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}
