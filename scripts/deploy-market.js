
const { network, ethers, waffle} = require("hardhat");

const MinimumAskPrice = "1000000000000000"
const MaximumAskPrice= "10000000000000000000000"

const WETH = "0x32Cd5AA21a015339fF39Cb9ac283DF43fF4B8955"

const main = async () => {
  // Get network name: hardhat, testnet or mainnet.
  const networkName = network.name;
  
  const [deployer] = await ethers.getSigners();

  console.log(`Deploying to ${networkName} network...`);
  console.log("Deploying contracts with the account:", deployer.address);
  

  // Deploy contract
  const ERC721NFTMarketV1 = await ethers.getContractFactory("ERC721NFTMarketV1");

  const contract = await ERC721NFTMarketV1.deploy(
    deployer.address,
    deployer.address,
    WETH,
    MinimumAskPrice,
    MaximumAskPrice
  );

  // Wait for the contract to be deployed before exiting the script.
  await contract.deployed();
  console.log(`Deployed to ${contract.address}`);
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
