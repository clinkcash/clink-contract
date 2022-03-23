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
  this.WETH9Mock = await ethers.getContractFactory("WETH9Mock");
  // deploy weth
  this.weth = await this.WETH9Mock.deploy();
  await this.weth.deployed();

  // 1.get ERC20Mock
  this.ERC20Mock = await ethers.getContractFactory("ERC20Mock");

  // deploy
  this.collateral = await this.ERC20Mock.deploy(
      "TEST-TOKEN", "WBTC",
  );
  await this.collateral.deployed();
  await this.collateral.mint(this.alice.address, '1000000000000000000000000000000000')

  // 2. deploy clink
  this.Clink = await ethers.getContractFactory(
      "Clink"
  );
  this.clink = await this.Clink.deploy();
  await this.clink.deployed();

  // 3. deploy tokenVault
  this.TokenVault = await ethers.getContractFactory("TokenVault");
  this.tokenVault = await this.TokenVault.deploy(this.weth.address);
  await this.tokenVault.deployed();

  // 4.deploy master core
  this.Core = await ethers.getContractFactory("Core");
  this.masterContract = await this.Core.deploy(
      this.tokenVault.address,
      this.clink.address
  );
  await this.masterContract.deployed();

  // 5.deploy oracle
  this.OracleMock = await ethers.getContractFactory("OracleMock");
  this.oracle = await this.OracleMock.deploy();
  await this.oracle.deployed();

  // *6.设置oracle的初始 价格
  await this.oracle.set("1000000000000000000");

  // 7.deploy  wbtc-clink core
  // init data
  const INTEREST_CONVERSION = 1e18 / (365.25 * 3600 * 24) / 100;
  const interest = parseInt(String(2 * INTEREST_CONVERSION));
  const OPENING_CONVERSION = 1e5 / 100;
  const opening = 0.5 * OPENING_CONVERSION;
  const liquidation = 10 * 1e3 + 1e5;
  const collateralization = 85 * 1e3;

  // encode
  const initData = ethers.utils.defaultAbiCoder.encode(
      [
        "address",
        "address",
        "bytes",
        "uint64",
        "uint256",
        "uint256",
        "uint256",
      ],
      [
        this.collateral.address,
        this.oracle.address,
        "0x0000000000000000000000000000000000000000",
        interest,
        liquidation,
        collateralization,
        opening,
      ]
  );

  // send deploy tx
  const tx = await (
      await this.tokenVault.deploy(this.masterContract.address, initData, true)
  ).wait();

  // get core address from tx event
  const deployEvent = tx?.events?.[0];
  const coreAddress = deployEvent?.args?.cloneAddress;
  this.core = this.Core.attach(coreAddress);

  // 8. deploy mock swapper
  this.SimpleSwapperMock = await ethers.getContractFactory(
      "SimpleSwapperMock"
  );
  this.swapper = await this.SimpleSwapperMock.deploy(
      this.clink.address,
      this.collateral.address,
      this.oracle.address,
      this.tokenVault.address,
      this.core.address
  );
  await this.swapper.deployed();

  // 9.init core clink
  await this.clink.mint(this.alice.address, "100000000000000000000000");
  await this.clink.approve(this.tokenVault.address, "0xffffffffffffffffffffffffffffffffffffffffff");
  await this.tokenVault.deposit(this.clink.address, this.alice.address, this.core.address, "100000000000000000000000", "0");

  // 10. mint clink to mock swapper
  await this.clink.mint(this.swapper.address, "100000000000000000000000");

  await this.collateral.transfer(
      this.swapper.address,
      "100000000000000000000000000000"
  );

  console.info("weth:", this.weth.address);
  console.info("collateral:", this.collateral.address);
  console.info("clink:", this.clink.address);
  console.info("tokenVault:", this.tokenVault.address);
  console.info("oracle:", this.oracle.address);
  console.info("masterContract :", this.masterContract.address);
  console.info("core :", this.core.address);
  console.info("swapper:", this.swapper.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
