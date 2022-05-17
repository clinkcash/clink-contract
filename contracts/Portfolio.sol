// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ITokenVault.sol";
import "./interfaces/IERC20Burnable.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/ISwapper.sol";
import "./interfaces/IInitialization.sol";
import "./libraries/AssetInfoLibrary.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title Core
/// @dev This contract allows contract calls to any contract (except TokenVault)
/// from arbitrary callers thus, don't trust calls from this contract in any circumstances.
contract Portfolio is Ownable, IInitialization {
    using AssetInfoLibrary for AssetInfo;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    event LogExchangeRate(uint256 rate);
    event LogAccrue(uint128 accruedAmount);
    event LogAddCollateral(address indexed from, address indexed to, uint256 share);
    event LogRemoveCollateral(address indexed from, address indexed to, uint256 share);
    event LogBorrow(address indexed from, address indexed to, uint256 amount, uint256 part);
    event LogRepay(address indexed from, address indexed to, uint256 amount, uint256 part);
    event LogFeeTo(address indexed newFeeTo);
    event LogWithdrawFees(address indexed feeTo, uint256 feesEarnedFraction);

    // Immutables (for MasterContract and all clones)
    ITokenVault public immutable tokenVault;
    Portfolio public immutable masterContract;
    IERC20 public immutable clink;

    // MasterContract variables
    address public feeTo;

    // Per clone variables
    // Clone init settings
    IERC20[] public collateral; //collateral list
    mapping(address => bool) tokenApprove; //check token status
    mapping(address => IOracle) public oracle;
    mapping(address => bytes) public oracleData;

    // Total amounts
    mapping(address => uint256) public totalCollateralShare; // Total collateral supplied
    AssetInfo public totalBorrow; // amount = Total token amount to be repayed by borrowers, share = Total parts of the debt held by borrowers

    // User balances token address-> user address
    mapping(address => mapping(address => uint256)) public userCollateralShare;
    mapping(address => uint256) public userBorrowPart;

    /// @notice Exchange and interest rate tracking.
    /// This is 'cached' here because calls to Oracles can be very expensive.
    mapping(address => uint256) public exchangeRate;

    struct AccrueInfo {
        uint64 lastAccrued;
        uint128 feesEarned;
        uint64 INTEREST_PER_SECOND;
    }

    AccrueInfo public accrueInfo;

    // Settings
    uint256 public COLLATERIZATION_RATE;
    uint256 private constant COLLATERIZATION_RATE_PRECISION = 1e5; // Must be less than EXCHANGE_RATE_PRECISION (due to optimization in math)

    uint256 private constant EXCHANGE_RATE_PRECISION = 1e18;

    uint256 public LIQUIDATION_MULTIPLIER;
    uint256 private constant LIQUIDATION_MULTIPLIER_PRECISION = 1e5;

    uint256 public BORROW_OPENING_FEE;
    uint256 private constant BORROW_OPENING_FEE_PRECISION = 1e5;

    uint256 private constant DISTRIBUTION_PART = 10;
    uint256 private constant DISTRIBUTION_PRECISION = 100;

    /// @notice The constructor is only used for the initial master contract. Subsequent clones are initialised via `init`.
    constructor(ITokenVault tokenVault_, IERC20 clink_) {
        tokenVault = tokenVault_;
        clink = clink_;
        masterContract = this;
    }

    /// @notice Serves as the constructor for clones, as clones can't have a regular constructor
    /// @dev `data` is abi encoded in the format: (IERC20 collateral, IERC20 asset, IOracle oracle, bytes oracleData)
    function init(bytes calldata data) public payable override {
        require(collateral.length == 0, "Core: already initialized");
        IERC20 initCollateral;
        IOracle initOracle;
        bytes memory initData;
        (initCollateral, initOracle, initData, accrueInfo.INTEREST_PER_SECOND, LIQUIDATION_MULTIPLIER, COLLATERIZATION_RATE, BORROW_OPENING_FEE) = abi
            .decode(data, (IERC20, IOracle, bytes, uint64, uint256, uint256, uint256));
        addCollateralToken(initCollateral, initOracle, initData);
        require(collateral.length > 0, "Core: bad pair");
    }

    /// @notice Accrues the interest on the borrowed tokens and handles the accumulation of fees.
    function accrue() public {
        AccrueInfo memory _accrueInfo = accrueInfo;
        // Number of seconds since accrue was called
        uint256 elapsedTime = block.timestamp - _accrueInfo.lastAccrued;
        if (elapsedTime == 0) {
            return;
        }
        _accrueInfo.lastAccrued = uint64(block.timestamp);

        AssetInfo memory _totalBorrow = totalBorrow;
        if (_totalBorrow.share == 0) {
            accrueInfo = _accrueInfo;
            return;
        }

        // Accrue interest
        uint128 extraAmount = ((uint256(_totalBorrow.amount) * _accrueInfo.INTEREST_PER_SECOND * elapsedTime) / 1e18).toUint128();
        _totalBorrow.amount += extraAmount;

        _accrueInfo.feesEarned += extraAmount;
        totalBorrow = _totalBorrow;
        accrueInfo = _accrueInfo;

        emit LogAccrue(extraAmount);
    }

    /// @notice Concrete implementation of `isSolvent`. Includes a third parameter to allow caching `exchangeRate`.
    function _isSolvent(address user) internal view returns (bool) {
        // accrue must have already been called!
        uint256 borrowPart = userBorrowPart[user];
        if (borrowPart == 0) return true;
        uint collateralVal;
        for (uint i = 0; i < collateral.length; i++) {
            IERC20 token = collateral[i];
            uint256 collateralShare = userCollateralShare[address(token)][user];
            if (collateralShare == 0) {
                continue;
            }

            collateralVal +=
                (tokenVault.toAmount(
                    token,
                    collateralShare * (EXCHANGE_RATE_PRECISION / COLLATERIZATION_RATE_PRECISION) * COLLATERIZATION_RATE,
                    false
                ) * EXCHANGE_RATE_PRECISION) /
                exchangeRate[address(token)];
        }
        AssetInfo memory _totalBorrow = totalBorrow;
        return
            collateralVal >=
            // Moved exchangeRate here instead of dividing the other side to preserve more precision
            (borrowPart * _totalBorrow.amount * EXCHANGE_RATE_PRECISION) / _totalBorrow.share;
    }

    /// @dev Checks if the user is solvent in the closed liquidation case at the end of the function body.
    modifier solvent() {
        _;
        require(_isSolvent(msg.sender), "Core: user insolvent");
    }

    /// @notice Gets the exchange rate. I.e how much collateral to buy 1e18 asset.
    /// This function is supposed to be invoked if needed because Oracle queries can be expensive.
    /// @return updated True if `exchangeRate` was updated.
    /// @return rate The new exchange rate.
    function updateExchangeRate(address token) public returns (bool updated, uint256 rate) {
        (updated, rate) = oracle[token].get(oracleData[token]);

        if (updated) {
            exchangeRate[token] = rate;
            emit LogExchangeRate(rate);
        } else {
            // Return the old rate if fetching wasn't successful
            rate = exchangeRate[token];
        }
    }

    function updateExchangeRateAll() public returns (bool[] memory updated, uint256[] memory rate) {
        updated = new bool[](collateral.length);
        rate = new uint256[](collateral.length);
        for (uint i = 0; i < collateral.length; i++) {
            IERC20 token = collateral[i];
            updateExchangeRate(address(token));
        }
    }

    /// @dev Helper function to move tokens.
    /// @param token The ERC-20 token.
    /// @param share The amount in shares to add.
    /// @param total Grand total amount to deduct from this contract's balance. Only applicable if `skim` is True.
    /// Only used for accounting checks.
    /// @param skim If True, only does a balance check on this contract.
    /// False if tokens from msg.sender in `tokenVault` should be transferred.
    function _addTokens(
        IERC20 token,
        uint256 share,
        uint256 total,
        bool skim
    ) internal {
        if (skim) {
            require(share <= tokenVault.balanceOf(token, address(this)) - total, "Core: Skim too much");
        } else {
            tokenVault.transfer(token, msg.sender, address(this), share);
        }
    }

    /// @notice Adds `collateral` from msg.sender to the account `to`.
    /// @param to The receiver of the tokens.
    /// @param skim True if the amount should be skimmed from the deposit balance of msg.sender.x
    /// False if tokens from msg.sender in `tokenVault` should be transferred.
    /// @param share The amount of shares to add for `to`.
    function addCollateral(
        address token,
        address to,
        bool skim,
        uint256 share
    ) public {
        userCollateralShare[token][to] += share;
        uint256 oldTotalCollateralShare = totalCollateralShare[token];
        totalCollateralShare[token] = oldTotalCollateralShare + share;
        _addTokens(IERC20(token), share, oldTotalCollateralShare, skim);
        emit LogAddCollateral(skim ? address(tokenVault) : msg.sender, to, share);
    }

    /// @dev Concrete implementation of `removeCollateral`.
    function _removeCollateral(
        address token,
        address to,
        uint256 share
    ) internal checkToken(token) {
        userCollateralShare[token][msg.sender] = userCollateralShare[token][msg.sender] - share;
        totalCollateralShare[token] = totalCollateralShare[token] - share;
        emit LogRemoveCollateral(msg.sender, to, share);
        tokenVault.transfer(IERC20(token), address(this), to, share);
    }

    /// @notice Removes `share` amount of collateral and transfers it to `to`.
    /// @param to The receiver of the shares.
    /// @param share Amount of shares to remove.
    function removeCollateral(
        address token,
        address to,
        uint256 share
    ) public solvent {
        // accrue must be called because we check solvency
        accrue();
        _removeCollateral(token, to, share);
    }

    /// @dev Concrete implementation of `borrow`.
    function _borrow(address to, uint256 amount) internal returns (uint256 part, uint256 share) {
        uint256 feeAmount = (amount * BORROW_OPENING_FEE) / BORROW_OPENING_FEE_PRECISION;
        // A flat % fee is charged for any borrow
        (totalBorrow, part) = totalBorrow.add(amount + feeAmount, true);
        accrueInfo.feesEarned += uint128(feeAmount);
        userBorrowPart[msg.sender] += part;

        // As long as there are tokens on this contract you can 'mint'... this enables limiting borrows
        share = tokenVault.toShare(clink, amount, false);
        tokenVault.transfer(clink, address(this), to, share);

        emit LogBorrow(msg.sender, to, amount + feeAmount, part);
    }

    /// @notice Sender borrows `amount` and transfers it to `to`.
    /// @return part Total part of the debt held by borrowers.
    /// @return share Total amount in shares borrowed.
    function borrow(address to, uint256 amount) public solvent returns (uint256 part, uint256 share) {
        accrue();
        (part, share) = _borrow(to, amount);
    }

    /// @dev Concrete implementation of `repay`.
    function _repay(
        address to,
        bool skim,
        uint256 part
    ) internal returns (uint256 amount) {
        (totalBorrow, amount) = totalBorrow.sub(part, true);
        userBorrowPart[to] = userBorrowPart[to] - part;

        uint256 share = tokenVault.toShare(clink, amount, true);
        tokenVault.transfer(clink, skim ? address(tokenVault) : msg.sender, address(this), share);
        emit LogRepay(skim ? address(tokenVault) : msg.sender, to, amount, part);
    }

    /// @notice Repays a loan.
    /// @param to Address of the user this payment should go.
    /// @param skim True if the amount should be skimmed from the deposit balance of msg.sender.
    /// False if tokens from msg.sender in `tokenVault` should be transferred.
    /// @param part The amount to repay. See `userBorrowPart`.
    /// @return amount The total amount repayed.
    function repay(
        address to,
        bool skim,
        uint256 part
    ) public returns (uint256 amount) {
        accrue();
        amount = _repay(to, skim, part);
    }

    // Functions that need accrue to be called
    uint8 internal constant ACTION_REPAY = 2;
    uint8 internal constant ACTION_REMOVE_COLLATERAL = 4;
    uint8 internal constant ACTION_BORROW = 5;
    uint8 internal constant ACTION_GET_REPAY_SHARE = 6;
    uint8 internal constant ACTION_GET_REPAY_PART = 7;
    uint8 internal constant ACTION_ACCRUE = 8;

    // Functions that don't need accrue to be called
    uint8 internal constant ACTION_ADD_COLLATERAL = 10;
    uint8 internal constant ACTION_UPDATE_EXCHANGE_RATE = 11;

    // Function on TokenVault
    uint8 internal constant ACTION_TOKEN_VAULT_DEPOSIT = 20;
    uint8 internal constant ACTION_TOKEN_VAULT_WITHDRAW = 21;
    uint8 internal constant ACTION_TOKEN_VAULT_TRANSFER = 22;
    uint8 internal constant ACTION_TOKEN_VAULT_TRANSFER_MULTIPLE = 23;
    uint8 internal constant ACTION_TOKEN_VAULT_SETAPPROVAL = 24;

    // Any external call (except to TokenVault)
    uint8 internal constant ACTION_CALL = 30;

    int256 internal constant USE_VALUE1 = -1;
    int256 internal constant USE_VALUE2 = -2;

    /// @dev Helper function for choosing the correct value (`value1` or `value2`) depending on `inNum`.
    function _num(
        int256 inNum,
        uint256 value1,
        uint256 value2
    ) internal pure returns (uint256 outNum) {
        outNum = inNum >= 0 ? uint256(inNum) : (inNum == USE_VALUE1 ? value1 : value2);
    }

    /// @dev Helper function for depositing into `tokenVault`.
    function _tokenVaultDeposit(
        bytes memory data,
        uint256 value,
        uint256 value1,
        uint256 value2
    ) internal returns (uint256, uint256) {
        (IERC20 token, address to, int256 amount, int256 share) = abi.decode(data, (IERC20, address, int256, int256));
        amount = int256(_num(amount, value1, value2));
        // Done this way to avoid stack too deep errors
        share = int256(_num(share, value1, value2));
        return tokenVault.deposit{value: value}(token, msg.sender, to, uint256(amount), uint256(share));
    }

    /// @dev Helper function to withdraw from the `tokenVault`.
    function _tokenVaultWithdraw(
        bytes memory data,
        uint256 value1,
        uint256 value2
    ) internal returns (uint256, uint256) {
        (IERC20 token, address to, int256 amount, int256 share) = abi.decode(data, (IERC20, address, int256, int256));
        return tokenVault.withdraw(token, msg.sender, to, _num(amount, value1, value2), _num(share, value1, value2));
    }

    /// @dev Helper function to perform a contract call and eventually extracting revert messages on failure.
    /// Calls to `tokenVault` are not allowed for obvious security reasons.
    /// This also means that calls made from this contract shall *not* be trusted.
    function _call(
        uint256 value,
        bytes memory data,
        uint256 value1,
        uint256 value2
    ) internal returns (bytes memory, uint8) {
        (address callee, bytes memory callData, bool useValue1, bool useValue2, uint8 returnValues) = abi.decode(
            data,
            (address, bytes, bool, bool, uint8)
        );

        if (useValue1 && !useValue2) {
            callData = abi.encodePacked(callData, value1);
        } else if (!useValue1 && useValue2) {
            callData = abi.encodePacked(callData, value2);
        } else if (useValue1 && useValue2) {
            callData = abi.encodePacked(callData, value1, value2);
        }

        require(callee != address(tokenVault) && callee != address(this), "Core: can't call");

        (bool success, bytes memory returnData) = callee.call{value: value}(callData);
        require(success, "Core: call failed");
        return (returnData, returnValues);
    }

    struct CookStatus {
        bool needsSolvencyCheck;
        bool hasAccrued;
    }

    /// @notice Executes a set of actions and allows composability (contract calls) to other contracts.
    /// @param actions An array with a sequence of actions to execute (see ACTION_ declarations).
    /// @param values A one-to-one mapped array to `actions`. ETH amounts to send along with the actions.
    /// Only applicable to `ACTION_CALL`, `ACTION_TOKEN_VAULT_DEPOSIT`.
    /// @param datas A one-to-one mapped array to `actions`. Contains abi encoded data of function arguments.
    /// @return value1 May contain the first positioned return value of the last executed action (if applicable).
    /// @return value2 May contain the second positioned return value of the last executed action which returns 2 values (if applicable).
    function cook(
        uint8[] calldata actions,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external payable returns (uint256 value1, uint256 value2) {
        CookStatus memory status;
        for (uint256 i = 0; i < actions.length; i++) {
            uint8 action = actions[i];
            if (!status.hasAccrued && action < 10) {
                accrue();
                status.hasAccrued = true;
            }
            if (action == ACTION_ADD_COLLATERAL) {
                (address token, int256 share, address to, bool skim) = abi.decode(datas[i], (address, int256, address, bool));
                addCollateral(token, to, skim, _num(share, value1, value2));
            } else if (action == ACTION_REPAY) {
                (int256 part, address to, bool skim) = abi.decode(datas[i], (int256, address, bool));
                _repay(to, skim, _num(part, value1, value2));
            } else if (action == ACTION_REMOVE_COLLATERAL) {
                (address token, int256 share, address to) = abi.decode(datas[i], (address, int256, address));
                _removeCollateral(token, to, _num(share, value1, value2));
                status.needsSolvencyCheck = true;
            } else if (action == ACTION_BORROW) {
                (int256 amount, address to) = abi.decode(datas[i], (int256, address));
                (value1, value2) = _borrow(to, _num(amount, value1, value2));
                status.needsSolvencyCheck = true;
            } else if (action == ACTION_UPDATE_EXCHANGE_RATE) {
                (address token, bool must_update, uint256 minRate, uint256 maxRate) = abi.decode(datas[i], (address, bool, uint256, uint256));
                (bool updated, uint256 rate) = updateExchangeRate(token);
                require((!must_update || updated) && rate > minRate && (maxRate == 0 || rate > maxRate), "Core: rate not ok");
            } else if (action == ACTION_TOKEN_VAULT_SETAPPROVAL) {
                (address user, address _masterContract, bool approved, uint8 v, bytes32 r, bytes32 s) = abi.decode(
                    datas[i],
                    (address, address, bool, uint8, bytes32, bytes32)
                );
                tokenVault.setMasterContractApproval(user, _masterContract, approved, v, r, s);
            } else if (action == ACTION_TOKEN_VAULT_DEPOSIT) {
                (value1, value2) = _tokenVaultDeposit(datas[i], values[i], value1, value2);
            } else if (action == ACTION_TOKEN_VAULT_WITHDRAW) {
                (value1, value2) = _tokenVaultWithdraw(datas[i], value1, value2);
            } else if (action == ACTION_TOKEN_VAULT_TRANSFER) {
                (IERC20 token, address to, int256 share) = abi.decode(datas[i], (IERC20, address, int256));
                tokenVault.transfer(token, msg.sender, to, _num(share, value1, value2));
            } else if (action == ACTION_TOKEN_VAULT_TRANSFER_MULTIPLE) {
                (IERC20 token, address[] memory tos, uint256[] memory shares) = abi.decode(datas[i], (IERC20, address[], uint256[]));
                tokenVault.transferMultiple(token, msg.sender, tos, shares);
            } else if (action == ACTION_CALL) {
                (bytes memory returnData, uint8 returnValues) = _call(values[i], datas[i], value1, value2);

                if (returnValues == 1) {
                    (value1) = abi.decode(returnData, (uint256));
                } else if (returnValues == 2) {
                    (value1, value2) = abi.decode(returnData, (uint256, uint256));
                }
            } else if (action == ACTION_GET_REPAY_SHARE) {
                int256 part = abi.decode(datas[i], (int256));
                value1 = tokenVault.toShare(clink, totalBorrow.toAmount(_num(part, value1, value2), true), true);
            } else if (action == ACTION_GET_REPAY_PART) {
                int256 amount = abi.decode(datas[i], (int256));
                value1 = totalBorrow.toShare(_num(amount, value1, value2), false);
            }
        }

        if (status.needsSolvencyCheck) {
            require(_isSolvent(msg.sender), "Core: user insolvent");
        }
    }

    // /// @notice Handles the liquidation of users' balances, once the users' amount of collateral is too low.
    // /// @param users An array of user addresses.
    // /// @param maxBorrowParts A one-to-one mapping to `users`, contains maximum (partial) borrow amounts (to liquidate) of the respective user.
    // /// @param to Address of the receiver in open liquidations if `swapper` is zero.
    // function liquidate(
    //     address[] calldata users,
    //     address to,
    //     ISwapper[] memory swapper
    // ) public {
    //     // Oracle can fail but we still need to allow liquidations
    //     updateExchangeRateAll();
    //     accrue();

    //     uint256[] memory allCollateralShare = new uint256[](collateral.length);
    //     uint256 allBorrowAmount;
    //     uint256 allBorrowPart;
    //     AssetInfo memory _totalBorrow = totalBorrow;
    //     for (uint256 i = 0; i < users.length; i++) {
    //         address user = users[i];
    //         uint256 totalPart;//total user borrow part
    //         
    //         if (!_isSolvent(user)) {
    //             for (uint256 j = 0; j < collateral.length; j++) {
    //                 address token = address(collateral[j]);
    //                 uint256 collateralShare = userCollateralShare[token][user];
    //                 if (collateralShare == 0) {
    //                     continue;
    //                 }
    //                 uint256 collateralShareAmount = tokenVault.totals(collateral[index]).toAmount(collateralShare, false);
    //                 uint256 borrowAmount = (collateralShareAmount * LIQUIDATION_MULTIPLIER_PRECISION * EXCHANGE_RATE_PRECISION) /
    //                     (LIQUIDATION_MULTIPLIER * exchangeRate[token]);
    //                 uint256 borrowPart = _totalBorrow.toShare(borrowAmount, false);
    //                 totalPart += borrowPart;
    //             }
    //             if (totalPart == 0) {
    //                 continue;
    //             }
    //             uint256 rate = 100;
    //             if (totalPart > userBorrowPart[user]) {
    //                 rate = (userBorrowPart[user] * 100) / totalPart;
    //             }
    //             uint256 targetPart = (totalPart * rate) / 100;
    //             allBorrowPart += targetPart;
    //             allBorrowAmount += _totalBorrow.toAmount(targetPart, false);
    //             for (uint256 j = 0; j < collateral.length; j++) {
    //                 address token = address(collateral[j]);
    //                 uint256 collateralShare = userCollateralShare[token][user];
    //                 if (collateralShare == 0) {
    //                     continue;
    //                 }
    //                 if (rate == 100) {
    //                     userCollateralShare[token][user] = 0;
    //                     allCollateralShare[j] += collateralShare;
    //                 } else {
    //                     collateralShare = (collateralShare * rate) / 100;
    //                     userCollateralShare[token][user] -= collateralShare;
    //                     allCollateralShare[j] += collateralShare;
    //                 }
    //             }
    //         }
    //     }
    //     require(allBorrowAmount != 0, "Core: all are solvent");
    //     _totalBorrow.amount -= allBorrowAmount.toUint128();
    //     _totalBorrow.share -= allBorrowPart.toUint128();
    //     totalBorrow = _totalBorrow;

    //     // Apply a percentual fee share to sSpell holders
    //     {
    //         uint256 distributionAmount = ((((allBorrowAmount * LIQUIDATION_MULTIPLIER) / LIQUIDATION_MULTIPLIER_PRECISION) - allBorrowAmount) *
    //             DISTRIBUTION_PART) / DISTRIBUTION_PRECISION;
    //         // Distribution Amount
    //         allBorrowAmount += distributionAmount;
    //         accrueInfo.feesEarned += distributionAmount.toUint128();
    //     }

    //     uint256 allBorrowShare = tokenVault.toShare(clink, allBorrowAmount, true);

    //     // Swap using a swapper freely chosen by the caller
    //     // Open (flash) liquidation: get proceeds first and provide the borrow after
    //     for (uint i = 0; i < collateral.length; i++) {
    //         if (allCollateralShare[i] == 0) {
    //             continue;
    //         }
    //         totalCollateralShare[address(collateral[i])] -= allCollateralShare[i];
    //         tokenVault.transfer(collateral[i], address(this), to, allCollateralShare[i]);
    //         if (swapper[i] != ISwapper(address(0))) {
    //             swapper[i].swap(collateral[i], clink, msg.sender, 0, allCollateralShare[i]);
    //         }
    //     }
    //     // msg.sender will be rewarded the stable coin for the extra collateral share(allCollateralShare).
    //     tokenVault.transfer(clink, msg.sender, address(this), allBorrowShare);
    // }

    /// @notice Withdraws the fees accumulated.
    function withdrawFees() public {
        accrue();
        address _feeTo = masterContract.feeTo();
        uint256 _feesEarned = accrueInfo.feesEarned;
        uint256 share = tokenVault.toShare(clink, _feesEarned, false);
        tokenVault.transfer(clink, address(this), _feeTo, share);
        accrueInfo.feesEarned = 0;

        emit LogWithdrawFees(_feeTo, _feesEarned);
    }

    /// @notice Sets the beneficiary of interest accrued.
    /// MasterContract Only Admin function.
    /// @param newFeeTo The address of the receiver.
    function setFeeTo(address newFeeTo) public onlyOwner {
        feeTo = newFeeTo;
        emit LogFeeTo(newFeeTo);
    }

    /// @notice reduces the supply of CLINK
    /// @param amount amount to reduce supply by
    function reduceSupply(uint256 amount) public {
        require(msg.sender == masterContract.owner(), "Caller is not the owner");
        tokenVault.withdraw(clink, address(this), address(this), amount, 0);
        IERC20Burnable(address(clink)).burn(amount);
    }

    modifier checkToken(address token) {
        require(tokenApprove[token] == true, "token not supported");
        _;
    }

    function addCollateralToken(
        IERC20 _token,
        IOracle initOracle,
        bytes memory initData
    ) public {
        if (collateral.length > 0) {
            require(msg.sender == masterContract.owner(), "Caller is not the owner");
        }
        collateral.push(_token);
        oracle[address(_token)] = initOracle;
        oracleData[address(_token)] = initData;
        tokenApprove[address(_token)] = true;
    }
}
