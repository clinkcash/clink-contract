const hre = require("hardhat");
const { ethers, waffle, upgrades } = require("hardhat");

async function main() {
    this.signers = await ethers.getSigners()
    this.alice = this.signers[0]


    const tokenVaultAddr = '0xFc03AA054eE9d7fB61019e95907ee1feb02b0Ac6'
    const clinkAddr = '0x23B1E638F43B96C7c9CEafd70A92A91F347BA6Dc'


    this.NFT = await ethers.getContractFactory("NFTMock")
    this.nft = await this.NFT.deploy("TEST", "TEST")
    await this.nft.deployed();
    console.info(" nft ", this.nft.address)

    this.WETH9Mock = await ethers.getContractFactory("WETH9Mock");


    this.Clink = await ethers.getContractFactory("Clink");
    this.clink = this.Clink.attach(clinkAddr);
    console.info(" clink ", this.clink.address)


    this.TokenVault = await ethers.getContractFactory("TokenVault");
    this.tokenVault = this.TokenVault.attach(tokenVaultAddr);
    console.info(" tokenVault ", this.tokenVault.address)



    this.AggregatorV3Mock = await ethers.getContractFactory("AggregatorV3Mock");
    this.aggregator = await this.AggregatorV3Mock.deploy();
    await this.aggregator.deployed();
    console.info(" aggregator ", this.aggregator.address)


    this.PriceHelper = await ethers.getContractFactory("PriceHelper")
    this.priceHelper = await this.PriceHelper.deploy(this.aggregator.address)
    await this.priceHelper.deployed();
    console.info(" priceHelper ", this.priceHelper.address)

    const vaultSettings = [[100, 10000000000000], [40, 100], [50, 100], [10, 100], [1, 100], [10, 100], 86400, '0xfffffffffffffffffffffffffffffffffffff']
    this.NFTVault = await ethers.getContractFactory("NFTVault")

    this.nFTVault = await this.NFTVault.deploy(this.clink.address, this.tokenVault.address, this.nft.address, this.priceHelper.address, vaultSettings)
    await this.nFTVault.deployed();
    console.info(" nFTVault ", this.nFTVault.address)

    //init
    await (await this.tokenVault.whitelistMasterContract(this.nFTVault.address, true)).wait();
    await (await this.priceHelper.addNFTCollection(this.nft.address, this.aggregator.address, [])).wait()
    await (await this.clink.mint(this.alice.address, "100000000000000000000000")).wait();
    await (await this.clink.approve(this.tokenVault.address, "0xffffffffffffffffffffffffffffffffffffffffff")).wait()
    await (await this.tokenVault.deposit(this.clink.address, this.alice.address, this.nFTVault.address, "100000000000000000000000", "0")).wait()
    await (await this.tokenVault.setMasterContractApproval(this.alice.address, this.nFTVault.address, true, 0, "0x0000000000000000000000000000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000000000000000000000000000")).wait()
    await (await this.nft.mint(this.alice.address)).wait()
    await (await this.nft.setApprovalForAll(this.nFTVault.address, true)).wait()
    await (await this.nFTVault.borrow(0, "1000000000000000000000", false)).wait()

    console.info(await this.tokenVault.balanceOf(this.clink.address, this.alice.address))
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });