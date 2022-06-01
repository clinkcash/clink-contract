# Develop

# goerli test address

```
tokenvault :0x6BB4929267f2030632C64D4701E0F6805aD100B4
tokens:
clink : 0x23B1E638F43B96C7c9CEafd70A92A91F347BA6Dc

weth : 0x32Cd5AA21a015339fF39Cb9ac283DF43fF4B8955
wbtc : 0x5654C0B6DF8d31c95dc20533fC66296D8A093a89
ftn:0x70A0587B7C6D2fdb35AFae97Cf716a3317bC5feB
usdt:0xD07F6e03DaC20d88E35Ba414C2CFcb6BFE934c99

masterContract:
masterContract : 0x24A602bF9afF8aC2541B65e22AB97Ea91BB72d78

cores:
weth-core:0xdAfbA96f89c0F75474B015A59B9Cc4BC07d85628
wbtc-core : 0x65FC0cdDb04800079Cfd9e3fC84B877236Bbc853
ftn-core:0xDe3bbF3AcfB29b153e4f378cd999611abBC2cF51
usdt-core:0x1493B8DaE402b4b951070cceAA852275eFb4bA86

oracles:
weth-oracle:0xD97B23732C232EAc02bDBEbdDB6a737a4C718d44
wbtc-oracle : 0x393Bc0F1bb048EFf8a3358B7D5a9Ca2019D0cBc5
ftn-oracle : 0xDF38bE79C01Cc1635e8FEa59f8F47f7c15b165F3
usdt-oracle: 0xb8b2a6B855caC8e6634B9d242Ea01b80E9726f52

pairs:
weth-usdt:0xe115A33533FF97e5DF983c96C33EbC4D8C397a83
wbtc-usdt:0x7c04EE9F127eA8C0d813B143e36668731ab80869
ftn-usdt:0xBc9E0FA65a6e899e9263bFeA42790cbdFe03A204
```

# kovan test address

```
tokenvault :0xcb6e3bb46db170f8b9b3d026b19b4ff638577639
tokens:
clink : 0xCb8A8F4721b9b8e4487d88a838BcD31b08E466c0

weth : 0xaD0D6B4da4D3150cd947b1Fc7b33567ba6c593bA
wbtc : 0xA783432Cb869AF5979357209f9e49a17e395cDcc
ftn:0x5a06e2Ab09A40B5D31f2AB7818652c1d1b50F0D0
usdt:0xC7C9665340cE2f3393A358184ba734b32E27cE73

masterContract:
masterContract : 0x6BB4929267f2030632C64D4701E0F6805aD100B4

cores:
wbtc-core : 0xcf397a162b6930403e60334a29c93b1abf70eb0b
ftn-core:0x8fcBaC0B8A38d3dC3fC691eb99086326e59b5484
usdt-core:0xe8522996C56BD5Fdb31ee558397C8F537e0Bf5D3
weth-core:0x70EAbEDA3c96d26Ea34a0c871C69130A02972d53

swappers:
wbtc-swapper : 0x6775cE026E34c6633a098e9790DeCf49F71Bc029
cSushi-swapper : 0x9559CBC0A4F240533B0B20302a806FD722F61eb8

oracles:
wbtc-oracle : 0x5654C0B6DF8d31c95dc20533fC66296D8A093a89
ftn-oracle : 0x39ea7cDdD8cf0f39c23B32348A069023A3cC9444
usdt-oracle:0x432F1491e72453a65328D035C9487a764ce3062e
weth-oracle:0x531110484aF39BEE9b6Ace07dF5be0f41268DEA5

exchange url:
csushi <-> clk : https://app.uniswap.org/#/swap?chain=kovan

how to get wbtc?
can mint wbtc on the opensource mock contract in kovan scan
```

### rinkeby test address

```
weth: 0xa977088F01218A17cC76B7ab0cdc4Ad08DEFb9C2
wbtc: 0x044d5401EE010A78f7E3799533b955f585522cFA
clink: 0x000c978d290D32192642f90A7bf77baC95De8567
tokenVault: 0x3E52D4BFE370DB56cA28E772C2C81cB7DeeccA44
oracle: 0x51635993b4C01F17D11543a92804e0cD7a03cBbf
masterContract : 0x3F5Be5F60E298eddE2Df5e0337d7690De0064ed0
core : 0x10bd432a812c017178259a6c45e64c8e7009bfd1
swapper: 0xd2115Cb101b7aA2e9d7c1FD825EE27E5A69FCce7
```

### goerli test address

```
weth: 0xa977088F01218A17cC76B7ab0cdc4Ad08DEFb9C2
wbtc: 0x044d5401EE010A78f7E3799533b955f585522cFA
clink: 0x000c978d290D32192642f90A7bf77baC95De8567
tokenVault: 0x3E52D4BFE370DB56cA28E772C2C81cB7DeeccA44
oracle: 0x51635993b4C01F17D11543a92804e0cD7a03cBbf
masterContract : 0x3F5Be5F60E298eddE2Df5e0337d7690De0064ed0
core : 0x10bd432a812c017178259a6c45e64c8e7009bfd1
swapper: 0xd2115Cb101b7aA2e9d7c1FD825EE27E5A69FCce7
```

# Clink

a lending platform that uses interest-bearing tokens as collateral to borrow a USD pegged stablecoin (Clink), that can
be used as any other traditional stablecoin.

## contracts

- Clink : the USD pegged stablecoin
- Core : Each Lending Market has a dedicated smart contract. These smart contracts are called core and allow users to
  open loans, borrow Clinks, leverage and repay.
- TokenVault : Contract for custody of assets, including Clink, collateral, etc

## Project setup

```
npm install
```

## deploy command

```
npx hardhat run ./scripts/deploy.js --network kovan
```

## Hardhat Project Scripts

This project demonstrates an advanced Hardhat use case, integrating other tools commonly used alongside Hardhat in the
ecosystem.

The project comes with a sample contract, a test for that contract, a sample script that deploys that contract, and an
example of a task implementation, which simply lists the available accounts. It also comes with a variety of other
tools, preconfigured to work with the project code.

Try running some of the following tasks:

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
npx hardhat help
REPORT_GAS=true npx hardhat test
npx hardhat coverage
npx hardhat run scripts/deploy.js
node scripts/deploy.js
npx eslint '**/*.js'
npx eslint '**/*.js' --fix
npx prettier '**/*.{json,sol,md}' --check
npx prettier '**/*.{json,sol,md}' --write
npx solhint 'contracts/**/*.sol'
npx solhint 'contracts/**/*.sol' --fix
```

## Etherscan verification

To try out Etherscan verification, you first need to deploy a contract to an Ethereum network that's supported by
Etherscan, such as Ropsten.

In this project, copy the .env.example file to a file named .env, and then edit it to fill in the details. Enter your
Etherscan API key, your Ropsten node URL (eg from Alchemy), and the private key of the account which will send the
deployment transaction. With a valid .env file in place, first deploy your contract:

```shell
hardhat run --network ropsten scripts/deploy.js
```

Then, copy the deployment address and paste it in to replace `DEPLOYED_CONTRACT_ADDRESS` in this command:

```shell
npx hardhat verify --network ropsten DEPLOYED_CONTRACT_ADDRESS "Hello, Hardhat!"
```

## Licence

UNLICENCED
