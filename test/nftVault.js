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

        this.AggregatorV3Mock = await ethers.getContractFactory("AggregatorV3Mock");
        this.aggregator = await this.AggregatorV3Mock.deploy();
        await this.aggregator.deployed();
        console.info(" aggregator ", this.aggregator.address)


        // this.PriceHelper = await ethers.getContractFactory("UniLPPriceHelper")
        // this.priceHelper = await this.PriceHelper.deploy(this.aggregator.address)
        // await this.priceHelper.deployed();
        // console.info(" priceHelper ", this.priceHelper.address)


        this.NFTVault = await ethers.getContractFactory("NFTVault")

        this.masterContract = await this.NFTVault.deploy(this.clink.address, this.tokenVault.address)
        await this.masterContract.deployed();
        console.info(" masterContract ", this.masterContract.address)


        const vaultSettings = [[100, 10000000000000], [40, 100], [50, 100], [10, 100], [1, 100], [10, 100], 86400]


        const initData = ethers.utils.defaultAbiCoder.encode(
            ["uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "address", "address"],
            [
                100, 10000000000000, 40, 100, 50, 100, 10, 100, 1, 100, 10, 100, 86400,
                this.nft.address,
                this.nft.address
            ]
        );
        // send deploy tx
        const tx = await (
            await this.tokenVault.deploy(this.masterContract.address, initData, true)
        ).wait();

        // get core address from tx event
        const deployEvent = tx?.events?.[0];
        const coreAddress = deployEvent?.args?.cloneAddress;
        this.nFTVault = this.NFTVault.attach(coreAddress);
        console.info(" nFTVault ", this.nFTVault.address)


    })


    it("brrow", async function () {
        // await this.priceHelper.addNFTCollection(this.nft.address, this.aggregator.address, [])
        // await this.clink.mint(this.alice.address, "100000000000000000000000");
        // await this.clink.approve(this.tokenVault.address, "0xffffffffffffffffffffffffffffffffffffffffff");
        // await this.tokenVault.deposit(this.clink.address, this.alice.address, this.nFTVault.address, "100000000000000000000000", "0");
        // await this.tokenVault.setMasterContractApproval(this.alice.address, this.nFTVault.address, true, 0, "0x0000000000000000000000000000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000000000000000000000000000")
        // await this.nft.mint(this.alice.address)
        // await this.nft.setApprovalForAll(this.nFTVault.address, true)

        // await this.nFTVault.borrow(0, "1000000000000000000000", false)

        // console.info(await this.tokenVault.balanceOf(this.clink.address, this.alice.address))

    });

});
