const { expect } = require("chai");
const hre = require("hardhat");
const ethers = require("ethers"); // Standalone ethers for utils

describe("P2PFreelance", function () {
  let contract, owner, freelancer, employer;
  const registrationFee = 1;
  const projectFee = 1;
  const proposalFee = 1;

  beforeEach(async function () {
    [owner, freelancer, employer, other] = await hre.ethers.getSigners();
    const P2PFreelance = await hre.ethers.getContractFactory("P2PFreelance");
    contract = await P2PFreelance.deploy();
  });

  function getSignature(signer, userType, timestamp) {
    // Simulate the signature logic in the contract
    const messageHash = ethers.utils.solidityKeccak256([
      "address",
      "uint8",
      "uint256",
    ], [signer.address, userType, timestamp]);
    const prefixedHash = ethers.utils.solidityKeccak256([
      "string",
      "bytes32"
    ], ["\x19Ethereum Signed Message:\n32", messageHash]);
    return signer.signMessage(ethers.utils.arrayify(prefixedHash));
  }

  it("should register a freelancer profile", async function () {
    const userType = 0; // Freelancer
    const now = (await hre.ethers.provider.getBlock("latest")).timestamp;
    const signature = await getSignature(freelancer, userType, now);
    const skills = ["Solidity", "JS"];
    const experiences = [];
    const portfolios = [];
    await expect(contract.connect(freelancer).registerProfile(
      "Ali", "photo", userType, skills, "BS", experiences, portfolios, signature,
      { value: registrationFee }
    )).to.emit(contract, "ProfileRegistered").withArgs(freelancer.address, userType);
    const profile = await contract.getProfileBase(freelancer.address);
    expect(profile[0]).to.equal(freelancer.address);
    expect(profile[1]).to.equal("Ali");
    expect(profile[3]).to.equal(userType);
  });

  it("should register an employer profile", async function () {
    const userType = 1; // Employer
    const now = (await hre.ethers.provider.getBlock("latest")).timestamp;
    const signature = await getSignature(employer, userType, now);
    const skills = ["Management"];
    const experiences = [];
    const portfolios = [];
    await expect(contract.connect(employer).registerProfile(
      "Bob", "photo", userType, skills, "MBA", experiences, portfolios, signature,
      { value: registrationFee }
    )).to.emit(contract, "ProfileRegistered").withArgs(employer.address, userType);
    const profile = await contract.getProfileBase(employer.address);
    expect(profile[0]).to.equal(employer.address);
    expect(profile[1]).to.equal("Bob");
    expect(profile[3]).to.equal(userType);
  });

  it("should update profile", async function () {
    const userType = 0;
    const now = (await hre.ethers.provider.getBlock("latest")).timestamp;
    const signature = await getSignature(freelancer, userType, now);
    await contract.connect(freelancer).registerProfile(
      "Ali", "photo", userType, ["Solidity"], "BS", [], [], signature,
      { value: registrationFee }
    );
    await contract.connect(freelancer).updateProfile(
      "Ali2", "photo2", ["Solidity", "JS"], "MS", [], []
    );
    const profile = await contract.getProfileBase(freelancer.address);
    expect(profile[1]).to.equal("Ali2");
    expect(profile[2]).to.equal("photo2");
    expect(profile[4][1]).to.equal("JS");
    expect(profile[5]).to.equal("MS");
  });

  it("should allow employer to register a project", async function () {
    // Register employer
    const userType = 1;
    const now = (await hre.ethers.provider.getBlock("latest")).timestamp;
    const signature = await getSignature(employer, userType, now);
    await contract.connect(employer).registerProfile(
      "Bob", "photo", userType, ["Management"], "MBA", [], [], signature,
      { value: registrationFee }
    );
    // Register project
    const deadline = now + 10000;
    await expect(contract.connect(employer).registerProject(
      "TestProj", "desc", ["Solidity"], 10, 1000, deadline,
      { value: projectFee }
    )).to.emit(contract, "ProjectRegistered");
    const project = await contract.getProject(0);
    expect(project[1]).to.equal("TestProj");
    expect(project[2]).to.equal("desc");
    expect(project[3][0]).to.equal("Solidity");
    expect(project[4]).to.equal(10);
    expect(project[5]).to.equal(1000);
    expect(project[6]).to.equal(true);
    expect(project[7]).to.equal(deadline);
  });

  it("should allow freelancer to submit a proposal", async function () {
    // Register employer
    const userTypeEmp = 1;
    const now = (await hre.ethers.provider.getBlock("latest")).timestamp;
    const signatureEmp = await getSignature(employer, userTypeEmp, now);
    await contract.connect(employer).registerProfile(
      "Bob", "photo", userTypeEmp, ["Management"], "MBA", [], [], signatureEmp,
      { value: registrationFee }
    );
    // Register freelancer
    const userTypeFreelancer = 0;
    const signatureFreelancer = await getSignature(freelancer, userTypeFreelancer, now);
    await contract.connect(freelancer).registerProfile(
      "Ali", "photo", userTypeFreelancer, ["Solidity"], "BS", [], [], signatureFreelancer,
      { value: registrationFee }
    );
    // Register project
    const deadline = now + 10000;
    await contract.connect(employer).registerProject(
      "TestProj", "desc", ["Solidity"], 10, 1000, deadline,
      { value: projectFee }
    );
    // Submit proposal
    await expect(contract.connect(freelancer).submitProposal(
      0, "I can do it", 900, 8, { value: proposalFee }
    )).to.emit(contract, "ProposalSubmitted").withArgs(0, freelancer.address);
    // Only employer can get proposal
    const proposal = await contract.connect(employer).getProposal(0, 0);
    expect(proposal[0]).to.equal(freelancer.address);
    expect(proposal[1]).to.equal("I can do it");
    expect(proposal[2]).to.equal(900);
    expect(proposal[3]).to.equal(8);
  });

  it("should restrict proposal access to employer only", async function () {
    // Register employer
    const userTypeEmp = 1;
    const now = (await hre.ethers.provider.getBlock("latest")).timestamp;
    const signatureEmp = await getSignature(employer, userTypeEmp, now);
    await contract.connect(employer).registerProfile(
      "Bob", "photo", userTypeEmp, ["Management"], "MBA", [], [], signatureEmp,
      { value: registrationFee }
    );
    // Register freelancer
    const userTypeFreelancer = 0;
    const signatureFreelancer = await getSignature(freelancer, userTypeFreelancer, now);
    await contract.connect(freelancer).registerProfile(
      "Ali", "photo", userTypeFreelancer, ["Solidity"], "BS", [], [], signatureFreelancer,
      { value: registrationFee }
    );
    // Register project
    const deadline = now + 10000;
    await contract.connect(employer).registerProject(
      "TestProj", "desc", ["Solidity"], 10, 1000, deadline,
      { value: projectFee }
    );
    // Submit proposal
    await contract.connect(freelancer).submitProposal(
      0, "I can do it", 900, 8, { value: proposalFee }
    );
    // Freelancer should not be able to get proposal
    await expect(contract.connect(freelancer).getProposal(0, 0)).to.be.revertedWith("Only employer");
  });

  it("should not allow more than MAX_ITEMS skills", async function () {
    const userType = 0;
    const now = (await hre.ethers.provider.getBlock("latest")).timestamp;
    const signature = await getSignature(freelancer, userType, now);
    const skills = ["a","b","c","d","e","f"];
    await expect(contract.connect(freelancer).registerProfile(
      "Ali", "photo", userType, skills, "BS", [], [], signature,
      { value: registrationFee }
    )).to.be.revertedWith("Skills invalid");
  });

  it("should not allow proposal after deadline", async function () {
    // Register employer
    const userTypeEmp = 1;
    const now = (await hre.ethers.provider.getBlock("latest")).timestamp;
    const signatureEmp = await getSignature(employer, userTypeEmp, now);
    await contract.connect(employer).registerProfile(
      "Bob", "photo", userTypeEmp, ["Management"], "MBA", [], [], signatureEmp,
      { value: registrationFee }
    );
    // Register freelancer
    const userTypeFreelancer = 0;
    const signatureFreelancer = await getSignature(freelancer, userTypeFreelancer, now);
    await contract.connect(freelancer).registerProfile(
      "Ali", "photo", userTypeFreelancer, ["Solidity"], "BS", [], [], signatureFreelancer,
      { value: registrationFee }
    );
    // Register project with deadline in the past
    const deadline = now - 1;
    await expect(contract.connect(employer).registerProject(
      "TestProj", "desc", ["Solidity"], 10, 1000, deadline,
      { value: projectFee }
    )).to.be.revertedWith("Deadline invalid");
  });
}); 