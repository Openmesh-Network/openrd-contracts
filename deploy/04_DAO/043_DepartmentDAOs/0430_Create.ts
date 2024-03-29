import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, DeploymentsExtension } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { getBool, setBool } from "../../../utils/globalVars";
import { createDAO } from "../utils/DAODeployer";
import { geTaskDraftsSettings, getTokenListGovernanceSettings } from "../utils/PluginSettings";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (!(await getBool("NewTokenListGovernance")) && !(await getBool("NewDraftsSetup")) && !(await getBool("NewNFT"))) {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();

  await createDepartment(deployer, "data", [0], deployments);
  await createDepartment(deployer, "frontend", [0], deployments);
  await createDepartment(deployer, "blockchain", [0], deployments);
  await createDepartment(deployer, "cloud", [0], deployments);

  await setBool("NewDepartments", true);
};
export default func;
func.tags = ["DepartmentDAO"];
func.dependencies = ["TokenListGovernance", "TaskDrafts", "NFT", "Tasks", "ManagementDAO"];

async function createDepartment(deployer: string, departmentName: string, members: number[], deployments: DeploymentsExtension) {
  const subdomain = "openrd-" + departmentName + "-beta"; //"department-test-" + (await getVar("ENSCounter")) + "-" + departmentName;

  const tasks = await deployments.get("Tasks");
  const nftCollection = await deployments.get("NFT");
  const tokenListGovernanceSetup = await deployments.get("TokenListGovernanceSetup");
  const managementDao = await deployments.get("management_dao");
  const tokenListGovernanceSettings = await getTokenListGovernanceSettings(nftCollection.address, members, managementDao.address);
  // In case there is a transaction in progress, either this one or that will get the wrong address, based on which one gets confirmed earlier
  // This is because the nonce has then increased by 1, however there is currently no other way to get the address as far as I know
  const expectedGovernanceAddress = await ethers.getCreateAddress({
    from: tokenListGovernanceSetup.address,
    nonce: await ethers.provider.getTransactionCount(tokenListGovernanceSetup.address),
  });
  const taskDraftsSettings = await geTaskDraftsSettings(tasks.address, expectedGovernanceAddress);

  const dao = await createDAO(deployer, subdomain, [tokenListGovernanceSettings, taskDraftsSettings], deployments);

  await deployments.save(departmentName + "_dao", { address: dao.daoAddress, ...(await deployments.getArtifact("DAO")) });
  await deployments.save(departmentName + "_tokenListGovernance", {
    address: dao.pluginAddresses[0],
    ...(await deployments.getArtifact("TokenListGovernance")),
  });
  await deployments.save(departmentName + "_taskDrafts", { address: dao.pluginAddresses[1], ...(await deployments.getArtifact("TaskDrafts")) });
}
