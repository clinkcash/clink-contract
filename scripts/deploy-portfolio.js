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

  // 0x257079b5dB460CEaf0FFFF9223117627C74d0048
  // 0x503222489864adE0444BF17781B3a292450149D8
  // deploy weth

  this.ERC20Mock = await ethers.getContractFactory("ERC20Mock");

  this.WBTC = await this.ERC20Mock.attach("0xA783432Cb869AF5979357209f9e49a17e395cDcc");
  this.USDT = await this.ERC20Mock.attach("0xC7C9665340cE2f3393A358184ba734b32E27cE73");
  this.WETH = await this.ERC20Mock.attach("0xaD0D6B4da4D3150cd947b1Fc7b33567ba6c593bA");

  this.Clink = await ethers.getContractFactory("Clink");
  this.clink = await this.Clink.attach('0xCb8A8F4721b9b8e4487d88a838BcD31b08E466c0')

  this.TokenVault = await ethers.getContractFactory("TokenVault");
  this.tokenVault = await this.TokenVault.attach("0xcb6e3bb46db170f8b9b3d026b19b4ff638577639")

  this.Portfolio = await ethers.getContractFactory("Portfolio");
  this.masterContract = await this.Portfolio.attach('0x443fc512f2cbe5ec50109601a2780c2a95b6dc0f')
  // this.masterContract = await this.Portfolio.deploy(this.tokenVault.address, this.clink.address);
  // await this.masterContract.deployed();

  const INTEREST_CONVERSION = 1e18 / (365.25 * 3600 * 24) / 100;
  const interest = parseInt(String(2 * INTEREST_CONVERSION));
  const OPENING_CONVERSION = 1e5 / 100;
  const opening = 0 * OPENING_CONVERSION;
  const liquidation = 10 * 1e3 + 1e5;
  const collateralization = 85 * 1e3;

  const initData = ethers.utils.defaultAbiCoder.encode(
    ["address", "address", "bytes", "uint64", "uint256", "uint256", "uint256"],
    [
      this.WBTC.address,
      '0x503222489864adE0444BF17781B3a292450149D8',
      "0x0000000000000000000000000000000000000000",
      interest,
      liquidation,
      collateralization,
      opening,
    ]
  );

  // const tx = await (await this.tokenVault.deploy(this.masterContract.address, initData, true)).wait();

  // const deployEvent = tx?.events?.[0];
  // const coreAddress = deployEvent?.args?.cloneAddress;
  this.portfolio = this.Portfolio.attach('0xfb827c0974ad266066249eb29f65df5b3b1f742b');

  await (await this.portfolio.addCollateralToken(
    this.USDT.address,
    '0x432F1491e72453a65328D035C9487a764ce3062e',
    "0x0000000000000000000000000000000000000000"
  )).wait();

  await (await this.portfolio.addCollateralToken(
    this.WETH.address,
    '0x531110484aF39BEE9b6Ace07dF5be0f41268DEA5',
    "0x0000000000000000000000000000000000000000"
  )).wait();

  // await this.clink.mint(this.alice.address, "208000000000000000000000");
  await (await this.clink.approve(this.tokenVault.address, "0xffffffffffffffffffffffffffffffffffffffffff")).wait();
  await (await this.tokenVault.deposit(
    this.clink.address,
    this.alice.address,
    this.portfolio.address,
    "208000000000000000000000",
    "0"
  )).wait();

  console.info("clink:", this.clink.address);
  console.info("tokenVault:", this.tokenVault.address);
  console.info("masterContract :", this.masterContract.address);
  console.info("Portfolio :", this.portfolio.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
