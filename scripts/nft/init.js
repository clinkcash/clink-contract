const hre = require("hardhat");
const { ethers, waffle, upgrades } = require("hardhat");

async function main() {
    this.signers = await ethers.getSigners()
    this.alice = this.signers[0]


    const tokenVaultAddr = '0xFc03AA054eE9d7fB61019e95907ee1feb02b0Ac6'
    const clinkAddr = '0x23B1E638F43B96C7c9CEafd70A92A91F347BA6Dc'


    this.NFT = await ethers.getContractFactory("NFTMock")
    this.nft = await this.NFT.attach("0x723864E0609500BF41993B93850C52a926e47498")
    console.info(" nft ", this.nft.address)


    this.Clink = await ethers.getContractFactory("Clink");
    this.clink = this.Clink.attach(clinkAddr);
    console.info(" clink ", this.clink.address)

    this.TokenVault = await ethers.getContractFactory("TokenVault");
    this.tokenVault = this.TokenVault.attach(tokenVaultAddr);
    console.info(" tokenVault ", this.tokenVault.address)



    const vaultSettings = [[100, 10000000000000], [40, 100], [50, 100], [10, 100], [1, 100], [10, 100], 86400, '0xffffffffffffffffffffffffffffffff']
    this.NFTVault = await ethers.getContractFactory("NFTVault")
    this.nFTVault = this.NFTVault.attach('0x750eF79357719f2c388144389F083933848C6331');
    console.info(" nFTVault ", this.nFTVault.address)

    //init
    
    // await this.tokenVault.deposit(this.clink.address, this.alice.address, this.nFTVault.address, "100000000000000000000000", "0");
    // await this.tokenVault.setMasterContractApproval(this.alice.address, this.nFTVault.address, true, 0, "0x0000000000000000000000000000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000000000000000000000000000")
    // await this.nft.mint(this.alice.address)
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