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
  this.OracleV3 = await ethers.getContractFactory("OracleMockV3");
  this.OracleV1 = await ethers.getContractFactory("OracleMock");

  const data = [
    {
      token: "0x32Cd5AA21a015339fF39Cb9ac283DF43fF4B8955",
      pair: "0x12bcF97b855514441e5BBD3fD9a5fdbC2398C14d",
    }, {
      token: "0x5654C0B6DF8d31c95dc20533fC66296D8A093a89",
      pair: '0x8c3C98a5c3F1dF08749cE564cA88369a6D99Ec40'
    }
  ]

  for (const item of data) {
    this.oracle = await this.OracleV3.deploy(
      item.token, item.pair
    );
    await this.oracle.deployed();
    console.info("oracle : ", this.oracle.address)
  }
  // this.oracle = await this.OracleV1.deploy();
  // await this.oracle.set('1000000000000000000')
  // console.info("oracle : ", this.oracle.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
