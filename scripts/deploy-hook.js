const hre = require("hardhat");

async function main() {
  // For testing, we first need to deploy a mock IPoolManager contract
  // In a real deployment, you would use the actual Uniswap v4 PoolManager address
  console.log("Deploying mock PoolManager for testing...");
  const MockPoolManager = await hre.ethers.getContractFactory("MockPoolManager");
  const mockPoolManager = await MockPoolManager.deploy();
  await mockPoolManager.waitForDeployment();
  console.log(`Mock PoolManager deployed to: ${mockPoolManager.target}`);
  
  // Deploy vDPP Token if not already deployed
  console.log("Deploying vDPP Token...");
  const vDPPToken = await hre.ethers.deployContract("vDPPToken");
  await vDPPToken.waitForDeployment();
  console.log(`vDPP Token deployed to: ${vDPPToken.target}`);
  
  // Get the deployer address
  const [deployer] = await hre.ethers.getSigners();
  
  // Deploy the DesiredPriceHook
  console.log("Deploying DesiredPriceHook...");
  const DesiredPriceHook = await hre.ethers.getContractFactory("DesiredPriceHook");
  const dppHook = await DesiredPriceHook.deploy(
    mockPoolManager.target,   // IPoolManager address
    vDPPToken.target,         // vDPP token address
    deployer.address          // Initial governance address
  );
  await dppHook.waitForDeployment();
  console.log(`DesiredPriceHook deployed to: ${dppHook.target}`);
  
  // Set the DPP Hook address in the vDPP token contract
  console.log("Setting DPP Hook address in vDPP Token...");
  const setDPPHookTx = await vDPPToken.setDPPHook(dppHook.target);
  await setDPPHookTx.wait();
  console.log("DPP Hook address set in vDPP Token");
  
  // Verify the contracts on Etherscan (if on a supported network)
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("Waiting for block confirmations...");
    await dppHook.deploymentTransaction().wait(5);
    
    console.log("Verifying contracts on Etherscan...");
    await hre.run("verify:verify", {
      address: vDPPToken.target,
      constructorArguments: [],
    });
    
    await hre.run("verify:verify", {
      address: dppHook.target,
      constructorArguments: [
        mockPoolManager.target,
        vDPPToken.target,
        deployer.address
      ],
    });
  }

  return { vDPPToken, dppHook };
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });