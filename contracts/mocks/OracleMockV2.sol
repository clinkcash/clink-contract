// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/IOracle.sol";

// WARNING: This oracle is only for testing, please use PeggedOracle for a fixed value oracle
contract OracleMockV2 is IOracle {
    bool public testMode; // true return the rate ,false return the oracle value
    uint256 public rate;
    bool public success;
    IOracle public oracle;

    constructor() {
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
            return oracle.get(data);
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
            return oracle.peek(data);
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
            return oracle.peekSpot(data);
        }
        return rate;
    }

    function setOracle(address _oracle) public {
        // The rate can be updated.
        oracle = IOracle(_oracle);
    }

    function name(bytes calldata) public view override returns (string memory) {
        return "Test";
    }

    function symbol(bytes calldata)
        public
        view
        override
        returns (string memory)
    {
        return "TEST";
    }
}
