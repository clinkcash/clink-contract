/* eslint-disable @typescript-eslint/no-non-null-assertion */

require("@nomiclabs/hardhat-waffle");
require('hardhat-contract-sizer');
require("@nomiclabs/hardhat-etherscan");
require('solidity-coverage')

const accounts = {
    mnemonic: "test test test test test test test test test test test junk",
};
module.exports = {
    defaultNetwork: "hardhat",
    abiExporter: {
        path: "./abi",
        clear: false,
        flat: true,
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
        alice: {
            default: 1,
        },
        bob: {
            default: 2,
        },
        carol: {
            default: 3,
        },
    },
    networks: {
        hardhat: {
            // allowUnlimitedContractSize:true,
        },
        localhost: {
            live: false,
            saveDeployments: true,
            tags: ["local"],
        },
        kovan: {
            url: "https://kovan.infura.io/v3/yourkey",
            accounts: [
                `the pri key`,
            ],
        },
    },
    mocha: {
        timeout: 500000,
        bail: true,
    },
    solidity: {
        compilers: [
            {
                version: "0.8.0",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: "0.8.4",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            }
        ]
    },
    contractSizer: {
        alphaSort: false,
        disambiguatePaths: false,
        runOnCompile: true,
        strict: true
    },

};

