//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;


interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(address from, address to, uint value) external returns (bool);
}

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint) external;
}

interface TetherToken {
    function approve(address _spender, uint256 _value) external;
    function balanceOf(address user) external view returns (uint256);
}

interface IBentoBoxV1 {
    function toAmount(
        address _token,
        uint256 _share,
        bool _roundUp
    ) external view returns (uint256);

    function withdraw(
        IERC20 token,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256, uint256);

    function deposit(
        IERC20 token,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256, uint256);

    function deploy(
        address masterContract,
        bytes calldata data,
        bool useCreate2
    ) external payable returns (address cloneAddress);

    function setMasterContractApproval(
        address user,
        address masterContract,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function balanceOf(IERC20, address) external view returns (uint256);

    function totals(IERC20) external view returns (uint256 elastic, uint256 base);

    function flashLoan(
        address borrower,
        address receiver,
        IERC20 token,
        uint256 amount,
        bytes calldata data
    ) external;

    function toShare(
        address token,
        uint256 amount,
        bool roundUp
    ) external view returns (uint256 share);
}

interface CurvePool {
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy, address receiver) external returns (uint256);
    function approve(address _spender, uint256 _value) external returns (bool);
    function remove_liquidity_one_coin(uint256 tokenAmount, int128 i, uint256 min_amount) external;
}

interface IThreeCrypto is CurvePool {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external;
}

// This contract simply calls multiple targets sequentially, ensuring WETH balance before and after
contract MIMFlashBotsMultiCall {
    address private immutable owner;
    CurvePool public constant MIM3POOL = CurvePool(0x5a6A4D54456819380173272A5E8E9B9904BdF41B);
    IThreeCrypto constant public threecrypto = IThreeCrypto(0xD51a44d3FaE010294C616388b506AcdA1bfAAE46);
    TetherToken public constant TETHER = TetherToken(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 public constant MIM = IERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
    IWETH public constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() public {
        owner = msg.sender;
        MIM.approve(address(MIM3POOL), type(uint256).max);
        TETHER.approve(address(threecrypto), type(uint256).max);
    }

    receive() external payable {
    }

    function excuteLiquidate(uint256 _ethToCoinbase, address[] memory _tokenVault,address[] memory _liquidateAddr, bytes[] memory _payloads, address receiver) external {
        require(_liquidateAddr.length == _payloads.length);
        uint256 _wethBalanceBefore = WETH.balanceOf(address(this));
        for (uint256 i = 0; i < _liquidateAddr.length; i++) {
            (bool _success, bytes memory _response) = _liquidateAddr[i].call(_payloads[i]);
            require(_success);
        }
        for (uint256 i = 0; i < _tokenVault.length; i++) {
            IBentoBoxV1 tokenVault = IBentoBoxV1(_tokenVault[i]);
             tokenVault.withdraw(MIM, address(this), address(this), 0, tokenVault.balanceOf(MIM, address(this)));
        }

        uint256 minAmt = MIM.balanceOf(address(this));
        uint256 amountTo = MIM3POOL.exchange_underlying(0, 3, minAmt, 0,address(this)); //mim ->usdt

        uint256 amountIntermediate = TETHER.balanceOf(address(this));
        //usdt->weth
        threecrypto.exchange(0, 2, amountIntermediate, 0);

        uint256 _wethBalanceAfter = WETH.balanceOf(address(this));
        require(_wethBalanceAfter > _wethBalanceBefore + _ethToCoinbase);
        WETH.withdraw(_wethBalanceAfter);
        if (_ethToCoinbase == 0) {
            block.coinbase.transfer(address(this).balance * 99 / 100);
            payable(receiver).transfer(address(this).balance);
        } else {
            block.coinbase.transfer(_ethToCoinbase);
            payable(receiver).transfer(address(this).balance);
        }
    }

    function call(address payable _to, uint256 _value, bytes calldata _data) external onlyOwner payable returns (bytes memory) {
        require(_to != address(0));
        (bool _success, bytes memory _result) = _to.call{value : _value}(_data);
        require(_success);
        return _result;
    }
}
