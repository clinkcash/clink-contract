# Develop

## goerli test address 

#### nft:
```

 pair: wbtc-weth
  weth : 0x32Cd5AA21a015339fF39Cb9ac283DF43fF4B8955
  wbtc : 0x5654C0B6DF8d31c95dc20533fC66296D8A093a89
  
 lpnftManager 0xC36442b4a4522E871399CD717aBDD847Ab11FE88
 clink  0x23B1E638F43B96C7c9CEafd70A92A91F347BA6Dc
 tokenVault  0xFc03AA054eE9d7fB61019e95907ee1feb02b0Ac6
 aggregator  0x23cc8cd17977d45e3043979912d8236ec9cf850a
 priceHelper  0x39C810D755864FBbF6f4984760EC7038A216423F
 masterContract  0x50d3f033252e9832de0adc3609c663b90e06dd4a
 nFTVault  0xc4Df77E2cceB1eF0ed0224Cc68359dF984D4C6e8
```
test process:
1. add LP pair: wbtc-weth
2. set lpnftManager Approve for nFTVault
3. borrow

uniswap: https://app.uniswap.org/#/pool?chain=goerli

#### mix:
```
clink: 0x23B1E638F43B96C7c9CEafd70A92A91F347BA6Dc
tokenVault: 0xFc03AA054eE9d7fB61019e95907ee1feb02b0Ac6
masterContract : 0x7f5957a4d30b4CC2CF0a160e73f36Ce7cB303f0b
Mix : 0xE0aCCAfF6D13d5858C0Ffa857a0eCcb01D4593D3

```
#### core:
```
tokenvault :0x77D194fA029b7B415241dedeffCBb19e8b012570
tokens:
clink : 0x23B1E638F43B96C7c9CEafd70A92A91F347BA6Dc
Fontana: 0x0ce4a807c963c09C63BCCd3f732591fe4629012f
sFontana: 0x93f93573FBC53bCE406886E6B3FDCf47E7beFB22

weth : 0x32Cd5AA21a015339fF39Cb9ac283DF43fF4B8955
wbtc : 0x5654C0B6DF8d31c95dc20533fC66296D8A093a89
usdt:0xD07F6e03DaC20d88E35Ba414C2CFcb6BFE934c99

masterContract:
masterContract : 0xe2d38A358Cc2118Cce291aD85E2148226c016220

cores:
weth-core:0x36bDcFCFe2A879E23178Fee8F81Ab64f9fF5E0b7
wbtc-core : 0x81190FB92289B0e68e90609d3c42EB171557216a
usdt-core:0xb66b1376fC8Db4BB13c6B09FdA6D5e2989dC9400

oracles:
weth-oracle:0x95488E3988E66BAEDFaC328b79C79E5F1e778140
wbtc-oracle : 0xc4F62bb197c7F2753C151B48e02f63F5ad6744f4
usdt-oracle: 0xb8b2a6B855caC8e6634B9d242Ea01b80E9726f52

sorbettiere: 0x8691112Ffc7B305d313110d827499646e8571D64

pairs:
weth-usdt:0x12bcF97b855514441e5BBD3fD9a5fdbC2398C14d
wbtc-usdt:0x8c3C98a5c3F1dF08749cE564cA88369a6D99Ec40
clink-usdt:0x5D7C0F872c792A53d594E84AFD0B7EE06721e478
weth-ftn: 0x2DB9A312922Eeeea95e627C3474ba1D4395c12D9
weth-clink: 0xde72a63e852881FA09c27a989DBa0516949Ea0e1

uniswap:https://app.uniswap.org/#/swap?chain=goerli
weth in tokenvault: 0x146cCE28E076a43c02065B0695F27470aCb5715E
```
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
