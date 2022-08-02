// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
import "../interfaces/IAggregatorV3Interface.sol";

contract AggregatorV3Mock is IAggregatorV3Interface {
    function decimals() external pure override returns (uint8) {
        return 6;
    }

    function latestRoundData()
        external
        pure
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = 1;
        answer = 2000000000;
        startedAt = 1;
        updatedAt = 1;
        answeredInRound = 1;
    }
}
