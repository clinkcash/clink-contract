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

  const WETHMOCK = '0x146cCE28E076a43c02065B0695F27470aCb5715E'

  this.ERC20Mock = await ethers.getContractFactory("ERC20Mock");

  this.WBTC = await this.ERC20Mock.attach("0x5654C0B6DF8d31c95dc20533fC66296D8A093a89");
  this.USDT = await this.ERC20Mock.attach("0xD07F6e03DaC20d88E35Ba414C2CFcb6BFE934c99");
  this.WETH = await this.ERC20Mock.attach("0x32Cd5AA21a015339fF39Cb9ac283DF43fF4B8955");

  this.Clink = await ethers.getContractFactory("Clink");
  this.clink = await this.Clink.attach('0x23B1E638F43B96C7c9CEafd70A92A91F347BA6Dc')

  this.TokenVault = await ethers.getContractFactory("TokenVault");
  this.tokenVault = await this.TokenVault.deploy(WETHMOCK);
  await this.tokenVault.deployed();

  this.Mix = await ethers.getContractFactory("Mix");
  // this.masterContract = await this.Mix.attach('0xf99a76f00d73ff1f3c135048250046b462ca75f7')
  this.masterContract = await this.Mix.deploy(this.tokenVault.address, this.clink.address);
  await this.masterContract.deployed();

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
      '0xc4F62bb197c7F2753C151B48e02f63F5ad6744f4',
      "0x0000000000000000000000000000000000000000",
      interest,
      liquidation,
      collateralization,
      opening,
    ]
  );

  const tx = await (await this.tokenVault.deploy(this.masterContract.address, initData, true)).wait();

  const deployEvent = tx?.events?.[1];
  const coreAddress = deployEvent?.args?.cloneAddress;
  this.mix = this.Mix.attach(coreAddress);

  await (await this.mix.addCollateralToken(
    this.USDT.address,
    '0xb8b2a6B855caC8e6634B9d242Ea01b80E9726f52',
    "0x0000000000000000000000000000000000000000"
  )).wait();

  await (await this.mix.addCollateralToken(
    this.WETH.address,
    '0x95488E3988E66BAEDFaC328b79C79E5F1e778140',
    "0x0000000000000000000000000000000000000000"
  )).wait();

  // await this.clink.mint(this.alice.address, "208000000000000000000000");
  await (await this.clink.approve(this.tokenVault.address, "0xffffffffffffffffffffffffffffffffffffffffff")).wait();
  await (await this.tokenVault.deposit(
    this.clink.address,
    this.alice.address,
    this.mix.address,
    "208000000000000000000000",
    "0"
  )).wait();

  console.info("clink:", this.clink.address);
  console.info("tokenVault:", this.tokenVault.address);
  console.info("masterContract :", this.masterContract.address);
  console.info("Mix :", this.mix.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
