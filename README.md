# Develop

### kovan test address

```
tokenvault :0x97be1ca3a78ee3d9eacfe1ed8bb64bf14a8a9e03
tokens:
weth : 0xaD0D6B4da4D3150cd947b1Fc7b33567ba6c593bA
wbtc : 0xA783432Cb869AF5979357209f9e49a17e395cDcc
clink : 0xCb8A8F4721b9b8e4487d88a838BcD31b08E466c0
ftn:0x5a06e2Ab09A40B5D31f2AB7818652c1d1b50F0D0
usdt:0xC7C9665340cE2f3393A358184ba734b32E27cE73

masterContract:
mix : 0x51bD96a9d774cE7ed753e57d474B600Fa44D810D

cores:
wbtc/weth/usdt-core:0xfFb1CA288CDE25BB8de249F60515D9d816E679E2

oracles:
wbtc-oracle : 0x503222489864adE0444BF17781B3a292450149D8(0x257079b5dB460CEaf0FFFF9223117627C74d0048)
ftn-oracle : 0x39ea7cDdD8cf0f39c23B32348A069023A3cC9444
usdt-oracle:0x432F1491e72453a65328D035C9487a764ce3062e
weth-core:0x531110484aF39BEE9b6Ace07dF5be0f41268DEA5

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
