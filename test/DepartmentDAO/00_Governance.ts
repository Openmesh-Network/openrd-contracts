import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { deployments, ethers, getNamedAccounts } from "hardhat";
import { DAO, IDAO, TaskDrafts, Tasks, TokenListGovernance, VerifiedContributor } from "../../typechain-types";
import { TestSetup } from "../Helpers/TestSetup";
import { expect } from "chai";
import { days, minutes, now } from "../../utils/timeUnits";
import { ether } from "../../utils/ethersUnits";

export async function getDAO() {
  await loadFixture(TestSetup);
  const { deployer } = await getNamedAccounts();

  const DAO = (await ethers.getContract("blockchain_dao", deployer)) as DAO;
  const TokenListGovernance = (await ethers.getContract("blockchain_tokenListGovernance", deployer)) as TokenListGovernance;
  const TaskDrafts = (await ethers.getContract("blockchain_taskDrafts", deployer)) as TaskDrafts;
  const NFT = (await ethers.getContract("NFT", deployer)) as VerifiedContributor;
  const Tasks = (await ethers.getContract("Tasks", deployer)) as Tasks;

  return { DAO, TokenListGovernance, TaskDrafts, NFT, deployer, Tasks };
}

describe("Department DAO Governance", function () {
  it("has members", async function () {
    const dao = await loadFixture(getDAO);
    expect(await dao.TokenListGovernance.isMember(0)).to.be.true;
  });

  it("reverts when no NFT", async function () {
    const dao = await loadFixture(getDAO);
    const managementDAO = await deployments.get("management_dao");
    (await ethers.getSigners())[0].sendTransaction({
      to: managementDAO.address,
      value: ether,
    });
    await dao.NFT.connect(await ethers.getImpersonatedSigner(managementDAO.address)).burn(0);
    const metadata = ethers.toUtf8Bytes("0x");
    const actions: IDAO.ActionStruct[] = [];
    const start = now() + 30 * minutes;
    const end = now() + 2 * days;
    await expect(dao.TokenListGovernance.createProposal(metadata, actions, 0, start, end, 0, false, 0)).to.be.reverted;
  });

  it("allow when NFT", async function () {
    const dao = await loadFixture(getDAO);
    //await dao.NFT.grantToken(dao.deployer, 0);
    const metadata = ethers.toUtf8Bytes("0x");
    const actions: IDAO.ActionStruct[] = [];
    const start = now() + 30 * minutes;
    const end = now() + 2 * days;
    await expect(dao.TokenListGovernance.createProposal(metadata, actions, 0, start, end, 0, false, 0)).to.not.be.reverted;
  });

  it("reverts when wrong NFT", async function () {
    const dao = await loadFixture(getDAO);
    //await dao.NFT.grantToken(dao.deployer, 0);
    const metadata = ethers.toUtf8Bytes("0x");
    const actions: IDAO.ActionStruct[] = [];
    const start = now() + 30 * minutes;
    const end = now() + 2 * days;
    await expect(dao.TokenListGovernance.createProposal(metadata, actions, 0, start, end, 0, false, 1)).to.be.reverted;
  });

  it("reverts when not accepted NFT", async function () {
    const dao = await loadFixture(getDAO);
    const managementDAO = await deployments.get("management_dao");
    (await ethers.getSigners())[0].sendTransaction({
      to: managementDAO.address,
      value: ether,
    });
    await dao.NFT.connect(await ethers.getImpersonatedSigner(managementDAO.address)).mint(dao.deployer, 5);
    //await dao.NFT.grantToken(dao.deployer, 5);
    const metadata = ethers.toUtf8Bytes("0x");
    const actions: IDAO.ActionStruct[] = [];
    const start = now() + 30 * minutes;
    const end = now() + 2 * days;
    await expect(dao.TokenListGovernance.createProposal(metadata, actions, 0, start, end, 0, false, 5)).to.be.reverted;
  });

  it("allow when NFT accepted", async function () {
    const dao = await loadFixture(getDAO);
    //await dao.NFT.grantToken(dao.deployer, 5);

    // Move this to a helper function (get DAO signer? execute as DAO?)
    const managementDAO = await deployments.get("management_dao");
    (await ethers.getSigners())[0].sendTransaction({
      to: managementDAO.address,
      value: ether,
    });
    await dao.NFT.connect(await ethers.getImpersonatedSigner(managementDAO.address)).mint(dao.deployer, 5);
    await dao.TokenListGovernance.connect(await ethers.getImpersonatedSigner(managementDAO.address)).addMembers([5]);

    const metadata = ethers.toUtf8Bytes("0x");
    const actions: IDAO.ActionStruct[] = [];
    const start = now() + 30 * minutes;
    const end = now() + 2 * days;
    await expect(dao.TokenListGovernance.createProposal(metadata, actions, 0, start, end, 0, false, 5)).to.not.be.reverted;
  });
});
