import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre; // ethers sẽ có sẵn từ hre sau khi cấu hình đúng
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // Deploy the contract
  const Robot = await deploy("Robot", {
    from: deployer,
    args: ["Mock Robot", "MRB"],
    log: true,
  });

  // Get the deployed contract instance
  const robotContract = await ethers.getContractAt("Robot", Robot.address);

  // Call the mint function
  const tx = await robotContract.mint(deployer);
  await tx.wait();

  console.log(`Minted a token to ${deployer}`);
};

export default deployFunction;
deployFunction.tags = ["Robot"];
