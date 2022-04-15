const { network, ethers, waffle} = require("hardhat");


async function main() {
    this.network = network;
    this.signers = await ethers.getSigners();
    this.alice = this.signers[0];

    // We get the contract to deploy
    const Ftn = await ethers.getContractFactory("Ftn");
    const ftn = await Ftn.deploy();
  
    await ftn.deployed();
  
    console.log("ftn deployed to:", ftn.address);

    //Sorbettiere
    const Sorbettiere = await ethers.getContractFactory("Sorbettiere");
    
    const ftnPerSecond = '10000000000000000000'//10*1e18.toString();
    const startTime = Date.now() / 1000 | 0;

    console.log(" startTime is :", startTime);

    const sorbettiere = await Sorbettiere.deploy(ftn.address, ftnPerSecond, startTime);
    await sorbettiere.deployed();
    
    console.log("sorbettiere deployed to:", sorbettiere.address);
  }
  
main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});