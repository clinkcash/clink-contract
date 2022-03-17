const {expect} = require("chai");
const {ethers, waffle, network} = require("hardhat");

describe("Clink", function () {

    before(async function () {
        this.network = network;
        this.signers = await ethers.getSigners();
        this.alice = this.signers[0];
        this.bob = this.signers[1];
        this.carol = this.signers[2];
        const Clink = await ethers.getContractFactory("Clink");
        this.clink = await Clink.deploy();
        await this.clink.deployed();
    });

    it("Clink", async function () {

        await this.clink.mint(this.alice.address,"10000000000000000000000");
        expect(await this.clink.totalSupply()).to.equal("10000000000000000000000");
        expect(await this.clink.balanceOf(this.alice.address)).to.equal("10000000000000000000000");


        await this.clink.burn("5000000000000000000000");
        expect(await this.clink.totalSupply()).to.equal("5000000000000000000000");
        expect(await this.clink.balanceOf(this.alice.address)).to.equal("5000000000000000000000");

    });
});
