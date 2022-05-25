// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// const hre = require("hardhat");
const { network, ethers, waffle} = require("hardhat");

async function main() {


  this.network = network;
  this.signers = await ethers.getSigners();
  this.alice = this.signers[0];
  
  this.WBTCOracle = await ethers.getContractFactory("WbtcOracle");
  this.btcOracle = await this.WBTCOracle.deploy();
  await this.btcOracle.deployed();
  console.info(this.btcOracle.address)

  this.OracleMock = await ethers.getContractFactory("OracleMockV2");
  this.oracle = await this.OracleMock.deploy();
  await this.oracle.deployed();
  console.info(this.oracle.address)
  await this.oracle.setOracle(this.btcOracle.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
