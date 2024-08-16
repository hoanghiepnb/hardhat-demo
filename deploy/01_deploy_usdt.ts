import {DeployFunction} from "hardhat-deploy/types";
import {HardhatRuntimeEnvironment} from "hardhat/types";

const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getNamedAccounts} = hre;
    const {deploy} = deployments;
    const {deployer} = await getNamedAccounts();

    const USDT = await deploy("MockUSDT", {
      from: deployer,
      args: [],
      log: true,
    });
}

export default deployFunction;
deployFunction.tags = ["USDT"];