import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";

const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getNamedAccounts} = hre;
    const {deploy, get} = deployments;
    const {deployer} = await getNamedAccounts();

    const USDT = await get("MockUSDT");
    const TicketPrize = 10000000000000000000n;
    const MarketPlace = await deploy("Lottery", {
        from: deployer,
        args: [USDT.address, TicketPrize, 5000],
        log: true,
    });
};

export default deployFunction;
deployFunction.tags = ["Lottery"];