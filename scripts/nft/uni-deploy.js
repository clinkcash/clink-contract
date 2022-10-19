const hre = require("hardhat");
const { ethers, waffle, upgrades } = require("hardhat");

async function main() {
    this.signers = await ethers.getSigners()
    this.alice = this.signers[0]


    const tokenVaultAddr = '0x77D194fA029b7B415241dedeffCBb19e8b012570'
    const clinkAddr = '0x23B1E638F43B96C7c9CEafd70A92A91F347BA6Dc'

    const nft = '0xC36442b4a4522E871399CD717aBDD847Ab11FE88';

    const weth = '0x32Cd5AA21a015339fF39Cb9ac283DF43fF4B8955'
    const wbtc = '0x5654C0B6DF8d31c95dc20533fC66296D8A093a89'


    this.NFT = await ethers.getContractFactory("NFTMock")
    this.nft = await this.NFT.attach(nft)
    console.info(" nft ", this.nft.address)


    this.Clink = await ethers.getContractFactory("Clink");
    this.clink = this.Clink.attach(clinkAddr);
    console.info(" clink ", this.clink.address)


    this.TokenVault = await ethers.getContractFactory("TokenVault");
    this.tokenVault = this.TokenVault.attach(tokenVaultAddr);
    console.info(" tokenVault ", this.tokenVault.address)

    this.AggregatorMock = await ethers.getContractFactory("AggregatorMock");

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

    await (await this.priceHelper.addWhiteList(weth, wbtc)).wait()


    this.NFTVault = await ethers.getContractFactory("NFTVault")

    this.masterContract = await this.NFTVault.deploy(this.clink.address, this.tokenVault.address)
    await this.masterContract.deployed();
    console.info(" masterContract ", this.masterContract.address)


    const vaultSettings = [[100, 10000000000000], [40, 100], [50, 100], [10, 100], [1, 100], [10, 100], 86400]


    const initData = ethers.utils.defaultAbiCoder.encode(
        ["uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "address", "address"],
        [
            100, 10000000000000, 40, 100, 50, 100, 10, 100, 1, 100, 10, 100, 86400,
            nft,
            this.priceHelper.address
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

    const priceUsd = await this.priceHelper.getNFTValueUSD(nft,29913)
    console.info(priceUsd)
    // console.info(await this.nft.ownerOf(29820))

    // await (await this.nft.setApprovalForAll(this.nFTVault.address, true)).wait()
    // await (await this.nft.approve(this.nFTVault.address, 29820)).wait()
    // console.info(await this.nft.isApprovedForAll(this.alice.address,this.nFTVault.address))
    // console.info(this.alice.address)

    // await (await this.nFTVault.borrow(29913, "1000000000000000000000", false)).wait()
    

    // console.info(await this.tokenVault.balanceOf(this.clink.address, this.alice.address))
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });