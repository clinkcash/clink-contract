// const {expect} = require("chai");
const {ethers, waffle, network} = require("hardhat");
describe("demo", function () {
    before(async function () {
        this.network = network;
        this.signers = await ethers.getSigners();
        this.alice = this.signers[0];
        this.provider = waffle.provider;

        // Hardhat always runs the compile task when running scripts with its command
        // line interface.
        //
        // If this script is run directly using `node` you may want to call compile
        // manually to make sure everything is compiled
        // await hre.run('compile');

        this.WETH9Mock = await ethers.getContractFactory("WETH9Mock");
        // deploy weth
        this.weth = await this.WETH9Mock.deploy();
        await this.weth.deployed();

        this.ERC20Mock = await ethers.getContractFactory("ERC20Mock");

        this.TEST1 = await this.ERC20Mock.deploy("TEST-TOKEN", "TEST1");
        await this.TEST1.deployed();
        this.TEST1.mint(this.alice.address, "1000000000000000000000000000000000");

        this.TEST2 = await this.ERC20Mock.deploy("TEST-TOKEN", "TEST2");
        await this.TEST2.deployed();
        this.TEST2.mint(this.alice.address, "1000000000000000000000000000000000");

        this.Clink = await ethers.getContractFactory("Clink");
        this.clink = await this.Clink.deploy();
        await this.clink.deployed();

        this.TokenVault = await ethers.getContractFactory("TokenVault");
        this.tokenVault = await this.TokenVault.deploy(this.weth.address);
        await this.tokenVault.deployed();

        this.Portfolio = await ethers.getContractFactory("Portfolio");
        this.masterContract = await this.Portfolio.deploy(this.tokenVault.address, this.clink.address);
        await this.masterContract.deployed();

        this.OracleMock = await ethers.getContractFactory("OracleMock");
        this.oracle = await this.OracleMock.deploy();
        await this.oracle.deployed();

        await this.oracle.set("1000000000000000000");

        const INTEREST_CONVERSION = 1e18 / (365.25 * 3600 * 24) / 100;
        const interest = parseInt(String(2 * INTEREST_CONVERSION));
        const OPENING_CONVERSION = 1e5 / 100;
        const opening = 0 * OPENING_CONVERSION;
        const liquidation = 10 * 1e3 + 1e5;
        const collateralization = 85 * 1e3;

        const initData = ethers.utils.defaultAbiCoder.encode(
            ["address", "address", "bytes", "uint64", "uint256", "uint256", "uint256"],
            [
                this.TEST1.address,
                this.oracle.address,
                "0x0000000000000000000000000000000000000000",
                interest,
                liquidation,
                collateralization,
                opening,
            ]
        );

        const tx = await (await this.tokenVault.deploy(this.masterContract.address, initData, true)).wait();

        const deployEvent = tx?.events?.[0];
        const coreAddress = deployEvent?.args?.cloneAddress;
        this.portfolio = this.Portfolio.attach(coreAddress);

        await this.portfolio.addCollateralToken(
            this.TEST2.address,
            this.oracle.address,
            "0x0000000000000000000000000000000000000000"
        );

        await this.clink.mint(this.alice.address, "208000000000000000000000");
        await this.clink.approve(this.tokenVault.address, "0xffffffffffffffffffffffffffffffffffffffffff");
        await this.tokenVault.deposit(
            this.clink.address,
            this.alice.address,
            this.portfolio.address,
            "208000000000000000000000",
            "0"
        );

        console.info("weth:", this.weth.address);
        console.info("TEST1:", this.TEST1.address);
        console.info("TEST2:", this.TEST2.address);
        console.info("clink:", this.clink.address);
        console.info("tokenVault:", this.tokenVault.address);
        console.info("oracle:", this.oracle.address);
        console.info("masterContract :", this.masterContract.address);
        console.info("Portfolio :", this.Portfolio.address);

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

        //
        this.getApproveData = async (account) => {
            const verifyingContract = await this.tokenVault.address;
            const masterContract = (await this.portfolio.masterContract()).toString();
            const nonce = await this.tokenVault.nonces(account);
            const chainId = this.provider._network.chainId;

            const domain = {
                name: "TokenVault V1",
                chainId,
                verifyingContract,
            };

            // The named list of all type definitions
            const types = {
                SetMasterContractApproval: [
                    {name: "warning", type: "string"},
                    {name: "user", type: "address"},
                    {name: "masterContract", type: "address"},
                    {name: "approved", type: "bool"},
                    {name: "nonce", type: "uint256"},
                ],
            };

            // The data to sign
            const value = {
                warning: "Give FULL access to funds in (and approved to) TokenVault?",
                user: account,
                masterContract,
                approved: true,
                nonce: +nonce.toString(),
            };
            console.log(chainId);

            let signature;

            try {
                signature = await this.alice._signTypedData(domain, types, value);
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

            return ethers.utils.defaultAbiCoder.encode(
                ["address", "address", "bool", "uint8", "bytes32", "bytes32"],
                [account, masterContract, true, parsedSignature.v, parsedSignature.r, parsedSignature.s]
            );
        };

        this.getBorrowEncode = (borrow, account) => {
            return ethers.utils.defaultAbiCoder.encode(["int256", "address"], [borrow, account]);
        };
        this.getDepositEncode = (tokenAddr, account, amount) => {
            return ethers.utils.defaultAbiCoder.encode(
                ["address", "address", "int256", "int256"],
                [tokenAddr, account, amount, "0"]
            );
        };
        this.getUpdateRateEncode = (tokenAddr) => {
            return ethers.utils.defaultAbiCoder.encode(
                ["address", "bool", "uint256", "uint256"],
                [tokenAddr, true, "0x00", "0x00"]
            );
        };
        this.getAddCollateralEncode = (tokenAddr, account, amount) => {
            return ethers.utils.defaultAbiCoder.encode(
                ["address", "int256", "address", "bool"],
                [tokenAddr, amount, account, false]
            );
        };
        this.getBentoWithdrawEncode = (tokenAddr, account, amount) => {
            return ethers.utils.defaultAbiCoder.encode(
                ["address", "address", "int256", "int256"],
                [tokenAddr, account, amount, "0x0"]
            );
        };
    });

    it("ddCollateral and borrow ", async function () {
        // get collateral
        // await this.collateral.mint({value: '1000000000000000000000'});

        console.info((await this.clink.balanceOf(this.alice.address)).toString());

        // await this.clink.transfer(
        //   this.core.address,
        //   "1000000000000000000000000000"
        // );

        // approve collateral
        await this.TEST1.approve(
            (await this.tokenVault.address).toString(),
            "0xffffffffffffffffffffffffffffffffffffffffffffff"
        );
        await this.TEST2.approve(
            (await this.tokenVault.address).toString(),
            "0xffffffffffffffffffffffffffffffffffffffffffffff"
        );

        // get approve data
        const approveData = await this.getApproveData(this.alice.address);
        console.info(approveData);

        const borrowEncode = this.getBorrowEncode("170000000000000000000000", this.alice.address);

        const test1DepositEncode = this.getDepositEncode(
            this.TEST1.address,
            this.alice.address,
            "100000000000000000000000"
        );

        const test2DepositEncode = this.getDepositEncode(
            this.TEST2.address,
            this.alice.address,
            "100000000000000000000000"
        );

        const test1AddEncode = this.getAddCollateralEncode(
            this.TEST1.address,
            this.alice.address,
            "100000000000000000000000"
        );

        const test2AddEncode = this.getAddCollateralEncode(
            this.TEST2.address,
            this.alice.address,
            "100000000000000000000000"
        );

        const withdrawData = this.getBentoWithdrawEncode(
            this.clink.address,
            this.alice.address,
            "168000000000000000000000"
        );

        const updateEncode1 = this.getUpdateRateEncode(this.TEST1.address);
        const updateEncode2 = this.getUpdateRateEncode(this.TEST2.address);

        console.info((await this.clink.balanceOf(this.alice.address)).toString());

        const result = await this.portfolio.cook(
            [11, 11, 24, 20, 20, 10, 10, 5, 21],
            [0, 0, 0, 0, 0, 0, 0, 0, 0],
            [
                updateEncode1,
                updateEncode2,
                approveData,
                test1DepositEncode,
                test2DepositEncode,
                test1AddEncode,
                test2AddEncode,
                borrowEncode,
                withdrawData,
            ]
        );

        console.info((await this.clink.balanceOf(this.alice.address)).toString());

        console.info(result);
    });
});
