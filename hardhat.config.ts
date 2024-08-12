import { HardhatUserConfig } from "hardhat/config";
import "hardhat-deploy";
import "@nomiclabs/hardhat-etherscan";

const config: HardhatUserConfig = {
    solidity: "0.8.24",
    networks: {
        hardhat: {
            chainId: 1337
        },
        testnet: {
            url: "https://bsc-testnet-dataseed.bnbchain.org",
            chainId: 97,
            accounts: ['0xcdd0e4bfa4331f692a03f8aec1dea16909f7110f98840a352d0a008bf2705b0b'],
        }
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
    },
    etherscan: {
        apiKey: "7UBDUSN9W5TUMVHXYC87CCEU8J9YT7YRHP"
    }
};

export default config;
