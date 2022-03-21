// const {expect} = require("chai");
const {ethers, waffle, network} = require("hardhat");
describe("demo", function () {
    before(async function () {
        this.network = network;
        this.signers = await ethers.getSigners();
        this.alice = this.signers[0];
        this.bob = this.signers[1];
        this.carol = this.signers[2];
        this.dev = this.signers[3];
        this.minter = this.signers[4];
        this.provider = waffle.provider;

        // Hardhat always runs the compile task when running scripts with its command
        // line interface.
        //
        // If this script is run directly using `node` you may want to call compile
        // manually to make sure everything is compiled
        // await hre.run('compile');

        this.WETH9Mock = await ethers.getContractFactory("WETH9Mock");
        // 部署初始金额全部mint给msg.sender
        this.weth = await this.WETH9Mock.deploy();
        await this.weth.deployed();

        // 部署命令 npx hardhat run ./scripts/deploy.js --network kovan
        // 1.获取ERC20Mock
        this.ERC20Mock = await ethers.getContractFactory("ERC20Mock");

        // 部署初始金额全部mint给msg.sender
        this.collateral = await this.ERC20Mock.deploy(
            "TEST-TOKEN", "WBTC",
        );
        await this.collateral.deployed();
        this.collateral.mint(this.alice.address, '1000000000000000000000000000000000')

        // 2. 部署MIM
        this.Clink = await ethers.getContractFactory(
            "Clink"
        );
        this.clink = await this.Clink.deploy();
        await this.clink.deployed();

        // 3. 部署tokenVault
        this.TokenVault = await ethers.getContractFactory("TokenVault");
        this.tokenVault = await this.TokenVault.deploy(this.weth.address);
        await this.tokenVault.deployed();

        // 4.部署master core
        this.Core = await ethers.getContractFactory("Core");
        this.masterContract = await this.Core.deploy(
            this.tokenVault.address,
            this.clink.address
        );
        await this.masterContract.deployed();

        // 5.部署oracle
        this.OracleMock = await ethers.getContractFactory("OracleMock");
        this.oracle = await this.OracleMock.deploy();
        await this.oracle.deployed();

        // *6.设置oracle的初始 价格
        await this.oracle.set("1000000000000000000");

        // 7.deploy具体的 weth-clink core
        // 下面开始构 具体的weth-clink core 相关参数
        const INTEREST_CONVERSION = 1e18 / (365.25 * 3600 * 24) / 100;
        const interest = parseInt(String(2 * INTEREST_CONVERSION));
        const OPENING_CONVERSION = 1e5 / 100;
        const opening = 0.5 * OPENING_CONVERSION;
        const liquidation = 10 * 1e3 + 1e5;
        const collateralization = 85 * 1e3;

        // 编码
        const initData = ethers.utils.defaultAbiCoder.encode(
            [
                "address",
                "address",
                "bytes",
                "uint64",
                "uint256",
                "uint256",
                "uint256",
            ],
            [
                this.collateral.address,
                this.oracle.address,
                "0x0000000000000000000000000000000000000000",
                interest,
                liquidation,
                collateralization,
                opening,
            ]
        );

        // 发送交易 deploy
        const tx = await (
            await this.tokenVault.deploy(this.masterContract.address, initData, true)
        ).wait();

        // 从交易事件中获取具体的cauldron address
        const deployEvent = tx?.events?.[0];
        const coreAddress = deployEvent?.args?.cloneAddress;
        this.core = this.Core.attach(coreAddress);

        // 8. 部署具体的swapper，里面逻辑简单写了一下，
        this.SimpleSwapperMock = await ethers.getContractFactory(
            "SimpleSwapperMock"
        );
        this.swapper = await this.SimpleSwapperMock.deploy(
            this.clink.address,
            this.collateral.address,
            this.oracle.address,
            this.tokenVault.address,
            this.core.address
        );
        await this.swapper.deployed();

        // 9.设置core的初始资金
        await this.clink.mint(this.alice.address, "100000000000000000000000");
        await this.clink.approve(this.tokenVault.address, "0xffffffffffffffffffffffffffffffffffffffffff");
        await this.tokenVault.deposit(this.clink.address, this.alice.address, this.core.address, "100000000000000000000000", "0");

        // 10. 下面是给swapper 转一些mim weth进去，免得调用swapper 换币的时候，报错
        await this.clink.mint(this.swapper.address, "100000000000000000000000");

        await this.collateral.transfer(
            this.swapper.address,
            "100000000000000000000000000000"
        );

        console.info("weth:", this.weth.address);
        console.info("collateral:", this.collateral.address);
        console.info("clink:", this.clink.address);
        console.info("tokenVault:", this.tokenVault.address);
        console.info("oracle:", this.oracle.address);
        console.info("masterContract :", this.masterContract.address);
        console.info("core :", this.core.address);
        console.info("swapper:", this.swapper.address);

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
            const masterContract = (
                await this.core.masterContract()
            ).toString();
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
                [
                    account,
                    masterContract,
                    true,
                    parsedSignature.v,
                    parsedSignature.r,
                    parsedSignature.s,
                ]
            );
        };

        this.getBorrowEncode = (borrow, account) => {
            return ethers.utils.defaultAbiCoder.encode(
                ["int256", "address"],
                [borrow, account]
            );
        };
        this.getDepositEncode = (tokenAddr, account, amount) => {
            return ethers.utils.defaultAbiCoder.encode(
                ["address", "address", "int256", "int256"],
                [tokenAddr, account, amount, "0"]
            );
        };
        this.getUpdateRateEncode = () => {
            return ethers.utils.defaultAbiCoder.encode(
                ["bool", "uint256", "uint256"],
                [true, "0x00", "0x00"]
            );
        };
        this.getAddCollateralEncode = (account, amount) => {
            return ethers.utils.defaultAbiCoder.encode(
                ["int256", "address", "bool"],
                [amount, account, false]
            );
        };
        this.getBentoWithdrawEncode = (pairToken, account, amount) => {
            return ethers.utils.defaultAbiCoder.encode(
                ["address", "address", "int256", "int256"],
                [pairToken, account, amount, "0x0"]
            );
        };
    });

    it("ddCollateral and borrow ", async function () {
        // get collateral
        // await this.collateral.mint({value: '1000000000000000000000'});
        const bal = await this.collateral.balanceOf(this.alice.address);
        console.info(bal);

        console.info((await this.clink.balanceOf(this.alice.address)).toString());

        // await this.clink.transfer(
        //   this.core.address,
        //   "1000000000000000000000000000"
        // );

        // approve eth
        await this.collateral.approve(
            (await this.tokenVault.address).toString(),
            "0xffffffffffffffffffffffffffffffffffffffffffffff"
        );

        // get approve data
        const approveData = await this.getApproveData(this.alice.address);
        console.info(approveData);

        const borrowEncode = this.getBorrowEncode("10000000", this.alice.address);

        const depositEncode = this.getDepositEncode(
            this.collateral.address,
            this.alice.address,
            "100000000000000000000000"
        );

        const colateralEncode = this.getAddCollateralEncode(
            this.alice.address,
            "100000000000000000000000"
        );

        const withdrawData = this.getBentoWithdrawEncode(
            this.clink.address,
            this.alice.address,
            "1000000"
        );

        const updateEncode = this.getUpdateRateEncode();

        const result = await this.core.cook(
            [11, 24, 20, 10, 5, 21],
            [0, 0, 0, 0, 0, 0],
            [
                updateEncode,
                approveData,
                depositEncode,
                colateralEncode,
                borrowEncode,
                withdrawData,
            ]
        );

        console.info((await this.clink.balanceOf(this.alice.address)).toString());

        console.info(result);
    });

    it(" deploy new core ", async function () {




        this.erc20 = await this.ERC20Mock.deploy(
            "TEST-TOKEN", "TEST",
        );
        await this.erc20.deployed();
        this.erc20.mint(this.alice.address, '1000000000000000000000000000000000')

        // 下面开始构 具体的weth-clink core 相关参数
        const INTEREST_CONVERSION = 1e18 / (365.25 * 3600 * 24) / 100;
        const interest = parseInt(String(2 * INTEREST_CONVERSION));
        const OPENING_CONVERSION = 1e5 / 100;
        const opening = 0.5 * OPENING_CONVERSION;
        const liquidation = 10 * 1e3 + 1e5;
        const collateralization = 85 * 1e3;

        // 编码
        const initData = ethers.utils.defaultAbiCoder.encode(
            [
                "address",
                "address",
                "bytes",
                "uint64",
                "uint256",
                "uint256",
                "uint256",
            ],
            [
                this.erc20.address,
                this.oracle.address,
                "0x0000000000000000000000000000000000000000",
                interest,
                liquidation,
                collateralization,
                opening,
            ]
        );

        // 发送交易 deploy
        const tx = await (
            await this.tokenVault.deploy(this.masterContract.address, initData, true)
        ).wait();

        // 从交易事件中获取具体的cauldron address
        const deployEvent = tx?.events?.[0];
        const coreAddress = deployEvent?.args?.cloneAddress;
        this.core1 = this.Core.attach(deployEvent?.args?.cloneAddress);

        await this.clink.mint(this.alice.address, "100000000000000000000000");
        await this.tokenVault.deposit(this.clink.address, this.alice.address, this.core1.address, "100000000000000000000000", "0");


        // get collateral
        // await this.collateral.mint({value: '1000000000000000000000'});
        const bal = await this.erc20.balanceOf(this.alice.address);
        console.info(bal);

        console.info((await this.clink.balanceOf(this.alice.address)).toString());

        // await this.clink.transfer(
        //   this.core.address,
        //   "1000000000000000000000000000"
        // );

        // approve eth
        await this.erc20.approve(this.tokenVault.address, "0xffffffffffffffffffffffffffffffffffffffffffffff");

        // get approve data
        const approveData = await this.getApproveData(this.alice.address);
        console.info(approveData);

        const borrowEncode = this.getBorrowEncode("10000000", this.alice.address);

        const depositEncode = this.getDepositEncode(
            this.erc20.address,
            this.alice.address,
            "100000000000000000000000"
        );

        const colateralEncode = this.getAddCollateralEncode(
            this.alice.address,
            "100000000000000000000000"
        );

        const withdrawData = this.getBentoWithdrawEncode(
            this.clink.address,
            this.alice.address,
            "1000000"
        );

        const updateEncode = this.getUpdateRateEncode();

        const result = await this.core1.cook(
            [11, 24, 20, 10, 5, 21],
            [0, 0, 0, 0, 0, 0],
            [
                updateEncode,
                approveData,
                depositEncode,
                colateralEncode,
                borrowEncode,
                withdrawData,
            ]
        );

        console.info((await this.clink.balanceOf(this.alice.address)).toString());

        console.info(result);
    });

    it("liquidation ", async function () {
        // get collateral
        // await this.collateral.mint({value: '1000000000000000000000'});
        const bal = await this.collateral.balanceOf(this.alice.address);
        console.info("weth", bal.toString());

        console.info(
            "clink",
            (await this.clink.balanceOf(this.alice.address)).toString()
        );

        // await this.clink.transfer(
        //   this.core.address,
        //   "1000000000000000000000000000"
        // );

        // approve eth
        await this.collateral.approve(
            (await this.tokenVault.address).toString(),
            "0xffffffffffffffffffffffffffffffffffffffffffffff"
        );

        // get approve data
        const approveData = await this.getApproveData(this.alice.address);
        console.info(approveData);

        const borrowEncode = this.getBorrowEncode(
            "500000000000000000000",
            this.alice.address
        );

        const depositEncode = this.getDepositEncode(
            this.collateral.address,
            this.alice.address,
            "1000000000000000000000"
        );

        const colateralEncode = this.getAddCollateralEncode(
            this.alice.address,
            "1000000000000000000000"
        );

        const withdrawData = this.getBentoWithdrawEncode(
            this.clink.address,
            this.alice.address,
            "500000000000000000000"
        );

        const updateEncode = this.getUpdateRateEncode();

        console.info(
            "clink",
            (await this.clink.balanceOf(this.alice.address)).toString()
        );
        await this.core.cook(
            [11, 24, 20, 10, 5, 21],
            [0, 0, 0, 0, 0, 0],
            [
                updateEncode,
                approveData,
                depositEncode,
                colateralEncode,
                borrowEncode,
                withdrawData,
            ]
        );

        console.info(
            "clink",
            (await this.clink.balanceOf(this.alice.address)).toString()
        );

        console.info("init asset");
        console.info(
            (
                await this.tokenVault.balanceOf(this.clink.address, this.alice.address)
            ).toString()
        );

        console.info(
            (
                await this.tokenVault.balanceOf(this.collateral.address, this.alice.address)
            ).toString()
        );

        console.info("set rate");

        // await this.oracle.set("110000000000000");
        // await this.core.liquidate(
        //   [this.alice.address],
        //   ["100000000000000000000"],
        //   this.alice.address,
        //   this.swapper.address
        // );
        //
        // console.info(
        //   (
        //     await this.tokenVault.balanceOf(this.clink.address, this.alice.address)
        //   ).toString()
        // );
        //
        // console.info(
        //   (
        //     await this.tokenVault.balanceOf(this.collateral.address, this.alice.address)
        //   ).toString()
        // );

        await this.oracle.set("1695000000000000000");
        await this.core.liquidate(
            [this.alice.address],
            ["100000000000000000000"],
            this.swapper.address,
            this.swapper.address
        );

        console.info(
            (
                await this.tokenVault.balanceOf(this.clink.address, this.alice.address)
            ).toString()
        );

        console.info(
            (
                await this.tokenVault.balanceOf(this.collateral.address, this.alice.address)
            ).toString()
        );
    });
});
