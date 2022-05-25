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
  this.provider = waffle.provider;

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

  this.portfolio = this.Portfolio.attach('0xfb827c0974ad266066249eb29f65df5b3b1f742b');

  this.parseSignature = (signature) => {
    const parsedSignature = signature.substring(2);

    const r = parsedSignature.substring(0, 64);
    const s = parsedSignature.substring(64, 128);
    const v = parsedSignature.substring(128, 130);

    return {
      r: "0x" + r,
      s: "0x" + s,
      v: parseInt(v, 16),
    };
  };

  //
  this.getApproveData = async (account) => {
    const verifyingContract = await this.tokenVault.address;
    const masterContract = (await this.portfolio.masterContract()).toString();
    const nonce = await this.tokenVault.nonces(account);
    const chainId = this.provider._network.chainId;

    const domain = {
      name: "TokenVault V1",
      chainId,
      verifyingContract,
    };

    // The named list of all type definitions
    const types = {
      SetMasterContractApproval: [
        { name: "warning", type: "string" },
        { name: "user", type: "address" },
        { name: "masterContract", type: "address" },
        { name: "approved", type: "bool" },
        { name: "nonce", type: "uint256" },
      ],
    };

    // The data to sign
    const value = {
      warning: "Give FULL access to funds in (and approved to) TokenVault?",
      user: account,
      masterContract,
      approved: true,
      nonce: +nonce.toString(),
    };
    console.log(chainId);

    let signature;

    try {
      signature = await this.alice._signTypedData(domain, types, value);
    } catch (e) {
      console.log("SIG ERR:", e.code);
      if (e.code === -32603) {
        return "ledger";

        // this.$store.commit("setPopupState", {
        //   type: "device-error",
        //   isShow: true,
        // });
      }
      return false;
    }
    const parsedSignature = this.parseSignature(signature);

    return ethers.utils.defaultAbiCoder.encode(
      ["address", "address", "bool", "uint8", "bytes32", "bytes32"],
      [account, masterContract, true, parsedSignature.v, parsedSignature.r, parsedSignature.s]
    );
  };

  this.getBorrowEncode = (borrow, account) => {
    return ethers.utils.defaultAbiCoder.encode(["int256", "address"], [borrow, account]);
  };
  this.getDepositEncode = (tokenAddr, account, amount) => {
    return ethers.utils.defaultAbiCoder.encode(
      ["address", "address", "int256", "int256"],
      [tokenAddr, account, amount, "0"]
    );
  };
  this.getUpdateRateEncode = (tokenAddr) => {
    return ethers.utils.defaultAbiCoder.encode(
      ["address", "bool", "uint256", "uint256"],
      [tokenAddr, true, "0x00", "0x00"]
    );
  };
  this.getAddCollateralEncode = (tokenAddr, account, amount) => {
    return ethers.utils.defaultAbiCoder.encode(
      ["address", "int256", "address", "bool"],
      [tokenAddr, amount, account, false]
    );
  };
  this.getBentoWithdrawEncode = (tokenAddr, account, amount) => {
    return ethers.utils.defaultAbiCoder.encode(
      ["address", "address", "int256", "int256"],
      [tokenAddr, account, amount, "0x0"]
    );
  };

  // await this.WBTC.approve(
  //   (await this.tokenVault.address).toString(),
  //   "0xffffffffffffffffffffffffffffffffffffffffffffff"
  // );
  // await this.WETH.approve(
  //   (await this.tokenVault.address).toString(),
  //   "0xffffffffffffffffffffffffffffffffffffffffffffff"
  // );

  // get approve data
  const approveData = await this.getApproveData(this.alice.address);
  console.info(approveData);

  const borrowEncode = this.getBorrowEncode("150000000000000000000", this.alice.address);

  const test1DepositEncode = this.getDepositEncode(
    this.WBTC.address,
    this.alice.address,
    "100000000000000000000"
  );

  const test2DepositEncode = this.getDepositEncode(
    this.WETH.address,
    this.alice.address,
    "100000000000000000000"
  );

  const test1AddEncode = this.getAddCollateralEncode(
    this.WBTC.address,
    this.alice.address,
    "100000000000000000000"
  );

  const test2AddEncode = this.getAddCollateralEncode(
    this.WETH.address,
    this.alice.address,
    "100000000000000000000"
  );

  const withdrawData = this.getBentoWithdrawEncode(
    this.clink.address,
    this.alice.address,
    "140000000000000000000"
  );

  const updateEncode1 = this.getUpdateRateEncode(this.WBTC.address);
  const updateEncode2 = this.getUpdateRateEncode(this.WETH.address);

  console.info((await this.clink.balanceOf(this.alice.address)).toString());

  
  const result = await this.portfolio.cook(
    [11, 11, 24, 20, 20, 10, 10, 5, 21],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [
      updateEncode1,
      updateEncode2,
      approveData,
      test1DepositEncode,
      test2DepositEncode,
      test1AddEncode,
      test2AddEncode,
      borrowEncode,
      withdrawData,
    ]
  );

  console.info((await this.clink.balanceOf(this.alice.address)).toString());

  console.info(result);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
