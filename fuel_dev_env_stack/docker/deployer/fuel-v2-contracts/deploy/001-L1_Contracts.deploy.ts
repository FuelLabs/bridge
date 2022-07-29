import { DeployFunction } from "hardhat-deploy/dist/types";

const deployFn: DeployFunction = async (hre) => {
  const { deploy } = hre.deployments;
  const { deployer } = await hre.getNamedAccounts();
  const deployerSigner = await hre.ethers.getSigner(deployer);

  // Deploy libraries
  let binaryMerkleTreeLib = await deploy("BinaryMerkleTreeLib", {
    contract: "BinaryMerkleTree",
    from: deployer,
    args: [],
    log: true,
  });

  // Deploy messaging contracts
  let transactionCount = await deployerSigner.getTransactionCount();
  let futureInboxAddress = hre.ethers.utils.getContractAddress({
    from: deployer,
    nonce: transactionCount + 0,
  });
  let futureOutboxAddress = hre.ethers.utils.getContractAddress({
    from: deployer,
    nonce: transactionCount + 1,
  });
  let fuelMessageOutbox = await deploy("FuelMessageInbox", {
    contract: "FuelMessageInbox",
    from: deployer,
    args: [futureOutboxAddress],
    libraries: {
      BinaryMerkleTree: binaryMerkleTreeLib.address,
    },
    log: true,
  });
  let fuelMessageInbox = await deploy("FuelMessageOutbox", {
    contract: "FuelMessageOutbox",
    from: deployer,
    args: [futureInboxAddress],
    log: true,
  });

  // Deploy contract for ERC20 bridging
  let l1ERC20Gateway = await deploy("L1ERC20Gateway", {
    contract: "L1ERC20Gateway",
    from: deployer,
    args: [
      fuelMessageOutbox.address,
      fuelMessageInbox.address,
      "0x609a428d6498d9ddba812cc67c883a53446a1c01bc7388040f1e758b15e1d8bb",
    ],
    log: true,
  });
};

// This is kept during an upgrade. So no upgrade tag.
deployFn.tags = ["L1_Contracts"];

export default deployFn;
