// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "../libraries/PositionValue.sol";
import "../interfaces/IPriceHelper.sol";
import "../interfaces/IAggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
/// @title NFT USD Price helper
contract UniLPPriceHelper is Ownable, IPriceHelper {
    mapping(address => IAggregatorV3Interface) public tokenAggregator;
    mapping(address => mapping(address => bool)) public whiteListPair;

    INonfungiblePositionManager public nft;

    /// @dev Checks if the provided NFT index is valid
    /// @param nftIndex The index to check
    modifier validNFTIndex(address nftContract, uint256 nftIndex) {
        require(nftContract == address(nft));
        //The standard OZ ERC721 implementation of ownerOf reverts on a non existing nft isntead of returning address(0)
        require(INonfungiblePositionManager(nftContract).ownerOf(nftIndex) != address(0), "invalid_nft");
        _;
    }

    constructor(INonfungiblePositionManager _nft) {
        nft = _nft;
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
        (, , address token0, address token1, uint24 fee, , , , , , , ) = nft.positions(_nftIndex);
        if (!whiteListPair[token0][token1]) {
            return 0;
        }
        address poolAddr = PoolAddress.computeAddress(
            nft.factory(),
            PoolAddress.PoolKey({token0: token0, token1: token1, fee: fee})
        );
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddr);
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        (uint amount0, uint amount1) = PositionValue.total(poolAddr, nft, _nftIndex, sqrtRatioX96);
        return (amount0 * tokenPrice(tokenAggregator[token0]) + amount1 * tokenPrice(tokenAggregator[token1])) / 1e18;
    }

    function isOpen(address _nftContract, uint256 _nftIndex)
        public
        view
        override
        validNFTIndex(_nftContract, _nftIndex)
        returns (bool)
    {
        (, , address token0, address token1, , , , , , , , ) = nft.positions(_nftIndex);
        return whiteListPair[token0][token1];
    }

    function addTokenAggregator(address token, IAggregatorV3Interface aggregator) public onlyOwner {
        require(address(tokenAggregator[token]) == address(0), "already set");
        tokenAggregator[token] = aggregator;
    }

    function addWhiteList(address token0, address token1) public onlyOwner {
        require(token0 != token1, "token addr err");
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        require(!whiteListPair[token0][token1], "already whitelisted");
        whiteListPair[token0][token1] = true;
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
