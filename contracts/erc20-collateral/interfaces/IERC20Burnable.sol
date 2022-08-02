// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Burnable {

    /// @param amount to burn
    function burn(uint256 amount) external;
}
