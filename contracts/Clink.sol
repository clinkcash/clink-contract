// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/ERC20.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";

// @title Clink
contract Clink is ERC20, BoringOwnable {
    using BoringMath for uint256;
    string public constant symbol = "CLK";
    string public constant name = "Clink stable coin";
    uint8 public constant decimals = 18;
    uint256 public override totalSupply;

    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0), "CLK: no mint to zero address");
        totalSupply = totalSupply + amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) public {
        require(amount <= balanceOf[msg.sender], "CLK: not enough");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}
