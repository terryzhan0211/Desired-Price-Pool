const hre = require("hardhat");

async function main() {
  // First, get the deployed vDPP token or deploy it if not already deployed
  let vDPPTokenAddress;
  
  // Try to get vDPP token address from previous deployment
  try {
    const deployData = require('../deployments.json');
    vDPPTokenAddress = deployData.vDPPToken;
    console.log(`Using existing vDPP Token at: ${vDPPTokenAddress}`);
  } catch (error) {
    console.log("No existing deployment found, deploying vDPP Token first...");
    
    const vDPPToken = await hre.ethers.deployContract("vDPPToken");
    await vDPPToken.waitForDeployment();
    vDPPTokenAddress = vDPPToken.target;
    
    console.log(`vDPP Token deployed to: ${vDPPTokenAddress}`);
  }

  // For testing, we'll use a mock pool manager
  console.log("Deploying Mock Pool Manager...");
  const mockPoolManager = await hre.ethers.deployContract("MockPoolManager");
  await mockPoolManager.waitForDeployment();
  console.log(`Mock Pool Manager deployed to: ${mockPoolManager.target}`);

  // Get the deployer address for governance
  const [deployer] = await hre.ethers.getSigners();
  
  // Deploy the DesiredPriceHook
  console.log("Deploying Desired Price Hook...");
  const desiredPriceHook = await hre.ethers.deployContract("DesiredPriceHook", [
    mockPoolManager.target,
    vDPPTokenAddress,
    deployer.address // Set deployer as governance initially
  ]);
  
  await desiredPriceHook.waitForDeployment();
  console.log(`Desired Price Hook deployed to: ${desiredPriceHook.target}`);

  // Configure vDPP token to allow hook to mint rewards
  console.log("Setting DPP Hook in vDPP Token...");
  const vDPPToken = await hre.ethers.getContractAt("vDPPToken", vDPPTokenAddress);
  await vDPPToken.setDPPHook(desiredPriceHook.target);
  console.log("DPP Hook set in vDPP Token");

  // Save deployment information
  const fs = require('fs');
  const deploymentData = {
    vDPPToken: vDPPTokenAddress,
    mockPoolManager: mockPoolManager.target,
    desiredPriceHook: desiredPriceHook.target,
    network: hre.network.name,
    timestamp: new Date().toISOString()
  };
  
  fs.writeFileSync(
    'deployments.json',
    JSON.stringify(deploymentData, null, 2)
  );
  console.log("Deployment information saved to deployments.json");

  // Verify contracts on Etherscan if not on a local network
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("Waiting for block confirmations before verification...");
    await desiredPriceHook.deploymentTransaction().wait(5);
    
    console.log("Verifying contracts on Etherscan...");
    try {
      await hre.run("verify:verify", {
        address: vDPPTokenAddress,
        constructorArguments: []
      });
    } catch (error) {
      console.log("vDPP Token verification failed or already verified:", error.message);
    }
    
    try {
      await hre.run("verify:verify", {
        address: mockPoolManager.target,
        constructorArguments: []
      });
    } catch (error) {
      console.log("MockPoolManager verification failed or already verified:", error.message);
    }
    
    try {
      await hre.run("verify:verify", {
        address: desiredPriceHook.target,
        constructorArguments: [
          mockPoolManager.target,
          vDPPTokenAddress,
          deployer.address
        ]
      });
    } catch (error) {
      console.log("DesiredPriceHook verification failed or already verified:", error.message);
    }
  }

  return { vDPPToken: vDPPTokenAddress, desiredPriceHook: desiredPriceHook.target };
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });