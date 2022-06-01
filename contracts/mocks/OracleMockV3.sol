// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/IOracle.sol";
import "../interfaces/ISushiSwap.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// WARNING: This oracle is only for testing, please use PeggedOracle for a fixed value oracle
// SUSHI SWAP price
contract OracleMockV3 is IOracle {
    bool public testMode; // true return the rate ,false return the oracle value
    uint256 public rate;
    bool public success;

    IERC20Metadata public token;
    ISushiSwap public sushi;
    event Demo(uint256 data);

    constructor(
        address _token,
        address _sushi
    ) {
        token = IERC20Metadata(_token);
        sushi = ISushiSwap(_sushi);
        success = true;
    }

    function set(uint256 rate_) public {
        // The rate can be updated.
        rate = rate_;
    }

    function setSuccess(bool val) public {
        success = val;
    }

    function setTestMode(bool val) public {
        testMode = val;
    }

    function getDataParameter() public pure returns (bytes memory) {
        return abi.encode("0x0");
    }

    // Get the latest exchange rate
    function get(bytes calldata data) public override returns (bool, uint256) {
        if (!testMode) {
            return (true, getPrice());
        }
        return (success, rate);
    }

    // Check the last exchange rate without any state changes
    function peek(bytes calldata data)
        public
        view
        override
        returns (bool, uint256)
    {
        if (!testMode) {
            return (true, getPrice());
        }
        return (success, rate);
    }

    function peekSpot(bytes calldata data)
        public
        view
        override
        returns (uint256)
    {
        if (!testMode) {
            return getPrice();
        }
        return rate;
    }

    function name(bytes calldata) public view override returns (string memory) {
        return token.name();
    }

    function symbol(bytes calldata)
        public
        view
        override
        returns (string memory)
    {
        return token.symbol();
    }

    function getPrice() public view returns (uint256) {
        (uint256 _reserve0, uint256 _reserve1, ) = sushi.getReserves();
        address token0 = sushi.token0();
        if (address(token) == token0) {
            return (1e6 * _reserve0) / _reserve1;
        } else {
            return (1e6 * _reserve1) / _reserve0;
        }
    }
}
