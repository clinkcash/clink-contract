/* eslint-disable @typescript-eslint/no-non-null-assertion */

require("@nomiclabs/hardhat-waffle");
require('hardhat-contract-sizer');
require("@nomiclabs/hardhat-etherscan");

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
            url: "https://kovan.infura.io/v3/938ec750ced64edda8fc17c9e135d0f6",
            accounts: [
                `b374d026f9d1f59232abaaf6836d281d3971315a130dbe15e58ba957632433bf`,
            ],
        },
    },
    etherscan: {
        apiKey: {
            kovan: 'YJBB6JRHGYXQ3JTWD1PWQ1NVAB13P7RGU6',
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

