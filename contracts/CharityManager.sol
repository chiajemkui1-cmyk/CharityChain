// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CharityCampaign.sol";

/**
 * @title CharityManager
 * @notice Factory and registry for verified charity campaigns
 */
contract CharityManager {
    address public platformAdmin;
    address public pendingAdmin;

    address[] public allCampaigns;
    mapping(address => address[]) public ngoCampaigns;
    mapping(address => bool) public isVerifiedNGO;
    mapping(address => NGOInfo) public ngoInfo;
    mapping(address => bool) public isCampaign;

    bool public paused;
    uint256 public verifiedNGOCount;

    mapping(address => NGOApplication) public ngoApplications;
    address[] private _pendingApplicants;

    struct NGOInfo {
        string name;
        string registrationNumber;
        uint256 verifiedAt;
        bool isActive;
    }

    struct NGOApplication {
        string name;
        string registrationNumber;
        string website;
        string description;
        uint256 appliedAt;
        ApplicationStatus status;
    }

    enum ApplicationStatus {
        None,
        Pending,
        Approved,
        Rejected
    }

    event NGOVerified(address indexed ngo, string name, string registrationNumber);
    event NGORevoked(address indexed ngo, string reason);
    event CampaignCreated(address indexed campaign, address indexed ngo, string mission, uint256 goal);
    event PlatformPausedEvent(address indexed admin);
    event PlatformUnpausedEvent(address indexed admin);
    event AdminTransferInitiated(address indexed currentAdmin, address indexed newAdmin);
    event AdminTransferCancelled(address indexed admin);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event NGOApplied(address indexed applicant, string name, string registrationNumber);
    event NGOApplicationApproved(address indexed applicant, string name);
    event NGOApplicationRejected(address indexed applicant, string reason);

    error NotAdmin();
    error NotVerifiedNGO();
    error AlreadyVerified();
    error PlatformIsPaused();
    error InvalidAddress();
    error InvalidArrayLengths();
    error InvalidMilestoneData();
    error NGONotActive();
    error NGONotVerified();
    error SelfTransferNotAllowed();
    error NoPendingTransfer();
    error AlreadyApplied();
    error ApplicationNotPending();
    error NoApplicationFound();

    modifier onlyAdmin() {
        if (msg.sender != platformAdmin) revert NotAdmin();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PlatformIsPaused();
        _;
    }

    constructor() {
        platformAdmin = msg.sender;
    }

    function applyAsNGO(
        string memory _name,
        string memory _registrationNumber,
        string memory _website,
        string memory _description
    ) external {
        if (isVerifiedNGO[msg.sender]) revert AlreadyVerified();
        if (ngoApplications[msg.sender].status == ApplicationStatus.Pending) revert AlreadyApplied();

        require(bytes(_name).length > 0, "Name required");
        require(bytes(_registrationNumber).length > 0, "Registration number required");

        ngoApplications[msg.sender] = NGOApplication({
            name: _name,
            registrationNumber: _registrationNumber,
            website: _website,
            description: _description,
            appliedAt: block.timestamp,
            status: ApplicationStatus.Pending
        });

        _pendingApplicants.push(msg.sender);

        emit NGOApplied(msg.sender, _name, _registrationNumber);
    }

    function approveNGOApplication(address _applicant) external onlyAdmin {
        if (_applicant == address(0)) revert InvalidAddress();

        NGOApplication storage app = ngoApplications[_applicant];
        if (app.status != ApplicationStatus.Pending) revert ApplicationNotPending();

        app.status = ApplicationStatus.Approved;

        isVerifiedNGO[_applicant] = true;
        ngoInfo[_applicant] = NGOInfo({
            name: app.name,
            registrationNumber: app.registrationNumber,
            verifiedAt: block.timestamp,
            isActive: true
        });

        verifiedNGOCount++;
        _removeFromPending(_applicant);

        emit NGOApplicationApproved(_applicant, app.name);
        emit NGOVerified(_applicant, app.name, app.registrationNumber);
    }

    function rejectNGOApplication(address _applicant, string memory _reason) external onlyAdmin {
        if (_applicant == address(0)) revert InvalidAddress();

        NGOApplication storage app = ngoApplications[_applicant];
        if (app.status != ApplicationStatus.Pending) revert ApplicationNotPending();

        app.status = ApplicationStatus.Rejected;
        _removeFromPending(_applicant);

        emit NGOApplicationRejected(_applicant, _reason);
    }

    function _removeFromPending(address _addr) internal {
        for (uint256 i = 0; i < _pendingApplicants.length; i++) {
            if (_pendingApplicants[i] == _addr) {
                _pendingApplicants[i] = _pendingApplicants[_pendingApplicants.length - 1];
                _pendingApplicants.pop();
                break;
            }
        }
    }

    function getPendingApplications() external view returns (address[] memory) {
        return _pendingApplicants;
    }

    function getApplication(
        address _applicant
    )
        external
        view
        returns (
            string memory name,
            string memory registrationNumber,
            string memory website,
            string memory description,
            uint256 appliedAt,
            ApplicationStatus status
        )
    {
        NGOApplication memory app = ngoApplications[_applicant];
        if (app.appliedAt == 0) revert NoApplicationFound();
        return (
            app.name,
            app.registrationNumber,
            app.website,
            app.description,
            app.appliedAt,
            app.status
        );
    }

    function getPendingApplicationCount() external view returns (uint256) {
        return _pendingApplicants.length;
    }

    function verifyNGO(
        address _ngo,
        string memory _name,
        string memory _registrationNumber
    ) external onlyAdmin {
        if (_ngo == address(0)) revert InvalidAddress();
        if (isVerifiedNGO[_ngo]) revert AlreadyVerified();

        isVerifiedNGO[_ngo] = true;
        ngoInfo[_ngo] = NGOInfo({
            name: _name,
            registrationNumber: _registrationNumber,
            verifiedAt: block.timestamp,
            isActive: true
        });

        verifiedNGOCount++;

        emit NGOVerified(_ngo, _name, _registrationNumber);
    }

    function revokeNGO(address _ngo, string memory _reason) external onlyAdmin {
        if (_ngo == address(0)) revert InvalidAddress();
        if (!isVerifiedNGO[_ngo]) revert NGONotVerified();

        isVerifiedNGO[_ngo] = false;
        ngoInfo[_ngo].isActive = false;
        verifiedNGOCount--;

        emit NGORevoked(_ngo, _reason);
    }

    function pausePlatform() external onlyAdmin {
        paused = true;
        emit PlatformPausedEvent(msg.sender);
    }

    function unpausePlatform() external onlyAdmin {
        paused = false;
        emit PlatformUnpausedEvent(msg.sender);
    }

    function transferAdmin(address _newAdmin) external onlyAdmin {
        if (_newAdmin == address(0)) revert InvalidAddress();
        if (_newAdmin == platformAdmin) revert SelfTransferNotAllowed();
        pendingAdmin = _newAdmin;
        emit AdminTransferInitiated(msg.sender, _newAdmin);
    }

    function cancelAdminTransfer() external onlyAdmin {
        if (pendingAdmin == address(0)) revert NoPendingTransfer();
        pendingAdmin = address(0);
        emit AdminTransferCancelled(msg.sender);
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "Not pending admin");
        address previousAdmin = platformAdmin;
        platformAdmin = pendingAdmin;
        pendingAdmin = address(0);
        emit AdminTransferred(previousAdmin, platformAdmin);
    }

    function createCampaign(
        string memory _mission,
        uint256 _goal,
        uint256 _durationDays,
        string[] memory _mDescs,
        uint256[] memory _mAmounts,
        bool[] memory _mIsImpact
    ) external whenNotPaused returns (address) {
        if (!isVerifiedNGO[msg.sender]) revert NotVerifiedNGO();
        if (!ngoInfo[msg.sender].isActive) revert NGONotActive();

        if (
            _mDescs.length != _mAmounts.length ||
            _mDescs.length != _mIsImpact.length
        ) revert InvalidArrayLengths();
        if (_mDescs.length == 0 || _mDescs.length > 20) revert InvalidMilestoneData();

        require(_goal > 0, "Goal must be positive");
        require(_durationDays > 0, "Invalid duration");

        CharityCampaign newCampaign = new CharityCampaign(
            msg.sender,
            _mission,
            _goal,
            _durationDays,
            _mDescs,
            _mAmounts,
            _mIsImpact
        );

        address campaignAddress = address(newCampaign);
        allCampaigns.push(campaignAddress);
        ngoCampaigns[msg.sender].push(campaignAddress);
        isCampaign[campaignAddress] = true;

        emit CampaignCreated(campaignAddress, msg.sender, _mission, _goal);
        return campaignAddress;
    }

    function getCampaignsByNGO(address _ngo) external view returns (address[] memory) {
        return ngoCampaigns[_ngo];
    }

    function getCampaignCount() external view returns (uint256) {
        return allCampaigns.length;
    }

    function getNGOInfo(
        address _ngo
    )
        external
        view
        returns (
            string memory name,
            string memory registrationNumber,
            uint256 verifiedAt,
            bool isActive,
            bool isVerified,
            uint256 campaignCount
        )
    {
        NGOInfo memory info = ngoInfo[_ngo];
        return (
            info.name,
            info.registrationNumber,
            info.verifiedAt,
            info.isActive,
            isVerifiedNGO[_ngo],
            ngoCampaigns[_ngo].length
        );
    }

    function getCampaignsPaginated(
        uint256 _offset,
        uint256 _limit
    ) external view returns (address[] memory campaigns, uint256 total) {
        total = allCampaigns.length;
        if (_offset >= total) return (new address[](0), total);
        uint256 end = _offset + _limit;
        if (end > total) end = total;
        uint256 length = end - _offset;
        campaigns = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            campaigns[i] = allCampaigns[_offset + i];
        }
        return (campaigns, total);
    }

    function isRegisteredCampaign(address _campaign) external view returns (bool) {
        return isCampaign[_campaign];
    }

    function getPlatformStats()
        external
        view
        returns (
            uint256 totalCampaigns,
            uint256 totalVerifiedNGOs,
            bool isPaused,
            address admin
        )
    {
        return (allCampaigns.length, verifiedNGOCount, paused, platformAdmin);
    }
}
