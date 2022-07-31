// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "../libraries/PositionValue.sol";
import "../interfaces/IPriceHelper.sol";
import "../interfaces/IAggregatorV3Interface.sol";

/// @title NFT USD Price helper
contract UniLPPriceHelper is IPriceHelper {
    IAggregatorV3Interface public token0Aggregator;
    IAggregatorV3Interface public token1Aggregator;
    INonfungiblePositionManager public nft;
    IUniswapV3Pool public pool;

    /// @dev Checks if the provided NFT index is valid
    /// @param nftIndex The index to check
    modifier validNFTIndex(address nftContract, uint256 nftIndex) {
        //The standard OZ ERC721 implementation of ownerOf reverts on a non existing nft isntead of returning address(0)
        require(INonfungiblePositionManager(nftContract).ownerOf(nftIndex) != address(0), "invalid_nft");
        _;
    }

    constructor(
        IAggregatorV3Interface _token0Aggregator,
        IAggregatorV3Interface _token1Aggregator,
        INonfungiblePositionManager _nft,
        IUniswapV3Pool _pool
    ) {
        token0Aggregator = _token0Aggregator;
        token1Aggregator = _token1Aggregator;
        nft = _nft;
        pool = _pool;
    }

    /// @dev Returns the value in USD of the NFT at index `_nftIndex`
    /// @param _nftIndex The NFT to return the value of
    /// @return The value of the NFT in USD, 18 decimals
    function getNFTValueUSD(address _nftContract, uint256 _nftIndex)
        public
        view
        override
        validNFTIndex(_nftContract, _nftIndex)
        returns (uint256)
    {
        require(_nftContract == address(nft));
        pool.slot0();
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        (uint amount0, uint amount1) = PositionValue.total(address(pool),nft, _nftIndex, sqrtRatioX96);
        return amount0 * tokenPrice(token0Aggregator) + amount1 * tokenPrice(token1Aggregator);
    }

    /// @dev Returns the current ETH price in USD
    /// @return The current ETH price, 18 decimals
    function tokenPrice(IAggregatorV3Interface aggregator) public view returns (uint256) {
        return _normalizeAggregatorAnswer(aggregator);
    }

    /// @dev Fetches and converts to 18 decimals precision the latest answer of a Chainlink aggregator
    /// @param aggregator The aggregator to fetch the answer from
    /// @return The latest aggregator answer, normalized
    function _normalizeAggregatorAnswer(IAggregatorV3Interface aggregator) internal view returns (uint256) {
        (, int256 answer, , uint256 timestamp, ) = aggregator.latestRoundData();

        require(answer > 0, "invalid_oracle_answer");
        require(timestamp != 0, "round_incomplete");

        uint8 decimals = aggregator.decimals();

        unchecked {
            //converts the answer to have 18 decimals
            return decimals > 18 ? uint256(answer) / 10**(decimals - 18) : uint256(answer) * 10**(18 - decimals);
        }
    }
}
