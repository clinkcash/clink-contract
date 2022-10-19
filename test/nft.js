const { expect } = require("chai");
const { ethers, upgrades, waffle } = require("hardhat");

describe("nft", function () {

    before(async function () {

        this.signers = await ethers.getSigners()
        this.alice = this.signers[0]

        this.NFT = await ethers.getContractFactory("NFTMock")
        this.nft = await this.NFT.deploy("TEST", "TEST")
        await this.nft.deployed();
        console.info(" nft ", this.nft.address)

        this.WETH9Mock = await ethers.getContractFactory("WETH9Mock");
        // deploy weth
        this.weth = await this.WETH9Mock.deploy();
        await this.weth.deployed();
        console.info(" weth ", this.weth.address)


        this.Clink = await ethers.getContractFactory("Clink");
        this.clink = await this.Clink.deploy();
        await this.clink.deployed();
        console.info(" clink ", this.clink.address)


        this.TokenVault = await ethers.getContractFactory("TokenVault");
        this.tokenVault = await this.TokenVault.deploy(this.weth.address);
        await this.tokenVault.deployed();
        console.info(" tokenVault ", this.tokenVault.address)

        this.AggregatorV3Mock = await ethers.getContractFactory("AggregatorMock");

    this.ethAggregator = await this.AggregatorMock.deploy("2000000000");
    await this.ethAggregator.deployed();
    console.info(" ethAggregator ", this.ethAggregator.address)

    this.btcAggregator = await this.AggregatorMock.deploy("20000000000");
    await this.btcAggregator.deployed();
    console.info(" btcAggregator ", this.btcAggregator.address)

    this.UniLPPriceHelper = await ethers.getContractFactory("UniLPPriceHelper")
    this.priceHelper = await this.UniLPPriceHelper.deploy(nft)
    await this.priceHelper.deployed();
    console.info(" priceHelper ", this.priceHelper.address)

    await (await this.priceHelper.addTokenAggregator(wbtc, this.btcAggregator.address)).wait()
    await (await this.priceHelper.addTokenAggregator(weth, this.ethAggregator.address)).wait()



        const vaultSettings = [[100, 10000000000000], [40, 100], [50, 100], [10, 100], [1, 100], [10, 100], 86400, '0xfffffffffffffffffffffffffffffffffffff']
        this.NFTVault = await ethers.getContractFactory("NFTVault")

        this.nFTVault = await this.NFTVault.deploy(this.clink.address, this.tokenVault.address, this.nft.address, this.priceHelper.address, vaultSettings)
        await this.nFTVault.deployed();
        console.info(" nFTVault ", this.nFTVault.address)

        //init
        await this.tokenVault.whitelistMasterContract(this.nFTVault.address, true);

    })


    it("brrow", async function () {
        await this.priceHelper.addNFTCollection(this.nft.address, this.aggregator.address, [])
        await this.clink.mint(this.alice.address, "100000000000000000000000");
        await this.clink.approve(this.tokenVault.address, "0xffffffffffffffffffffffffffffffffffffffffff");
        await this.tokenVault.deposit(this.clink.address, this.alice.address, this.nFTVault.address, "100000000000000000000000", "0");
        await this.tokenVault.setMasterContractApproval(this.alice.address, this.nFTVault.address, true, 0, "0x0000000000000000000000000000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000000000000000000000000000")
        await this.nft.mint(this.alice.address)
        await this.nft.setApprovalForAll(this.nFTVault.address, true)

        await this.nFTVault.borrow(0, "1000000000000000000000", false)

        console.info(await this.tokenVault.balanceOf(this.clink.address, this.alice.address))

    });

});
