// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "./interfaces/IPriceHelper.sol";
import "../interfaces/ITokenVault.sol";
import "../interfaces/IInitialization.sol";

/// @title NFT lending vault
/// @notice This contracts allows users to borrow PUSD using NFTs as collateral.
/// The floor price of the NFT collection is fetched using a chainlink oracle, while some other more valuable traits
/// can have an higher price set by the DAO. Users can also increase the price (and thus the borrow limit) of their
/// NFT by submitting a governance proposal. If the proposal is approved the user can lock a percentage of the new price
/// worth of JPEG to make it effective
contract NFTVault is Ownable, ReentrancyGuard, IInitialization, Multicall {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    event PositionOpened(address indexed owner, uint256 indexed index);
    event Borrowed(address indexed owner, uint256 indexed index, uint256 amount);
    event Repaid(address indexed owner, uint256 indexed index, uint256 amount);
    event PositionClosed(address indexed owner, uint256 indexed index);
    event Liquidated(address indexed liquidator, address indexed owner, uint256 indexed index, bool insured);
    event Repurchased(address indexed owner, uint256 indexed index);
    event InsuranceExpired(address indexed owner, uint256 indexed index);
    event LogFeeTo(address indexed newFeeTo);

    enum BorrowType {
        NOT_CONFIRMED,
        NON_INSURANCE,
        USE_INSURANCE
    }

    struct Position {
        BorrowType borrowType;
        uint256 debtPrincipal;
        uint256 debtPortion; //
        uint256 debtAmountForRepurchase;
        uint256 liquidatedAt;
        address liquidator;
    }

    struct Rate {
        uint128 numerator;
        uint128 denominator;
    }

    struct VaultSettings {
        Rate debtInterestApr;
        Rate creditLimitRate;
        Rate liquidationLimitRate;
        Rate organizationFeeRate;
        Rate insurancePurchaseRate;
        Rate insuranceLiquidationPenaltyRate;
        uint256 insuranceRepurchaseTimeLimit;
    }

    IERC20 public immutable clink;
    ITokenVault public immutable tokenVault;
    NFTVault public immutable masterContract;

    // MasterContract variables
    address public feeTo;

    IERC721 public nftContract;
    IPriceHelper public priceHelper;

    /// @notice Total outstanding debt
    uint256 public totalDebtAmount;
    /// @dev Last time debt was accrued. See {accrue} for more info
    uint256 public totalDebtAccruedAt;
    uint256 public totalFeeCollected;
    uint256 public totalDebtPortion;

    VaultSettings public settings;

    /// @dev Keeps track of all the NFTs used as collateral for positions
    EnumerableSet.UintSet private positionIndexes;

    mapping(uint256 => Position) private positions;
    mapping(uint256 => address) public positionOwner;

    /// @dev Checks if the provided NFT index is valid
    /// @param nftIndex The index to check
    modifier validNFTIndex(uint256 nftIndex) {
        //The standard OZ ERC721 implementation of ownerOf reverts on a non existing nft isntead of returning address(0)
        require(nftContract.ownerOf(nftIndex) != address(0), "invalid_nft");
        _;
    }

    constructor(IERC20 _clink, ITokenVault _tokenVault) {
        clink = _clink;
        tokenVault = _tokenVault;
        masterContract = this;
    }

    /// @notice Serves as the constructor for clones, as clones can't have a regular constructor
    /// @dev `data` is abi encoded in the format
    function init(bytes calldata data) public payable override {
        require(address(nftContract) == address(0), "NFTVault: already initialized");

        (VaultSettings memory _settings, IERC721 _nftContract, IPriceHelper _priceHelper) = abi.decode(
            data,
            (VaultSettings, IERC721, IPriceHelper)
        );

        _validateRate(_settings.debtInterestApr);
        _validateRate(_settings.creditLimitRate);
        _validateRate(_settings.liquidationLimitRate);
        _validateRate(_settings.organizationFeeRate);
        _validateRate(_settings.insurancePurchaseRate);
        _validateRate(_settings.insuranceLiquidationPenaltyRate);

        require(_greaterThan(_settings.liquidationLimitRate, _settings.creditLimitRate), "invalid_liquidation_limit");

        nftContract = _nftContract;
        priceHelper = _priceHelper;
        settings = _settings;
        require(address(nftContract) != address(0), "NFTVault: bad pair");
    }

    /// @dev The {accrue} function updates the contract's state by calculating
    /// the additional interest accrued since the last state update
    function accrue() public {
        uint256 additionalInterest = _calculateAdditionalInterest();

        totalDebtAccruedAt = block.timestamp;

        totalDebtAmount += additionalInterest;
        totalFeeCollected += additionalInterest;
    }

    /// @dev Checks if `r1` is greater than `r2`.
    function _greaterThan(Rate memory _r1, Rate memory _r2) internal pure returns (bool) {
        return _r1.numerator * _r2.denominator > _r2.numerator * _r1.denominator;
    }

    /// @dev Validates a rate. The denominator must be greater than zero and greater than or equal to the numerator.
    /// @param rate The rate to validate
    function _validateRate(Rate memory rate) internal pure {
        require(rate.denominator != 0 && rate.denominator >= rate.numerator, "invalid_rate");
    }

    struct NFTInfo {
        uint256 index;
        address owner;
        uint256 nftValueUSD;
    }

    /// @notice Returns data relative to the NFT at index `_nftIndex`
    /// @param _nftIndex The NFT index
    /// @return nftInfo The data relative to the NFT
    function getNFTInfo(uint256 _nftIndex) external view returns (NFTInfo memory nftInfo) {
        nftInfo = NFTInfo(_nftIndex, nftContract.ownerOf(_nftIndex), _getNFTValueUSD(_nftIndex));
    }

    /// @dev Returns the credit limit of an NFT
    /// @param _nftIndex The NFT to return credit limit of
    /// @return The NFT credit limit
    function _getCreditLimit(uint256 _nftIndex) internal view returns (uint256) {
        uint256 value = _getNFTValueUSD(_nftIndex);
        return (value * settings.creditLimitRate.numerator) / settings.creditLimitRate.denominator;
    }

    /// @dev Returns the minimum amount of debt necessary to liquidate an NFT
    /// @param _nftIndex The index of the NFT
    /// @return The minimum amount of debt to liquidate the NFT
    function _getLiquidationLimit(uint256 _nftIndex) internal view returns (uint256) {
        uint256 value = _getNFTValueUSD(_nftIndex);
        return (value * settings.liquidationLimitRate.numerator) / settings.liquidationLimitRate.denominator;
    }

    /// @dev Calculates current outstanding debt of an NFT
    /// @param _nftIndex The NFT to calculate the outstanding debt of
    /// @return The outstanding debt value
    function _getDebtAmount(uint256 _nftIndex) internal view returns (uint256) {
        uint256 calculatedDebt = _calculateDebt(totalDebtAmount, positions[_nftIndex].debtPortion, totalDebtPortion);

        uint256 principal = positions[_nftIndex].debtPrincipal;

        //_calculateDebt is prone to rounding errors that may cause
        //the calculated debt amount to be 1 or 2 units less than
        //the debt principal when the accrue() function isn't called
        //in between the first borrow and the _calculateDebt call.
        return principal > calculatedDebt ? principal : calculatedDebt;
    }

    /// @dev Calculates the total debt of a position given the global debt, the user's portion of the debt and the total user portions
    /// @param total The global outstanding debt
    /// @param userPortion The user's portion of debt
    /// @param totalPortion The total user portions of debt
    /// @return The outstanding debt of the position
    function _calculateDebt(
        uint256 total,
        uint256 userPortion,
        uint256 totalPortion
    ) internal pure returns (uint256) {
        return totalPortion == 0 ? 0 : (total * userPortion) / totalPortion;
    }

    /// @dev Opens a position
    /// Emits a {PositionOpened} event
    /// @param _owner The owner of the position to open
    /// @param _nftIndex The NFT used as collateral for the position
    function _openPosition(address _owner, uint256 _nftIndex) internal {
        positionOwner[_nftIndex] = _owner;
        positionIndexes.add(_nftIndex);

        nftContract.transferFrom(_owner, address(this), _nftIndex);

        emit PositionOpened(_owner, _nftIndex);
    }

    /// @dev Calculates the additional global interest since last time the contract's state was updated by calling {accrue}
    /// @return The additional interest value
    function _calculateAdditionalInterest() internal view returns (uint256) {
        // Number of seconds since {accrue} was called
        uint256 elapsedTime = block.timestamp - totalDebtAccruedAt;
        if (elapsedTime == 0) {
            return 0;
        }

        uint256 totalDebt = totalDebtAmount;
        if (totalDebt == 0) {
            return 0;
        }

        // Accrue interest
        return
            (elapsedTime * totalDebt * settings.debtInterestApr.numerator) /
            settings.debtInterestApr.denominator /
            365 days;
    }

    /// @notice Returns the number of open positions
    /// @return The number of open positions
    function totalPositions() external view returns (uint256) {
        return positionIndexes.length();
    }

    /// @notice Returns all open position NFT indexes
    /// @return The open position NFT indexes
    function openPositionsIndexes() external view returns (uint256[] memory) {
        return positionIndexes.values();
    }

    function _getNFTValueUSD(uint256 _nftIndex) public view returns (uint256) {
        return priceHelper.getNFTValueUSD(address(nftContract), _nftIndex);
    }

    struct PositionPreview {
        address owner;
        uint256 nftIndex;
        uint256 nftValueUSD;
        VaultSettings vaultSettings;
        uint256 creditLimit;
        uint256 debtPrincipal;
        uint256 debtPortion;
        uint256 debtInterest;
        uint256 liquidatedAt;
        BorrowType borrowType;
        bool liquidatable;
        address liquidator;
    }

    /// @notice Returns data relative to a postition, existing or not
    /// @param _nftIndex The index of the NFT used as collateral for the position
    /// @return preview See assignment below
    function showPosition(uint256 _nftIndex)
        external
        view
        validNFTIndex(_nftIndex)
        returns (PositionPreview memory preview)
    {
        address posOwner = positionOwner[_nftIndex];

        Position storage position = positions[_nftIndex];
        uint256 debtPrincipal = position.debtPrincipal;
        uint256 liquidatedAt = position.liquidatedAt;
        uint256 debtAmount = liquidatedAt != 0
            ? position.debtAmountForRepurchase //calculate updated debt
            : _calculateDebt(totalDebtAmount + _calculateAdditionalInterest(), position.debtPortion, totalDebtPortion);

        //_calculateDebt is prone to rounding errors that may cause
        //the calculated debt amount to be 1 or 2 units less than
        //the debt principal if no time has elapsed in between the first borrow
        //and the _calculateDebt call.
        if (debtPrincipal > debtAmount) debtAmount = debtPrincipal;

        unchecked {
            preview = PositionPreview({
                owner: posOwner, //the owner of the position, `address(0)` if the position doesn't exists
                nftIndex: _nftIndex, //the NFT used as collateral for the position
                nftValueUSD: _getNFTValueUSD(_nftIndex), //the value in USD of the NFT
                vaultSettings: settings, //the current vault's settings
                creditLimit: _getCreditLimit(_nftIndex), //the NFT's credit limit
                debtPrincipal: debtPrincipal, //the debt principal for the position, `0` if the position doesn't exists
                debtPortion: position.debtPortion,
                debtInterest: debtAmount - debtPrincipal, //the interest of the position
                borrowType: position.borrowType, //the insurance type of the position, `NOT_CONFIRMED` if it doesn't exist
                liquidatable: liquidatedAt == 0 && debtAmount >= _getLiquidationLimit(_nftIndex), //if the position can be liquidated
                liquidatedAt: liquidatedAt, //if the position has been liquidated and it had insurance, the timestamp at which the liquidation happened
                liquidator: position.liquidator //if the position has been liquidated and it had insurance, the address of the liquidator
            });
        }
    }

    /// @notice Allows users to open positions and borrow using an NFT
    /// @dev emits a {Borrowed} event
    /// @param _nftIndex The index of the NFT to be used as collateral
    /// @param _amount The amount of PUSD to be borrowed. Note that the user will receive less than the amount requested,
    /// the borrow fee and insurance automatically get removed from the amount borrowed
    /// @param _useInsurance Whereter to open an insured position. In case the position has already been opened previously,
    /// this parameter needs to match the previous insurance mode. To change insurance mode, a user needs to close and reopen the position
    function borrow(
        uint256 _nftIndex,
        uint256 _amount,
        bool _useInsurance
    ) external validNFTIndex(_nftIndex) nonReentrant {
        accrue();

        require(msg.sender == positionOwner[_nftIndex] || address(0) == positionOwner[_nftIndex], "unauthorized");
        require(_amount != 0, "invalid_amount");

        Position storage position = positions[_nftIndex];
        require(position.liquidatedAt == 0, "liquidated");
        require(
            position.borrowType == BorrowType.NOT_CONFIRMED ||
                (position.borrowType == BorrowType.USE_INSURANCE && _useInsurance) ||
                (position.borrowType == BorrowType.NON_INSURANCE && !_useInsurance),
            "invalid_insurance_mode"
        );

        uint256 creditLimit = _getCreditLimit(_nftIndex);
        uint256 debtAmount = _getDebtAmount(_nftIndex);
        require(debtAmount + _amount <= creditLimit, "insufficient_credit");

        //calculate the borrow fee
        uint256 organizationFee = (_amount * settings.organizationFeeRate.numerator) /
            settings.organizationFeeRate.denominator;

        uint256 feeAmount = organizationFee;
        //if the position is insured, calculate the insurance fee
        if (position.borrowType == BorrowType.USE_INSURANCE || _useInsurance) {
            feeAmount +=
                (_amount * settings.insurancePurchaseRate.numerator) /
                settings.insurancePurchaseRate.denominator;
        }
        totalFeeCollected += feeAmount;

        if (position.borrowType == BorrowType.NOT_CONFIRMED) {
            position.borrowType = _useInsurance ? BorrowType.USE_INSURANCE : BorrowType.NON_INSURANCE;
        }

        uint256 debtPortion = totalDebtPortion;
        // update debt portion
        if (debtPortion == 0) {
            totalDebtPortion = _amount;
            position.debtPortion = _amount;
        } else {
            //debtPortion =100,totalDebtAmount=200,_amount=100,
            //plusPortion = (100 * 100) / 200 = 50
            // plusPortion :debtPortion = _amount:totalDebtAmount = 1/2
            uint256 plusPortion = (debtPortion * _amount) / totalDebtAmount;
            totalDebtPortion = debtPortion + plusPortion;
            position.debtPortion += plusPortion;
        }
        position.debtPrincipal += _amount;
        totalDebtAmount += _amount;

        if (positionOwner[_nftIndex] == address(0)) {
            _openPosition(msg.sender, _nftIndex);
        }

        _withdrawClink(msg.sender, _amount - feeAmount);

        emit Borrowed(msg.sender, _nftIndex, _amount);
    }

    /// @notice Allows users to repay a portion/all of their debt. Note that since interest increases every second,
    /// a user wanting to repay all of their debt should repay for an amount greater than their current debt to account for the
    /// additional interest while the repay transaction is pending, the contract will only take what's necessary to repay all the debt
    /// @dev Emits a {Repaid} event
    /// @param _nftIndex The NFT used as collateral for the position
    /// @param _amount The amount of debt to repay. If greater than the position's outstanding debt, only the amount necessary to repay all the debt will be taken
    function repay(uint256 _nftIndex, uint256 _amount) external validNFTIndex(_nftIndex) nonReentrant {
        accrue();

        require(msg.sender == positionOwner[_nftIndex], "unauthorized");
        require(_amount != 0, "invalid_amount");

        Position storage position = positions[_nftIndex];
        require(position.liquidatedAt == 0, "liquidated");

        uint256 debtAmount = _getDebtAmount(_nftIndex);
        require(debtAmount != 0, "position_not_borrowed");

        uint256 debtPrincipal = position.debtPrincipal;
        uint256 debtInterest = debtAmount - debtPrincipal;

        _amount = _amount > debtAmount ? debtAmount : _amount;

        // burn all payment, the interest is sent to the DAO using the {collect} function
        _repayClink(msg.sender, _amount);

        uint256 paidPrincipal;

        unchecked {
            paidPrincipal = _amount > debtInterest ? _amount - debtInterest : 0;
        }

        uint256 totalPortion = totalDebtPortion;
        uint256 totalDebt = totalDebtAmount;
        uint256 minusPortion = paidPrincipal == debtPrincipal
            ? position.debtPortion
            : (totalPortion * _amount) / totalDebt;

        totalDebtPortion = totalPortion - minusPortion;
        position.debtPortion -= minusPortion;
        position.debtPrincipal -= paidPrincipal;
        totalDebtAmount = totalDebt - _amount;

        emit Repaid(msg.sender, _nftIndex, _amount);
    }

    /// @notice Allows a user to close a position and get their collateral back, if the position's outstanding debt is 0
    /// @dev Emits a {PositionClosed} event
    /// @param _nftIndex The index of the NFT used as collateral
    function closePosition(uint256 _nftIndex) external validNFTIndex(_nftIndex) nonReentrant {
        accrue();

        require(msg.sender == positionOwner[_nftIndex], "unauthorized");
        require(positions[_nftIndex].liquidatedAt == 0, "liquidated");
        require(_getDebtAmount(_nftIndex) == 0, "position_not_repaid");

        positionOwner[_nftIndex] = address(0);
        delete positions[_nftIndex];
        positionIndexes.remove(_nftIndex);

        // transfer nft back to owner if nft was deposited
        if (nftContract.ownerOf(_nftIndex) == address(this)) {
            nftContract.safeTransferFrom(address(this), msg.sender, _nftIndex);
        }

        emit PositionClosed(msg.sender, _nftIndex);
    }

    /// @notice Positions can only be liquidated
    /// once their debt amount exceeds the minimum liquidation debt to collateral value rate.
    /// In order to liquidate a position, the liquidator needs to repay the user's outstanding debt.
    /// If the position is not insured, it's closed immediately and the collateral is sent to `_recipient`.
    /// If the position is insured, the position remains open (interest doesn't increase) and the owner of the position has a certain amount of time
    /// (`insuranceRepurchaseTimeLimit`) to fully repay the liquidator and pay an additional liquidation fee (`insuranceLiquidationPenaltyRate`), if this
    /// is done in time the user gets back their collateral and their position is automatically closed. If the user doesn't repurchase their collateral
    /// before the time limit passes, the liquidator can claim the liquidated NFT and the position is closed
    /// @dev Emits a {Liquidated} event
    /// @param _nftIndex The NFT to liquidate
    /// @param _recipient The address to send the NFT to
    function liquidate(uint256 _nftIndex, address _recipient) external validNFTIndex(_nftIndex) nonReentrant {
        accrue();

        address posOwner = positionOwner[_nftIndex];
        require(posOwner != address(0), "position_not_exist");

        Position storage position = positions[_nftIndex];
        require(position.liquidatedAt == 0, "liquidated");

        uint256 debtAmount = _getDebtAmount(_nftIndex);
        require(debtAmount >= _getLiquidationLimit(_nftIndex), "position_not_liquidatable");

        // burn all payment
        _repayClink(msg.sender, debtAmount);

        // update debt portion
        totalDebtPortion -= position.debtPortion;
        totalDebtAmount -= debtAmount;
        position.debtPortion = 0;

        bool insured = position.borrowType == BorrowType.USE_INSURANCE;
        if (insured) {
            position.debtAmountForRepurchase = debtAmount;
            position.liquidatedAt = block.timestamp;
            position.liquidator = msg.sender;
        } else {
            // transfer nft to liquidator
            positionOwner[_nftIndex] = address(0);
            delete positions[_nftIndex];
            positionIndexes.remove(_nftIndex);
            nftContract.transferFrom(address(this), _recipient, _nftIndex);
        }

        emit Liquidated(msg.sender, posOwner, _nftIndex, insured);
    }

    /// @notice Allows liquidated users who purchased insurance to repurchase their collateral within the time limit
    /// defined with the `insuranceRepurchaseTimeLimit`. The user needs to pay the liquidator the total amount of debt
    /// the position had at the time of liquidation, plus an insurance liquidation fee defined with `insuranceLiquidationPenaltyRate`
    /// @dev Emits a {Repurchased} event
    /// @param _nftIndex The NFT to repurchase
    function repurchase(uint256 _nftIndex) external validNFTIndex(_nftIndex) nonReentrant {
        Position memory position = positions[_nftIndex];
        require(msg.sender == positionOwner[_nftIndex], "unauthorized");
        require(position.liquidatedAt != 0, "not_liquidated");
        require(position.borrowType == BorrowType.USE_INSURANCE, "non_insurance");
        require(position.liquidatedAt + settings.insuranceRepurchaseTimeLimit >= block.timestamp, "insurance_expired");

        uint256 debtAmount = position.debtAmountForRepurchase;
        uint256 penalty = (debtAmount * settings.insuranceLiquidationPenaltyRate.numerator) /
            settings.insuranceLiquidationPenaltyRate.denominator;

        // transfer nft to user
        positionOwner[_nftIndex] = address(0);
        delete positions[_nftIndex];
        positionIndexes.remove(_nftIndex);

        clink.safeTransferFrom(msg.sender, position.liquidator, debtAmount + penalty);

        nftContract.safeTransferFrom(address(this), msg.sender, _nftIndex);

        emit Repurchased(msg.sender, _nftIndex);
    }

    /// @notice Allows the liquidator who liquidated the insured position with NFT at index `_nftIndex` to claim the position's collateral
    /// after the time period defined with `insuranceRepurchaseTimeLimit` has expired and the position owner has not repurchased the collateral.
    /// @dev Emits an {InsuranceExpired} event
    /// @param _nftIndex The NFT to claim
    /// @param _recipient The address to send the NFT to
    function claimExpiredInsuranceNFT(uint256 _nftIndex, address _recipient)
        external
        validNFTIndex(_nftIndex)
        nonReentrant
    {
        Position memory position = positions[_nftIndex];
        address _owner = positionOwner[_nftIndex];
        require(address(0) != _owner, "no_position");
        require(position.liquidatedAt != 0, "not_liquidated");
        require(
            position.liquidatedAt + settings.insuranceRepurchaseTimeLimit < block.timestamp,
            "insurance_not_expired"
        );
        require(position.liquidator == msg.sender, "unauthorized");

        positionOwner[_nftIndex] = address(0);
        delete positions[_nftIndex];
        positionIndexes.remove(_nftIndex);

        nftContract.transferFrom(address(this), _recipient, _nftIndex);

        emit InsuranceExpired(_owner, _nftIndex);
    }

    function collect() external nonReentrant {
        address _feeTo = masterContract.feeTo();
        require(_feeTo != address(0), "addr err");
        accrue();
        _transferClink(address(this), _feeTo, totalFeeCollected);
        totalFeeCollected = 0;
    }

    /// @notice Sets the beneficiary of interest accrued.
    /// MasterContract Only Admin function.
    /// @param newFeeTo The address of the receiver.
    function setFeeTo(address newFeeTo) public onlyOwner {
        feeTo = newFeeTo;
        emit LogFeeTo(newFeeTo);
    }

    function _transferClink(
        address from,
        address to,
        uint256 amount
    ) internal {
        uint256 share = tokenVault.toShare(clink, amount, false);
        tokenVault.transfer(clink, from, to, share);
    }

    function _withdrawClink(address to, uint256 amount) internal {
        tokenVault.withdraw(clink, address(this), to, amount, 0);
    }

    function _repayClink(address from, uint256 amount) internal {
        clink.safeTransferFrom(from, address(this), amount);
        if (clink.allowance(address(this), address(tokenVault)) < amount) {
            clink.approve(address(tokenVault), type(uint).max);
        }
        tokenVault.deposit(clink, address(this), address(this), amount, 0);
    }

    function approveClick(
        address owner_,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        IERC20Permit(address(clink)).permit(owner_, spender, value, deadline, v, r, s);
    }
}
