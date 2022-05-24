const { network, ethers, waffle} = require("hardhat");


async function main() {
    this.network = network;
    this.signers = await ethers.getSigners();
    this.alice = this.signers[0];

   
    const ftnAddress = '0x5a06e2Ab09A40B5D31f2AB7818652c1d1b50F0D0';
    

    //Sorbettiere
    const Sorbettiere = await ethers.getContractFactory("Sorbettiere");
    
    const ftnPerSecond = '10000000000000000000'//10*1e18.toString();
    const startTime = Date.now() / 1000 | 0;

    console.log(" startTime is :", startTime);

    const sorbettiere = await Sorbettiere.deploy(ftnAddress, ftnPerSecond, startTime);
    await sorbettiere.deployed();
    
    console.log("sorbettiere deployed to:", sorbettiere.address);
  }
  
main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});