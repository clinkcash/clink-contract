// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/ISwapperGeneric.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/ITokenVault.sol";

interface ICore {
    function oracleData() external returns (bytes calldata data);
}


contract SimpleSwapperMock is ISwapperGeneric {

    IERC20 public clink;
    IERC20 public collateral;
    IOracle public oracle;
    uint256 public EXCHANGE_RATE_PRECISION = 1e18;
    ITokenVault public TOKENVAULT;
    ICore public core;

    constructor(IERC20 _mim, IERC20 _collateral, IOracle _oracle, ITokenVault _tokenVault, ICore _core) {
        clink = _mim;
        collateral = _collateral;
        oracle = _oracle;
        core = _core;
        TOKENVAULT = _tokenVault;
        clink.approve(address(_tokenVault), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        collateral.approve(address(_tokenVault), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    }

    function checkApprove(IERC20 token, uint256 amount) internal {
        if (token.allowance(address(this), address(TOKENVAULT)) < amount) {
            token.approve(address(TOKENVAULT), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        }
    }

    // Swaps to a flexible amount, from an exact input amount
    /// @inheritdoc ISwapperGeneric
    function swap(
        IERC20 from,
        IERC20 to,
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom
    ) public override returns (uint256 extraShare, uint256 shareReturned) {

        (uint256 amountFrom,) = TOKENVAULT.withdraw(IERC20(address(from)), address(this), address(this), 0, shareFrom);

        (bool updated,uint256 rate) = oracle.get(core.oracleData());
        uint256 toAmount;
        if (address(from) == address(clink)) {
            toAmount = amountFrom * rate / EXCHANGE_RATE_PRECISION;
        } else {
            toAmount = amountFrom * EXCHANGE_RATE_PRECISION / rate;
        }
        checkApprove(to, toAmount);
        (, shareReturned) = TOKENVAULT.deposit(to, address(this), recipient, toAmount, 0);
        extraShare = shareReturned - shareToMin;
    }

    // Swaps to an exact amount, from a flexible input amount
    /// @inheritdoc ISwapperGeneric
    function swapExact(
        IERC20,
        IERC20,
        address,
        address,
        uint256,
        uint256
    ) public override returns (uint256 shareUsed, uint256 shareReturned) {
        return (0, 0);
    }
}
