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

  const collaterals = [
    {
      token: '0x32Cd5AA21a015339fF39Cb9ac283DF43fF4B8955',
      oracle: '0xD97B23732C232EAc02bDBEbdDB6a737a4C718d44'
    },
    {
      token: '0x5654C0B6DF8d31c95dc20533fC66296D8A093a89',
      oracle: '0x393Bc0F1bb048EFf8a3358B7D5a9Ca2019D0cBc5'
    },
    {
      token: '0x70A0587B7C6D2fdb35AFae97Cf716a3317bC5feB',
      oracle: '0xDF38bE79C01Cc1635e8FEa59f8F47f7c15b165F3'
    },
    {
      token: '0xD07F6e03DaC20d88E35Ba414C2CFcb6BFE934c99',
      oracle: '0xb8b2a6B855caC8e6634B9d242Ea01b80E9726f52'
    }
  ]

  this.WETH9Mock = await ethers.getContractFactory("WETH9Mock");
  // deploy weth
  this.weth = await this.WETH9Mock.deploy();
  await this.weth.deployed();
  console.info("weth:", this.weth.address);


  // 1.get ERC20Mock
  this.ERC20Mock = await ethers.getContractFactory("ERC20Mock");

  // deploy
  // this.collateral = await this.ERC20Mock.deploy(
  //     "TEST-TOKEN", "WBTC",
  // );
  // await this.collateral.deployed();
  // await this.collateral.mint(this.alice.address, '1000000000000000000000000000000000')

  // 2. deploy clink
  this.Clink = await ethers.getContractFactory(
    "Clink"
  );
  this.clink = await this.Clink.deploy();
  await this.clink.deployed();
  console.info("clink:", this.clink.address);
  await (await this.clink.mint(this.alice.address, "0xffffffffffffffffffffffffffffffffffffffffff")).wait()

  // 3. deploy tokenVault
  this.TokenVault = await ethers.getContractFactory("TokenVault");
  this.tokenVault = await this.TokenVault.deploy(this.weth.address);
  await this.tokenVault.deployed();
  console.info("tokenVault:", this.tokenVault.address);
  await (await this.clink.approve(this.tokenVault.address, "0xffffffffffffffffffffffffffffffffffffffffff")).wait()

  // 4.deploy master core
  this.Core = await ethers.getContractFactory("Core");
  this.masterContract = await this.Core.deploy(
    this.tokenVault.address,
    this.clink.address
  );
  await this.masterContract.deployed();
  console.info("masterContract :", this.masterContract.address);

  for (const item of collaterals) {
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
        item.token,
        item.oracle,
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
    const core = this.Core.attach(coreAddress);
    console.info("core :", core.address);
    await (await this.tokenVault.deposit(this.clink.address, this.alice.address, core.address, "100000000000000000000000", "0")).wait()
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
