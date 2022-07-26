// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";


contract NFTAuction is Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;

    event NewAuction(
        IERC721 indexed nft,
        uint256 indexed index,
        uint256 startTime
    );
    event NewBid(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 bidValue
    );
    event NFTClaimed(
        uint256 indexed auctionId
    );
    event BidWithdrawn(
        uint256 indexed auctionId,
        address indexed account,
        uint256 bidValue
    );
    event JPEGLockAmountChanged(uint256 newLockAmount, uint256 oldLockAmount);
    event LockDurationChanged(uint256 newDuration, uint256 oldDuration);
    event MinimumIncrementRateChanged(
        Rate newIncrementRate,
        Rate oldIncrementRate
    );

    struct Rate {
        uint128 numerator;
        uint128 denominator;
    }

    enum StakeMode {
        CIG,
        JPEG,
        CARD
    }

    struct UserInfo {
        StakeMode stakeMode;
        uint256 stakeArgument; //unused for CIG
        uint256 unlockTime; //unused for CIG
    }

    struct Auction {
        IERC721 nftAddress;
        uint256 nftIndex;
        uint256 startTime;
        uint256 endTime;
        uint256 minBid;
        address highestBidOwner;
        bool ownerClaimed;
        mapping(address => uint256) bids;
    }


    uint256 public lockDuration;
    uint256 public auctionsLength;

    Rate public minIncrementRate;

    mapping(address => UserInfo) public userInfo;
    mapping(address => EnumerableSet.UintSet) internal userAuctions;
    mapping(uint256 => Auction) public auctions;

    constructor(
        uint256 _lockDuration,
        Rate memory _incrementRate
    ) {

        setLockDuration(_lockDuration);
        setMinimumIncrementRate(_incrementRate);
    }

    /// @notice Allows the owner to create a new auction
    /// @param _nft The address of the NFT to sell
    /// @param _idx The index of the NFT to sell
    /// @param _startTime The time at which the auction starts
    /// @param _endTime The time at which the auction ends
    /// @param _minBid The minimum bid value
    function newAuction(
        IERC721 _nft,
        uint256 _idx,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minBid
    ) external onlyOwner {
        require(address(_nft) != address(0), "INVALID_NFT");
        require(_startTime > block.timestamp, "INVALID_START_TIME");
        require(_endTime > _startTime, "INVALID_END_TIME");
        require(_minBid > 0, "INVALID_MIN_BID");

        Auction storage auction = auctions[auctionsLength++];
        auction.nftAddress = _nft;
        auction.nftIndex = _idx;
        auction.startTime = _startTime;
        auction.endTime = _endTime;
        auction.minBid = _minBid;

        _nft.transferFrom(msg.sender, address(this), _idx);

        emit NewAuction(_nft, _idx, _startTime);
    }

    /// @notice Allows users to bid on an auction. In case of multiple bids by the same user,
    /// the actual bid value is the sum of all bids.
    /// @param _auctionIndex The index of the auction to bid on
    function bid(uint256 _auctionIndex) public payable nonReentrant {
        Auction storage auction = auctions[_auctionIndex];

        require(block.timestamp >= auction.startTime, "NOT_STARTED");
        require(block.timestamp < auction.endTime, "ENDED_OR_INVALID");

        uint256 previousBid = auction.bids[msg.sender];
        uint256 totalBid = msg.value + previousBid;
        uint256 currentMinBid = auction.bids[auction.highestBidOwner];
        currentMinBid +=
            (currentMinBid * minIncrementRate.numerator) /
            minIncrementRate.denominator;

        require(
            totalBid >= currentMinBid && totalBid >= auction.minBid,
            "INVALID_BID"
        );

        auction.highestBidOwner = msg.sender;
        auction.bids[msg.sender] += msg.value;

        if (previousBid == 0)
            assert(userAuctions[msg.sender].add(_auctionIndex));

        emit NewBid(_auctionIndex, msg.sender, msg.value);
    }

    /// @notice Allows the highest bidder to claim the NFT they bid on if the auction is already over.
    /// @param _auctionIndex The index of the auction to claim the NFT from
    function claimNFT(uint256 _auctionIndex) external nonReentrant {
        Auction storage auction = auctions[_auctionIndex];

        require(auction.highestBidOwner == msg.sender, "NOT_WINNER");
        require(block.timestamp >= auction.endTime, "NOT_ENDED");
        require(userAuctions[msg.sender].remove(_auctionIndex), "ALREADY_CLAIMED");

        auction.nftAddress.transferFrom(address(this), msg.sender, auction.nftIndex);

        emit NFTClaimed(_auctionIndex);
    }

    /// @notice Allows bidders to withdraw their bid. Only works if `msg.sender` isn't the highest bidder.
    /// @param _auctionIndex The auction to claim the bid from.
    function withdrawBid(uint256 _auctionIndex) public nonReentrant {
        Auction storage auction = auctions[_auctionIndex];

        require(auction.highestBidOwner != msg.sender, "HIGHEST_BID_OWNER");

        uint256 bidAmount = auction.bids[msg.sender];
        require(bidAmount > 0, "NO_BID");

        auction.bids[msg.sender] = 0;
        assert(userAuctions[msg.sender].remove(_auctionIndex));

        (bool sent, ) = payable(msg.sender).call{value: bidAmount}("");
        require(sent, "ETH_TRANSFER_FAILED");

        emit BidWithdrawn(_auctionIndex, msg.sender, bidAmount);
    }

    /// @notice Allows bidders to withdraw multiple bids. Only works if `msg.sender` isn't the highest bidder.
    /// @param _indexes The auctions to claim the bids from.
    function withdrawBids(uint256[] calldata _indexes) external {
        for (uint256 i; i < _indexes.length; i++) {
            withdrawBid(_indexes[i]);
        }
    }

    /// @return The list of active bids for an account.
    /// @param _account The address to check.
    function getActiveBids(address _account) external view returns (uint256[] memory) {
        return userAuctions[_account].values();
    }

    /// @return The active bid of an account for an auction.
    /// @param _auctionIndex The auction to retrieve the bid from.
    /// @param _account The bidder's account
    function getAuctionBid(uint256 _auctionIndex, address _account) external view returns (uint256) {
        return auctions[_auctionIndex].bids[_account];
    }

    /// @notice Allows the owner to withdraw ETH after a successful auction.
    /// @param _auctionIndex The auction to withdraw the ETH from
    function withdrawETH(uint256 _auctionIndex) external onlyOwner {
        Auction storage auction = auctions[_auctionIndex];

        require(block.timestamp >= auction.endTime, "NOT_ENDED");
        address highestBidder = auction.highestBidOwner;
        require(highestBidder != address(0), "NFT_UNSOLD");        
        require(!auction.ownerClaimed, "ALREADY_CLAIMED");

        auction.ownerClaimed = true;

        (bool sent, ) = payable(msg.sender).call{
            value: auction.bids[highestBidder]
        }("");
        require(sent, "ETH_TRANSFER_FAILED");
    }

    /// @notice Allows the owner to withdraw an unsold NFT
    /// @param _auctionIndex The auction to withdraw the NFT from.
    function withdrawUnsoldNFT(uint256 _auctionIndex) external onlyOwner {
        Auction storage auction = auctions[_auctionIndex];

        require(block.timestamp >= auction.endTime, "NOT_ENDED");
        address highestBidder = auction.highestBidOwner;
        require(highestBidder == address(0), "NFT_SOLD"); 
        require(!auction.ownerClaimed, "ALREADY_CLAIMED");

        auction.ownerClaimed = true;

        auction.nftAddress.transferFrom(address(this), msg.sender, auction.nftIndex);
    }

    /// @notice Allows the owner to set the duration of locks.
    /// @param _newDuration The new lock duration
    function setLockDuration(uint256 _newDuration) public onlyOwner {
        require(_newDuration > 0, "INVALID_LOCK_DURATION");

        emit LockDurationChanged(_newDuration, lockDuration);

        lockDuration = _newDuration;
    }

    /// @notice Allows the owner to set the minimum increment rate from the last highest bid.
    /// @param _newIncrementRate The new increment rate.
    function setMinimumIncrementRate(Rate memory _newIncrementRate)
        public
        onlyOwner
    {
        require(
            _newIncrementRate.denominator != 0 &&
                _newIncrementRate.denominator >= _newIncrementRate.numerator,
            "INVALID_RATE"
        );

        emit MinimumIncrementRateChanged(_newIncrementRate, minIncrementRate);

        minIncrementRate = _newIncrementRate;
    }
}