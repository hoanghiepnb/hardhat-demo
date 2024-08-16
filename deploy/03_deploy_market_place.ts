import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";

const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getNamedAccounts} = hre;
    const {deploy, get} = deployments;
    const {deployer} = await getNamedAccounts();

    const USDT = await get("MockUSDT");
    const Robot = await get("Robot");
    const treasury = "0xc982c05870893A0BafD0B27Bc8AE4103df9fF357";
    const MarketPlace = await deploy("MarketPlace", {
        from: deployer,
        args: [Robot.address, USDT.address, 1000, treasury],
        log: true,
    });
};

export default deployFunction;
deployFunction.tags = ["MarketPlace"];