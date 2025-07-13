import { expect } from "chai";
import { ethers } from "hardhat";
import { SimpleSwap, TokenA, TokenB } from "../typechain-types";

describe("SimpleSwap", function () {
  let user: any;
  let tokenA: TokenA;
  let tokenB: TokenB;
  let simpleSwap: SimpleSwap;

  before(async () => {
    [owner, user] = await ethers.getSigners();

    const TokenAContractFactory = await ethers.getContractFactory("TokenA");
    tokenA = await TokenAContractFactory.deploy();

    const TokenBContractFactory = await ethers.getContractFactory("TokenB");
    tokenB = await TokenBContractFactory.deploy();

    const [tokenAAddress, tokenBAddress] = await Promise.all([tokenA.getAddress(), tokenB.getAddress()]);

    const SimpleSwapContractFactory = await ethers.getContractFactory("SimpleSwap");
    simpleSwap = await SimpleSwapContractFactory.deploy(tokenAAddress, tokenBAddress);
  });

  describe("addLiquidity", function () {
    it("Should add liquidity after minting tokens", async function () {
      const mintAmountA = ethers.parseEther("100");
      const mintAmountB = ethers.parseEther("100");
      await tokenA.connect(user).mint(mintAmountA);
      await tokenB.connect(user).mint(mintAmountB);

      await tokenA.connect(user).approve(await simpleSwap.getAddress(), mintAmountA);
      await tokenB.connect(user).approve(await simpleSwap.getAddress(), mintAmountB);

      const deadline = 1754084582;

      await simpleSwap
        .connect(user)
        .addLiquidity(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          mintAmountA,
          mintAmountB,
          0,
          0,
          user.address,
          deadline,
        );

      const reserveA = await simpleSwap.reserveA();
      const reserveB = await simpleSwap.reserveB();

      expect(reserveA).to.equal(mintAmountA);
      expect(reserveB).to.equal(mintAmountB);
    });
    it("Should mint liquidity Tokens for the specified address", async function () {
      expect(await simpleSwap.balanceOf(user.address)).to.be.equal(ethers.parseEther("100"));
    });
    it("Should handle deadline exceeded", async function () {
      const pastDeadline = 1748814182;

      await expect(
        simpleSwap.addLiquidity(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          10,
          10,
          0,
          0,
          user.address,
          pastDeadline,
        ),
      ).to.be.revertedWith("Deadline exceeded");
    });
  });

  describe("getPrice", function () {
    it("Should return the specified price for the amount in reserve", async function () {
      const price = await simpleSwap.getPrice(await tokenA.getAddress(), await tokenB.getAddress());
      expect(price).to.equal((ethers.parseEther("100") * BigInt(1e18)) / ethers.parseEther("100"));
    });
  });

  describe("swapExactTokensForTokens", function () {
    before(async () => {
      const mintAmountA = ethers.parseEther("110");
      const mintAmountB = ethers.parseEther("100");
      await tokenA.connect(user).mint(mintAmountA);
      await tokenB.connect(user).mint(mintAmountB);

      await tokenA.connect(user).approve(await simpleSwap.getAddress(), ethers.parseEther("100"));
      await tokenB.connect(user).approve(await simpleSwap.getAddress(), ethers.parseEther("100"));

      const deadline = 1754084582;

      await simpleSwap
        .connect(user)
        .addLiquidity(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          mintAmountA,
          mintAmountB,
          0,
          0,
          user.address,
          deadline,
        );
    });
    it("Should swap TokenA for TokenB", async function () {
      const swapAmount = ethers.parseEther("10");
      const minAmountOut = ethers.parseEther("8");

      await tokenA.connect(user).approve(await simpleSwap.getAddress(), swapAmount);

      const initialBalance = await tokenB.balanceOf(await user.getAddress());

      const addressTokenA = await tokenA.getAddress();
      const addressTokenB = await tokenB.getAddress();

      const path = [addressTokenA, addressTokenB];

      const deadline = 1754084582;

      await simpleSwap
        .connect(user)
        .swapExactTokensForTokens(swapAmount, minAmountOut, path, await user.getAddress(), deadline);

      const finalBalance = await tokenB.balanceOf(await user.getAddress());
      expect(finalBalance).to.be.gt(initialBalance);

      const reserveA = await simpleSwap.reserveA();
      const reserveB = await simpleSwap.reserveB();
      expect(reserveA).to.equal(ethers.parseEther("210"));
      expect(reserveB).to.be.lt(ethers.parseEther("200"));
    });
    it("Should handle deadline exceeded", async function () {
      const pastDeadline = 1748814182;

      await expect(
        simpleSwap.swapExactTokensForTokens(
          10,
          0,
          [await tokenA.getAddress(), await tokenB.getAddress()],
          user.address,
          pastDeadline,
        ),
      ).to.be.revertedWith("Deadline exceeded.");
    });

    it("Should handle invalid token addresses", async function () {
      const deadline = 1754084582;
      await expect(
        simpleSwap.swapExactTokensForTokens(
          10,
          0,
          [ethers.ZeroAddress, await tokenB.getAddress()],
          user.address,
          deadline,
        ),
      ).to.be.revertedWith("Token not found.");
    });

    it("Should handle zero amounts", async function () {
      const deadline = 1754084582;
      await expect(
        simpleSwap.swapExactTokensForTokens(
          0,
          0,
          [await tokenA.getAddress(), await tokenB.getAddress()],
          user.address,
          deadline,
        ),
      ).to.be.revertedWith("Positive value of tokens required.");
    });
  });
  describe("removeLiquidity", function () {
    it("Should remove liquidity after minting tokens", async function () {
      const mintAmountA = ethers.parseEther("100");
      const mintAmountB = ethers.parseEther("100");
      await tokenA.connect(user).mint(mintAmountA);
      await tokenB.connect(user).mint(mintAmountB);

      await tokenA.connect(user).approve(await simpleSwap.getAddress(), mintAmountA);
      await tokenB.connect(user).approve(await simpleSwap.getAddress(), mintAmountB);

      const deadline = 1754084582;

      await simpleSwap
        .connect(user)
        .removeLiquidity(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          ethers.parseEther("200"),
          0,
          0,
          user.address,
          deadline,
        );

      const reserveA = await simpleSwap.reserveA();
      const reserveB = await simpleSwap.reserveB();

      const balanceUser = await simpleSwap.balanceOf(user.address);

      expect(balanceUser).to.equal(0);
      expect(reserveA).to.equal(0);
      expect(reserveB).to.equal(0);
    });
  });
});
