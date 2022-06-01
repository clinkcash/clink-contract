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
  const usdt = '0xD07F6e03DaC20d88E35Ba414C2CFcb6BFE934c99'

  const data = [
    {
      token: "0x32Cd5AA21a015339fF39Cb9ac283DF43fF4B8955",
      pair: "0xe115A33533FF97e5DF983c96C33EbC4D8C397a83",
    }, {
      token: "0x5654C0B6DF8d31c95dc20533fC66296D8A093a89",
      pair: '0x7c04EE9F127eA8C0d813B143e36668731ab80869'
    }, {
      token: "0x70A0587B7C6D2fdb35AFae97Cf716a3317bC5feB",
      pair: '0xBc9E0FA65a6e899e9263bFeA42790cbdFe03A204'
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
