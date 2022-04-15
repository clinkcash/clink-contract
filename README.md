# Develop

### kovan test address

```
tokenvault :0xcb6e3bb46db170f8b9b3d026b19b4ff638577639

tokens:
cSushi:0x3666360b44bd9b30de72fde64dcd5950297eb22e
weth  : 0xEd71B3FFe0BCe56046be1CC43baF585D2244F346
wbtc  : 0xA783432Cb869AF5979357209f9e49a17e395cDcc
clink : 0xCb8A8F4721b9b8e4487d88a838BcD31b08E466c0
ftn   : 0x5a06e2Ab09A40B5D31f2AB7818652c1d1b50F0D0

masterContract:
masterContract : 0x6BB4929267f2030632C64D4701E0F6805aD100B4

cores:
wbtc-core : 0xcf397a162b6930403e60334a29c93b1abf70eb0b
cSushi-core : 0xbDa6bF47Ec7591712023Cb4c1d3C6A65D8FA8852

swappers:
wbtc-swapper : 0x6775cE026E34c6633a098e9790DeCf49F71Bc029
cSushi-swapper : 0x9559CBC0A4F240533B0B20302a806FD722F61eb8

oracles:
wbtc-oracle : 0x5654C0B6DF8d31c95dc20533fC66296D8A093a89
csushi-oracle:0x398cb309980F6a24F1499c53e2D721eF7d6FB046

exchange url:
csushi <-> clk : https://app.uniswap.org/#/swap?chain=kovan

lp pool reward:
sorbettiere: 0x5de53aC41c4e81498abD55F09A9E78676DA7f39B


how to get wbtc?
can mint wbtc on the opensource mock contract in kovan scan
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


