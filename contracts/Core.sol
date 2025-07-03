// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract P2PFreelance {
    using ECDSA for bytes32;

    // User types: Freelancer or Employer
    enum UserType { Freelancer, Employer }

    // Work experience entry
    struct Experience {
        string companyName;
        uint duration; // Duration in days
        string role;
        string description;
        string link;
    }

    // Portfolio entry
    struct Portfolio {
        string title;
        string description;
        string link;
        uint year;
        string result;
    }

    // User profile data
    struct UserProfile {
        address userAddress;
        string firstName;
        string profilePhoto; // Link to profile photo (e.g., IPFS)
        UserType userType;
        string[] skills; // Up to 5 skills
        string education;
        mapping(uint => Experience) experiences; // Up to 5 experiences
        mapping(uint => Portfolio) portfolios;   // Up to 5 portfolio items
        uint8 experienceCount;
        uint8 portfolioCount;
    }

    // Project data
    struct Project {
        address employer;
        string title;
        string description;
        string[] requiredSkills; // Up to 5 required skills
        uint duration; // Duration in days
        uint amount;
        bool isOpen;
        uint proposalDeadline; // Proposal deadline (timestamp)
        mapping(uint => Proposal) proposals; // Proposals mapping
        uint proposalCount;
    }

    // Proposal data
    struct Proposal {
        address freelancer;
        string text;
        uint amount;
        uint duration; // Duration in days
        uint timestamp;
    }

    // Mapping from user address to profile
    mapping(address => UserProfile) public profiles;
    // Array of all projects
    Project[] public projects;

    // Fee constants
    uint public constant REGISTRATION_FEE = 1 wei;
    uint public constant PROPOSAL_FEE = 1 wei;
    uint public constant PROJECT_FEE = 1 wei;
    uint public constant MAX_ITEMS = 5; // Max items for skills, experiences, portfolios

    // Events
    event ProfileRegistered(address indexed user, UserType userType);
    event ProjectRegistered(uint indexed projectId);
    event ProposalSubmitted(uint indexed projectId, address indexed freelancer);

    /**
     * Register a new user profile. Requires a valid signature and fee.
     */
    function registerProfile(
        string memory _firstName,
        string memory _profilePhoto,
        UserType _userType,
        string[] memory _skills,
        string memory _education,
        Experience[] memory _experiences,
        Portfolio[] memory _portfolios,
        bytes memory _signature
    ) public payable {
        require(msg.value >= REGISTRATION_FEE, "Insufficient fee");
        require(bytes(_firstName).length > 0 && bytes(_firstName).length <= 50, "Name invalid");
        require(_skills.length > 0 && _skills.length <= MAX_ITEMS, "Skills invalid");
        require(bytes(_education).length > 0 && bytes(_education).length <= 100, "Education invalid");
        require(bytes(_profilePhoto).length > 0 && bytes(_profilePhoto).length <= 256, "Photo invalid");
        require(_experiences.length <= MAX_ITEMS, "Experiences limit exceeded");
        require(_portfolios.length <= MAX_ITEMS, "Portfolios limit exceeded");

        // Signature verification for registration
        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, _userType, block.timestamp));
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        address signer = ECDSA.recover(prefixedHash, _signature);
        require(signer == msg.sender, "Invalid signature");

        UserProfile storage user = profiles[msg.sender];
        user.userAddress = msg.sender;
        user.firstName = _firstName;
        user.profilePhoto = _profilePhoto;
        user.userType = _userType;
        user.skills = _skills;
        user.education = _education;
        user.experienceCount = uint8(_experiences.length);
        user.portfolioCount = uint8(_portfolios.length);
        for (uint i = 0; i < _experiences.length; i++) {
            user.experiences[i] = _experiences[i];
        }
        for (uint i = 0; i < _portfolios.length; i++) {
            user.portfolios[i] = _portfolios[i];
        }
        emit ProfileRegistered(msg.sender, _userType);
    }

    /**
     * Update an existing user profile. Only the owner can update.
     */
    function updateProfile(
        string memory _firstName,
        string memory _profilePhoto,
        string[] memory _skills,
        string memory _education,
        Experience[] memory _experiences,
        Portfolio[] memory _portfolios
    ) public {
        require(msg.sender == profiles[msg.sender].userAddress, "Only owner");
        require(bytes(_firstName).length > 0 && bytes(_firstName).length <= 50, "Name invalid");
        require(_skills.length > 0 && _skills.length <= MAX_ITEMS, "Skills invalid");
        require(bytes(_education).length > 0 && bytes(_education).length <= 100, "Education invalid");
        require(bytes(_profilePhoto).length > 0 && bytes(_profilePhoto).length <= 256, "Photo invalid");
        require(_experiences.length <= MAX_ITEMS, "Experiences limit exceeded");
        require(_portfolios.length <= MAX_ITEMS, "Portfolios limit exceeded");

        UserProfile storage user = profiles[msg.sender];
        user.firstName = _firstName;
        user.profilePhoto = _profilePhoto;
        user.skills = _skills;
        user.education = _education;
        user.experienceCount = uint8(_experiences.length);
        user.portfolioCount = uint8(_portfolios.length);
        for (uint i = 0; i < _experiences.length; i++) {
            user.experiences[i] = _experiences[i];
        }
        for (uint i = 0; i < _portfolios.length; i++) {
            user.portfolios[i] = _portfolios[i];
        }
    }

    /**
     * Get basic profile information. Only the user or an employer can access.
     */
    function getProfileBase(address _user) public view returns (address, string memory, string memory, UserType, string[] memory, string memory, uint8, uint8) {
        UserProfile storage user = profiles[_user];
        require(msg.sender == _user || profiles[msg.sender].userType == UserType.Employer, "Access denied");
        return (user.userAddress, user.firstName, user.profilePhoto, user.userType, user.skills, user.education, user.experienceCount, user.portfolioCount);
    }

    /**
     * Get a specific experience entry for a user. Only the user or an employer can access.
     */
    function getExperiences(address _user, uint index) public view returns (Experience memory) {
        UserProfile storage user = profiles[_user];
        require(msg.sender == _user || profiles[msg.sender].userType == UserType.Employer, "Access denied");
        require(index < user.experienceCount, "Index out of bounds");
        return user.experiences[index];
    }

    /**
     * Get a specific portfolio entry for a user. Only the user or an employer can access.
     */
    function getPortfolios(address _user, uint index) public view returns (Portfolio memory) {
        UserProfile storage user = profiles[_user];
        require(msg.sender == _user || profiles[msg.sender].userType == UserType.Employer, "Access denied");
        require(index < user.portfolioCount, "Index out of bounds");
        return user.portfolios[index];
    }

    /**
     * Register a new project. Only employers can register projects.
     */
    function registerProject(
        string memory _title,
        string memory _description,
        string[] memory _requiredSkills,
        uint _duration,
        uint _amount,
        uint _proposalDeadline
    ) public payable {
        require(profiles[msg.sender].userType == UserType.Employer, "Only employer");
        require(msg.value >= PROJECT_FEE, "Insufficient fee");
        require(bytes(_title).length > 0 && bytes(_title).length <= 50, "Title invalid");
        require(_requiredSkills.length > 0 && _requiredSkills.length <= MAX_ITEMS, "Skills invalid");
        require(_duration > 0, "Duration invalid");
        require(_amount > 0, "Amount invalid");
        require(_proposalDeadline > block.timestamp, "Deadline invalid");

        projects.push();
        Project storage p = projects[projects.length - 1];
        p.employer = msg.sender;
        p.title = _title;
        p.description = _description;
        p.requiredSkills = _requiredSkills;
        p.duration = _duration;
        p.amount = _amount;
        p.isOpen = true;
        p.proposalDeadline = _proposalDeadline;
        p.proposalCount = 0;
        emit ProjectRegistered(projects.length - 1);
    }

    /**
     * Update a project's description and open status. Only the employer can update.
     */
    function updateProject(uint _projectId, string memory _description, bool _isOpen) public {
        require(msg.sender == projects[_projectId].employer, "Only employer");
        require(_projectId < projects.length, "Invalid project");
        projects[_projectId].description = _description;
        projects[_projectId].isOpen = _isOpen;
    }

    /**
     * Get information for a single project by ID.
     */
    function getProject(uint _projectId) public view returns (address, string memory, string memory, string[] memory, uint, uint, bool, uint, uint) {
        require(_projectId < projects.length, "Invalid project");
        Project storage p = projects[_projectId];
        return (p.employer, p.title, p.description, p.requiredSkills, p.duration, p.amount, p.isOpen, p.proposalDeadline, p.proposalCount);
    }

    /**
     * Submit a proposal to a project. Only freelancers can submit proposals.
     */
    function submitProposal(uint _projectId, string memory _text, uint _amount, uint _duration) public payable {
        require(profiles[msg.sender].userType == UserType.Freelancer, "Only freelancer");
        require(msg.value >= PROPOSAL_FEE, "Insufficient fee");
        require(bytes(_text).length > 0 && bytes(_text).length <= 256, "Text invalid");
        require(_projectId < projects.length && projects[_projectId].isOpen, "Project invalid");
        require(_amount > 0, "Amount invalid");
        require(_duration > 0, "Duration invalid");
        require(block.timestamp <= projects[_projectId].proposalDeadline, "Deadline passed");

        Project storage p = projects[_projectId];
        p.proposals[p.proposalCount] = Proposal(msg.sender, _text, _amount, _duration, block.timestamp);
        p.proposalCount++;
        emit ProposalSubmitted(_projectId, msg.sender);
    }

    /**
     * Get a proposal for a project by index. Only the employer can access proposals for their project.
     */
    function getProposal(uint _projectId, uint _proposalIndex) public view returns (address, string memory, uint, uint, uint) {
        require(_projectId < projects.length, "Invalid project");
        require(msg.sender == projects[_projectId].employer, "Only employer");
        Project storage p = projects[_projectId];
        require(_proposalIndex < p.proposalCount, "Invalid proposal");
        Proposal memory proposal = p.proposals[_proposalIndex];
        return (proposal.freelancer, proposal.text, proposal.amount, proposal.duration, proposal.timestamp);
    }
}