// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IOracle.sol";


interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

// WARNING: This oracle is only for testing, please use PeggedOracle for a fixed value oracle
contract CSushiOracleMock is IOracle {
    IUniswapV2Pair public constant pair = IUniswapV2Pair(0x49906456ba6C6F0D118f1081DaE7Ee7Fd2312Ef5);

    // Calculates the lastest exchange rate
    function _get() internal view returns (uint256) {
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        return reserve0 * 1e18 / reserve1;
    }

    // Get the latest exchange rate
    /// @inheritdoc IOracle
    function get(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    // Check the last exchange rate without any state changes
    /// @inheritdoc IOracle
    function peek(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    // Check the current spot exchange rate without any state changes
    /// @inheritdoc IOracle
    function peekSpot(bytes calldata data) external view override returns (uint256 rate) {
        (, rate) = peek(data);
    }

    function name(bytes calldata) public view override returns (string memory) {
        return "Test";
    }

    function symbol(bytes calldata) public view override returns (string memory) {
        return "TEST";
    }
}
