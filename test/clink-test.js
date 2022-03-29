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
        this.provider = waffle.provider;

        this.parseSignature = (signature) => {
            const parsedSignature = signature.substring(2);

            const r = parsedSignature.substring(0, 64);
            const s = parsedSignature.substring(64, 128);
            const v = parsedSignature.substring(128, 130);

            return {
                r: "0x" + r,
                s: "0x" + s,
                v: parseInt(v, 16),
            };
        };

        this.getPermitData = async (account) => {
            const verifyingContract = await this.clink.address;
            const nonce = +(await this.clink.nonces(account)).toString();
            const chainId = this.provider._network.chainId;


            const owner = this.alice.address;
            const spender = this.bob.address;
            const value = '100000000000000000000000000000';
            const deadline = Math.floor(new Date() / 1000) + 6000;

            const domain = {
                name: "Clink stable coin",
                chainId,
                verifyingContract,
                version: '1'
            };

            // The named list of all type definitions
            const types = {
                Permit: [
                    {name: "owner", type: "address"},
                    {name: "spender", type: "address"},
                    {name: "value", type: "uint256"},
                    {name: "nonce", type: "uint256"},
                    {name: "deadline", type: "uint256"}
                ],
            };

            // The data to sign
            const value1 = {
                owner,
                spender,
                value,
                nonce,
                deadline
            };
            console.log(chainId);

            let signature;

            try {
                signature = await this.alice._signTypedData(domain, types, value1);
            } catch (e) {
                console.log("SIG ERR:", e.code);
                if (e.code === -32603) {
                    return "ledger";

                    // this.$store.commit("setPopupState", {
                    //   type: "device-error",
                    //   isShow: true,
                    // });
                }
                return false;
            }
            const parsedSignature = this.parseSignature(signature);
            return [owner,
                spender,
                value,
                deadline,
                parsedSignature.v,
                parsedSignature.r,
                parsedSignature.s,
            ]
        };
    });

    it("clink test", async function () {

        //mint
        await this.clink.mint(this.alice.address, "10000000000000000000000");
        expect(await this.clink.totalSupply()).to.equal("10000000000000000000000");
        expect(await this.clink.balanceOf(this.alice.address)).to.equal("10000000000000000000000");


        // burn
        await this.clink.burn("5000000000000000000000");
        expect(await this.clink.totalSupply()).to.equal("5000000000000000000000");
        expect(await this.clink.balanceOf(this.alice.address)).to.equal("5000000000000000000000");

        // permit
        const param = await this.getPermitData(this.alice.address);
        await this.clink.permit(...param)
        await this.clink.connect(this.bob).transferFrom(this.alice.address, this.bob.address, '50000000000');
        expect(await this.clink.balanceOf(this.bob.address)).to.equal("50000000000");

    });
});
