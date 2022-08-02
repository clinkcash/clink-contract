const hre = require("hardhat");
const { ethers, waffle, upgrades } = require("hardhat");

async function main() {
    this.signers = await ethers.getSigners()
    this.alice = this.signers[0]


    const tokenVaultAddr = '0xFc03AA054eE9d7fB61019e95907ee1feb02b0Ac6'
    const clinkAddr = '0x23B1E638F43B96C7c9CEafd70A92A91F347BA6Dc'

    const nft = '0xC36442b4a4522E871399CD717aBDD847Ab11FE88';

    const weth = '0x32Cd5AA21a015339fF39Cb9ac283DF43fF4B8955'
    const wbtc = '0x5654C0B6DF8d31c95dc20533fC66296D8A093a89'

    const uniPriceHelperAddr = '0x942A7C155CA3152F0d139F22Cde975F4a0805bA9'
    const nFTVaultAddr = '0xc4Df77E2cceB1eF0ed0224Cc68359dF984D4C6e8'


    // this.NFT = await ethers.getContractFactory("NFTMock")
    // this.nft = await this.NFT.attach("TEST", "TEST")
    // await this.nft.deployed();
    // console.info(" nft ", this.nft.address)


    this.Clink = await ethers.getContractFactory("Clink");
    this.clink = this.Clink.attach(clinkAddr);
    console.info(" clink ", this.clink.address)


    this.TokenVault = await ethers.getContractFactory("TokenVault");
    this.tokenVault = this.TokenVault.attach(tokenVaultAddr);
    console.info(" tokenVault ", this.tokenVault.address)

    // this.AggregatorV3Mock = await ethers.getContractFactory("AggregatorV3Mock");
    // this.aggregator = await this.AggregatorV3Mock.deploy();
    // await this.aggregator.deployed();
    // console.info(" aggregator ", this.aggregator.address)

    this.UniLPPriceHelper = await ethers.getContractFactory("UniLPPriceHelper")
    this.priceHelper = await this.UniLPPriceHelper.attach(uniPriceHelperAddr)
    console.info(" priceHelper ", this.priceHelper.address)

    this.NFTVault = await ethers.getContractFactory("NFTVault")
    this.nFTVault = await this.NFTVault.attach(nFTVaultAddr)
    console.info(" nFTVault ", this.nFTVault.address)

    // const priceUsd = await this.priceHelper.getNFTValueUSD(nft,29820)
    // console.info(priceUsd)

    // //init
    // await (await this.tokenVault.whitelistMasterContract(this.nFTVault.address, true)).wait();
    // await (await this.priceHelper.addNFTCollection(this.nft.address, this.aggregator.address, [])).wait()
    // await (await this.clink.mint(this.alice.address, "100000000000000000000000")).wait();
    // await (await this.clink.approve(this.tokenVault.address, "0xffffffffffffffffffffffffffffffffffffffffff")).wait()
    // await (await this.tokenVault.deposit(this.clink.address, this.alice.address, this.nFTVault.address, "100000000000000000000000", "0")).wait()
    // await (await this.tokenVault.setMasterContractApproval(this.alice.address, this.nFTVault.address, true, 0, "0x0000000000000000000000000000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000000000000000000000000000")).wait()
    // await (await this.nft.mint(this.alice.address)).wait()
    // await (await this.nft.setApprovalForAll(this.nFTVault.address, true)).wait()
    await (await this.nFTVault.borrow(29820, "1000000000000000000000", false)).wait()

    // console.info(await this.tokenVault.balanceOf(this.clink.address, this.alice.address))
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });