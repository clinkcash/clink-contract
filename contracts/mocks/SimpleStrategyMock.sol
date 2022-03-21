// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


// solhint-disable not-rely-on-time

contract SimpleStrategyMock is IStrategy {
    using SafeERC20 for IERC20;

    IERC20 private immutable token;
    address private immutable tokenVault;

    modifier onlyTokenVault() {
        require(msg.sender == tokenVault, "Ownable: caller is not the owner");
        _;
    }

    constructor(address tokenVault_, IERC20 token_) public {
        tokenVault = tokenVault_;
        token = token_;
    }

    // Send the assets to the Strategy and call skim to invest them
    function skim(uint256) external override onlyTokenVault {
        // Leave the tokens on the contract
        return;
    }

    // Harvest any profits made converted to the asset and pass them to the caller
    function harvest(uint256 balance, address) external override onlyTokenVault returns (int256 amountAdded) {
        amountAdded = int256(token.balanceOf(address(this))-balance);
        token.safeTransfer(tokenVault, uint256(amountAdded)); // Add as profit
    }

    // Withdraw assets. The returned amount can differ from the requested amount due to rounding or if the request was more than there is.
    function withdraw(uint256 amount) external override onlyTokenVault returns (uint256 actualAmount) {
        token.safeTransfer(tokenVault, uint256(amount)); // Add as profit
        actualAmount = amount;
    }

    // Withdraw all assets in the safest way possible. This shouldn't fail.
    function exit(uint256 balance) external override onlyTokenVault returns (int256 amountAdded) {
        amountAdded = 0;
        token.safeTransfer(tokenVault, balance);
    }
}
