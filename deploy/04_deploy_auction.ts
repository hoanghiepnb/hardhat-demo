import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";

const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getNamedAccounts, ethers} = hre;
    const {deploy, get} = deployments;
    const {deployer} = await getNamedAccounts();

    const feeReceiver = "0xc982c05870893A0BafD0B27Bc8AE4103df9fF357";
    const feePercent = 1000;
    const penaltyPercent = 3000;
    const Auction = await deploy("Auction", {
        from: deployer,
        args: [feeReceiver, feePercent, penaltyPercent],
        log: true,
    });

    const auction = await get("Auction");
    const robot = await get("Robot");

    const robotContract = await ethers.getContractAt("Robot", robot.address);
    const auctionContract = await ethers.getContractAt("Auction", auction.address);

    await robotContract.mint(deployer);
};

export default deployFunction;
deployFunction.tags = ["Auction"];