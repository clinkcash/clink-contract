const { network, ethers, waffle} = require("hardhat");

const ftnAddress = '0x0ce4a807c963c09C63BCCd3f732591fe4629012f';

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