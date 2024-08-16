import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";

const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  const Robot = await deploy("Robot", {
    from: deployer,
    args: ["Mock Robot", "MRB"],
    log: true,
  });
};

export default deployFunction;
deployFunction.tags = ["Robot"];