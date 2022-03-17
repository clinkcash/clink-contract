/* eslint-disable @typescript-eslint/no-non-null-assertion */

require("@nomiclabs/hardhat-waffle");

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
        localhost: {
            live: false,
            saveDeployments: true,
            tags: ["local"],
        },
        kovan: {
            url: `https://kovan.infura.io/v3/${process.env.INFURA_API_KEY}`,
            accounts,
            chainId: 42,
            live: true,
            saveDeployments: true,
            tags: ["staging"],
        },
    },
    mocha: {
        timeout: 500000,
        bail: true,
    },
    solidity: {
        compilers: [
            {
                version: "0.6.12",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: "0.8.4",
            },
            {
                version: "0.8.6",
            },
            {
                version: "0.8.7",
            },
            {
                version: "0.8.9",
            },
            {
                version: "0.8.10",
            },
            {
                version: "0.7.6",
            },
        ]
    }
};

