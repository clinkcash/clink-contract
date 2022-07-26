// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

interface IPriceHelper {
    function getNFTValueUSD(address _nftContract, uint256 _nftIndex)
        external
        view
        returns (uint256);

    function nftTypes(address _nft, uint256 tokenId)
        external
        view
        returns (bytes32);

    function nftValueETH(address _nft, uint256 tokenId)
        external
        view
        returns (uint256);

    function nftTypeValueETH(address _nft, bytes32 nftType)
        external
        view
        returns (uint256);
}
