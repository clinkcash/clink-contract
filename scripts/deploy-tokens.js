// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// const hre = require("hardhat");
const { network, ethers, waffle } = require("hardhat");

async function main() {

  this.network = network;
  this.signers = await ethers.getSigners();
  this.alice = this.signers[0];
  // 1.get ERC20Mock
  this.ERC20Mock = await ethers.getContractFactory("ERC20MockV2");

  const data = [
    {
      symbol: "WBTC",
      decimals: 18,
    },
    {
      symbol: "WETH",
      decimals: 18,
    },
    {
      symbol: "FTN",
      decimals: 18,
    },
    {
      symbol: "USDT",
      decimals: 6,
    }
  ]
  

  for (const item of data) {
    // deploy
    this.collateral = await this.ERC20Mock.deploy(
      item.symbol, item.symbol, item.decimals
    );
    await this.collateral.deployed();
    await (await this.collateral.mint(this.alice.address, '1000000000000000000000000000000000')).wait()
    console.info(item.symbol, " : ", this.collateral.address)
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
