const { network, ethers, waffle} = require("hardhat");

const ftnAddress = '0x5a06e2Ab09A40B5D31f2AB7818652c1d1b50F0D0';

async function main() {
    this.network = network;
    this.signers = await ethers.getSigners();
    this.alice = this.signers[0];

    // We get the contract to deploy
    const sFontana = await ethers.getContractFactory("sFontana");
    const sftn = await sFontana.deploy(ftnAddress);
  
    await sftn.deployed();
  
    console.log("sftn deployed to:", sftn.address);

    
  }
  
main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});