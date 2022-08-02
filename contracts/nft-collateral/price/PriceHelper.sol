// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/IAggregatorV3Interface.sol";
import "../interfaces/IPriceHelper.sol";

/// @title NFT USD Price helper
/// @notice The floor price of the NFT collection is fetched using a chainlink oracle, while some other more valuable traits
/// can have an higher price set by the DAO.
contract PriceHelper is AccessControl, IPriceHelper {
    event DaoFloorChanged(address nftContract, uint256 newFloor);

    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");

    bytes32 public constant CUSTOM_NFT_HASH = keccak256("CUSTOM");

    /// @notice Chainlink ETH/USD price feed
    IAggregatorV3Interface public ethAggregator;
    /// @notice Chainlink NFT floor oracle
    mapping(address => IAggregatorV3Interface) public floorOracle;
    /// @notice Chainlink NFT fallback floor oracle
    mapping(address => IAggregatorV3Interface) public fallbackOracle;

    /// @notice If true, the floor price won't be fetched using the Chainlink oracle but
    /// a value set by the DAO will be used instead
    mapping(address => bool) public daoFloorOverride;
    // @notice If true, the floor price will be fetched using the fallback oracle
    mapping(address => bool) public useFallbackOracle;

    //price for batch nft
    mapping(address => mapping(bytes32 => uint256)) public nftTypeValueETH;
    //price for each nft
    mapping(address => mapping(uint256 => uint256)) public nftValueETH;
    //bytes32(0) is floor
    // type for each nft
    mapping(address => mapping(uint256 => bytes32)) public nftTypes;

    /// @dev Checks if the provided NFT index is valid
    /// @param nftIndex The index to check
    modifier validNFTIndex(address nftContract, uint256 nftIndex) {
        //The standard OZ ERC721 implementation of ownerOf reverts on a non existing nft isntead of returning address(0)
        require(IERC721(nftContract).ownerOf(nftIndex) != address(0), "invalid_nft");
        _;
    }

    /// @param _ethAggregator Chainlink ETH/USD price feed address
    constructor(IAggregatorV3Interface _ethAggregator) {
        _setupRole(DAO_ROLE, msg.sender);
        _setRoleAdmin(DAO_ROLE, DAO_ROLE);
        ethAggregator = _ethAggregator;
    }

    struct NFTCategoryInitializer {
        bytes32 hash;
        uint256 valueETH;
        uint256[] nfts;
    }

    /// @param _nftContract The NFT contrat address. It could also be the address of an helper contract
    /// if the target NFT isn't an ERC721 (CryptoPunks as an example)
    /// @param _floorOracle Chainlink floor oracle address
    /// @param _typeInitializers Used to initialize NFT categories with their value and NFT indexes.
    /// Floor NFT shouldn't be initialized this way
    function addNFTCollection(
        address _nftContract,
        IAggregatorV3Interface _floorOracle,
        NFTCategoryInitializer[] calldata _typeInitializers
    ) external onlyRole(DAO_ROLE) {
        floorOracle[_nftContract] = _floorOracle;

        //initializing the categories
        for (uint256 i; i < _typeInitializers.length; ++i) {
            NFTCategoryInitializer memory initializerMem = _typeInitializers[i];
            nftTypeValueETH[_nftContract][initializerMem.hash] = initializerMem.valueETH;
            for (uint256 j; j < initializerMem.nfts.length; j++) {
                nftTypes[_nftContract][initializerMem.nfts[j]] = initializerMem.hash;
            }
        }
    }

    /// @notice Allows the DAO to change fallback oracle
    /// @param _fallback new fallback address
    function setFallbackOracle(address _nftContract, IAggregatorV3Interface _fallback) external onlyRole(DAO_ROLE) {
        require(address(_fallback) != address(0), "invalid_address");

        fallbackOracle[_nftContract] = _fallback;
    }

    /// @notice Allows the DAO to toggle the fallback oracle
    /// @param _useFallback Whether to use the fallback oracle
    function toggleFallbackOracle(address _nftContract, bool _useFallback) external onlyRole(DAO_ROLE) {
        require(address(fallbackOracle[_nftContract]) != address(0), "fallback_not_set");
        useFallbackOracle[_nftContract] = _useFallback;
    }

    /// @notice Allows the DAO to bypass the floor oracle and override the NFT floor value
    /// @param _newFloor The new floor
    function overrideFloor(address _nftContract, uint256 _newFloor) external onlyRole(DAO_ROLE) {
        require(_newFloor != 0, "invalid_floor");
        nftTypeValueETH[_nftContract][bytes32(0)] = _newFloor;
        daoFloorOverride[_nftContract] = true;

        emit DaoFloorChanged(_nftContract, _newFloor);
    }

    /// @notice Allows the DAO to stop overriding floor
    function disableFloorOverride(address _nftContract) external onlyRole(DAO_ROLE) {
        daoFloorOverride[_nftContract] = false;
    }

    /// @notice Allows the DAO to add an NFT to a specific price category
    /// @param _nftIndex The index to add to the category
    /// @param _type The category hash
    function setNFTType(
        address _nftContract,
        uint256 _nftIndex,
        bytes32 _type
    ) external validNFTIndex(_nftContract, _nftIndex) onlyRole(DAO_ROLE) {
        require(_type == bytes32(0) || nftTypeValueETH[_nftContract][_type] != 0, "invalid_nftType");
        nftTypes[_nftContract][_nftIndex] = _type;
    }

    /// @notice Allows the DAO to change the value of an NFT category
    /// @param _type The category hash
    /// @param _amountETH The new value, in ETH
    function setNFTTypeValueETH(
        address _nftContract,
        bytes32 _type,
        uint256 _amountETH
    ) external onlyRole(DAO_ROLE) {
        nftTypeValueETH[_nftContract][_type] = _amountETH;
    }

    /// @notice Allows the DAO to set the value in ETH of the NFT at index `_nftIndex`.
    /// A JPEG deposit by a user is required afterwards. See {finalizePendingNFTValueETH} for more details
    /// @param _nftIndex The index of the NFT to change the value of
    /// @param _amountETH The new desired ETH value
    function setNFTValueETH(
        address _nftContract,
        uint256 _nftIndex,
        uint256 _amountETH
    ) external validNFTIndex(_nftContract, _nftIndex) onlyRole(DAO_ROLE) {
        require(_amountETH != 0, "vaule error");
        nftTypes[_nftContract][_nftIndex] = CUSTOM_NFT_HASH;
        nftValueETH[_nftContract][_nftIndex] = _amountETH;
    }

    /// @dev Returns the value in ETH of the NFT at index `_nftIndex`
    /// @param _nftIndex The NFT to return the value of
    /// @return The value of the NFT, 18 decimals
    function _getNFTValueETH(address _nftContract, uint256 _nftIndex) internal view returns (uint256) {
        bytes32 nftType = nftTypes[_nftContract][_nftIndex];

        if (nftType == bytes32(0) && !daoFloorOverride[_nftContract]) {
            return
                _normalizeAggregatorAnswer(
                    useFallbackOracle[_nftContract] ? fallbackOracle[_nftContract] : floorOracle[_nftContract]
                );
        } else if (nftType == CUSTOM_NFT_HASH) return nftValueETH[_nftContract][_nftIndex];

        return nftTypeValueETH[_nftContract][nftType];
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
        uint256 nft_value = _getNFTValueETH(_nftContract, _nftIndex);
        return (nft_value * _ethPriceUSD()) / 1 ether;
    }

    /// @dev Returns the current ETH price in USD
    /// @return The current ETH price, 18 decimals
    function _ethPriceUSD() internal view returns (uint256) {
        return _normalizeAggregatorAnswer(ethAggregator);
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

    function isOpen(address _nftContract, uint256 _nftIndex) public view override returns (bool) {
        return true;
    }
}
