// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

interface IPriceHelper {
    function getNFTValueUSD(address _nftContract, uint256 _nftIndex) external view returns (uint256);
}
