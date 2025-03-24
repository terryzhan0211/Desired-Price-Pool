const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("vDPP Token", function () {
  let vDPPToken;
  let owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    
    const vDPPTokenFactory = await ethers.getContractFactory("vDPPToken");
    vDPPToken = await vDPPTokenFactory.deploy();
    await vDPPToken.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await vDPPToken.owner()).to.equal(owner.address);
    });

    it("Should mint initial treasury tokens", async function () {
      const treasuryMinted = await vDPPToken.treasuryMinted();
      expect(treasuryMinted).to.equal(ethers.parseEther("2000000"));
      
      const ownerBalance = await vDPPToken.balanceOf(owner.address);
      expect(ownerBalance).to.equal(ethers.parseEther("2000000"));
    });
  });

  describe("Token Minting", function () {
    it("Should allow owner to mint treasury tokens", async function () {
      const mintAmount = ethers.parseEther("1000000");
      await vDPPToken.mintTreasury(addr1.address, mintAmount);
      
      const addr1Balance = await vDPPToken.balanceOf(addr1.address);
      expect(addr1Balance).to.equal(mintAmount);
      
      const treasuryMinted = await vDPPToken.treasuryMinted();
      expect(treasuryMinted).to.equal(ethers.parseEther("3000000")); // Initial 2M + 1M new
    });

    it("Should not allow non-owners to mint treasury tokens", async function () {
      const mintAmount = ethers.parseEther("1000000");
      await expect(
        vDPPToken.connect(addr1).mintTreasury(addr2.address, mintAmount)
      ).to.be.reverted;
    });

    it("Should enforce treasury supply cap", async function () {
      // Try to mint more than the remaining treasury allocation
      const maxTreasurySupply = await vDPPToken.MAX_TREASURY_SUPPLY();
      const treasuryMinted = await vDPPToken.treasuryMinted();
      const excessAmount = maxTreasurySupply - treasuryMinted + ethers.parseEther("1");
      
      await expect(
        vDPPToken.mintTreasury(addr1.address, excessAmount)
      ).to.be.revertedWith("Exceeds treasury allocation");
    });
  });

  describe("DPP Hook Integration", function () {
    it("Should allow setting the DPP Hook address", async function () {
      await vDPPToken.setDPPHook(addr1.address);
      expect(await vDPPToken.dppHook()).to.equal(addr1.address);
    });

    it("Should only allow DPP Hook to mint LP rewards", async function () {
      await vDPPToken.setDPPHook(addr1.address);
      
      // Non-hook address should not be able to mint LP rewards
      await expect(
        vDPPToken.mintLPRewards(addr2.address, ethers.parseEther("1000"))
      ).to.be.revertedWith("Only DPP Hook can mint LP rewards");
      
      // Hook address should be able to mint LP rewards
      await vDPPToken.connect(addr1).mintLPRewards(addr2.address, ethers.parseEther("1000"));
      
      const addr2Balance = await vDPPToken.balanceOf(addr2.address);
      expect(addr2Balance).to.equal(ethers.parseEther("1000"));
      
      const lpMinted = await vDPPToken.lpMinted();
      expect(lpMinted).to.equal(ethers.parseEther("1000"));
    });
  });
});