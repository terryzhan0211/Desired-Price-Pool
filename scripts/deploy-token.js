const hre = require("hardhat");

async function main() {
  console.log("Deploying vDPP Token...");

  const vDPPToken = await hre.ethers.deployContract("vDPPToken");
  await vDPPToken.waitForDeployment();

  console.log(`vDPP Token deployed to: ${vDPPToken.target}`);
  
  // Verify the contract on Etherscan (if on a supported network)
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("Waiting for block confirmations...");
    await vDPPToken.deploymentTransaction().wait(5);
    
    console.log("Verifying contract on Etherscan...");
    await hre.run("verify:verify", {
      address: vDPPToken.target,
      constructorArguments: [],
    });
  }

  return vDPPToken;
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });