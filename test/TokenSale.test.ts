import type { SnapshotRestorer } from "@nomicfoundation/hardhat-network-helpers";
import { takeSnapshot } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import type {
    SignerWithAddress
    // , ERC20Mock
} from "@nomiclabs/hardhat-ethers/signers";

import type { TokenSale } from "../typechain-types";
// const { snapshot, constants, time } = require("../helpers");
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("TokenSale", function () {
    const DAY = 24 * 3600;
    const tokenToTokenRatio = 1;
    const tokenToEthRatio = 2;


    let snapshotA: SnapshotRestorer;

    // Signers.
    let deployer: SignerWithAddress, owner: SignerWithAddress, user: SignerWithAddress;
    let bob: SignerWithAddress, alice: SignerWithAddress, eve: SignerWithAddress;
    // hardhat private key

    let tokenSale: any;
    let saleToken: any;
    let currencyToken: any;

    before(async () => {
        const START_TIME = (await time.latest()) + 1 * DAY;
        const END_TIME = (await time.latest()) + 10 * DAY;
        const totalSaleAmount = ethers.utils.parseEther("100000");

        // Getting of signers.
        [deployer, user, bob, alice, eve] = await ethers.getSigners();

        const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
        saleToken = await ERC20Mock.deploy();
        currencyToken = await ERC20Mock.deploy();
        await saleToken.deployTransaction.wait();
        await currencyToken.deployTransaction.wait();

        const TokenSale = await ethers.getContractFactory("TokenSale");
        tokenSale = await upgrades.deployProxy(TokenSale, [
            START_TIME,
            END_TIME,
            tokenToTokenRatio,
            tokenToEthRatio,
            saleToken.address,
            currencyToken.address
        ]);
        await tokenSale.deployed();

        let balance = await saleToken.balanceOf(deployer.address);

        await saleToken.approve(tokenSale.address, totalSaleAmount);
        await tokenSale.setSaleAmount(totalSaleAmount);

        owner = deployer;
        snapshotA = await takeSnapshot();
    });

    afterEach(async () => await snapshotA.restore());

    describe("TokenSale test", function () {
        it.only("Should pass all expect", async () => {
            let amount = ethers.utils.parseEther("10");
            const tokenAmount = ethers.utils.parseEther("10");

            await currencyToken.mint(alice.address, tokenAmount);
            await currencyToken.connect(alice).approve(tokenSale.address, tokenAmount);

            const balanceBefore = await saleToken.balanceOf(alice.address);
            expect(balanceBefore).to.be.eq(0);

            //time travel
            let further = (await time.latest()) + DAY * 2;
            await time.increaseTo(further);

            let tx_purchaseTokenEth = await tokenSale.connect(alice).purchaseTokenEth({ value: amount });
            let purchasedTokenAmountBefore = await tokenSale.purchasedTokenAmount(alice.address);
            expect(purchasedTokenAmountBefore).to.be.eq(amount.mul(tokenToEthRatio));

            let tx_purchaseToken = await tokenSale.connect(alice).purchaseToken(tokenAmount);
            let purchasedTokenAmount = await tokenSale.purchasedTokenAmount(alice.address);

            expect(purchasedTokenAmount.sub(purchasedTokenAmountBefore)).to.be.eq(tokenAmount);

            further = (await time.latest()) + DAY * 20;
            await time.increaseTo(further);
            let tx_claim = await tokenSale.connect(alice).claim();

            const balanceAfter = await saleToken.balanceOf(alice.address);

            expect(balanceAfter).to.be.eq(purchasedTokenAmount);

            let purchasedTokenAmountAfter = await tokenSale.purchasedTokenAmount(alice.address);
            expect(purchasedTokenAmountAfter).to.be.eq(0);

            await expect(tx_purchaseTokenEth).to.emit(tokenSale, "TokensEarned");
            await expect(tx_purchaseToken).to.emit(tokenSale, "TokensEarned");
            await expect(tx_claim).to.emit(tokenSale, "TokensClaimed");
        });
    });
});
