// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CharityCampaign
 * @notice Transparent, milestone-based charity campaign with donor governance
 */
contract CharityCampaign {
    struct Milestone {
        string description;
        uint256 amountToRelease;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 voteDeadline;
        bool fundsReleased;
        bool votingActive;
        bool isImpact;
        uint256 rejectionCount;
    }

    address public immutable ngoAddress;
    address public immutable manager;

    string public mission;
    uint256 public immutable targetGoal;
    uint256 public immutable campaignDeadline;
    uint256 public totalRaised;
    uint256 public adminSpent;
    uint256 public impactSpent;
    uint256 public currentMilestoneIndex;

    bool public campaignActive = true;
    bool public campaignSuccessful;
    bool public deadlocked;

    Milestone[] public milestones;
    address[] public donorList;

    mapping(address => uint256) public donorContributions;
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public hasVoted;
    mapping(uint256 => uint256) public milestoneVotingRound;
    mapping(address => bool) private isDonor;

    uint256 public constant VOTING_PERIOD = 300 seconds;
    uint256 public constant MIN_QUORUM_PERCENT = 30;
    uint256 public constant MAX_MILESTONE_REJECTIONS = 3;

    event DonationReceived(address indexed donor, uint256 amount, uint256 newTotal);
    event MilestoneVotingStarted(uint256 indexed milestoneIndex, uint256 deadline);
    event VoteCast(uint256 indexed milestoneIndex, address indexed voter, bool support, uint256 weight);
    event FundsReleased(uint256 indexed milestoneIndex, uint256 amount, bool isImpact);
    event MilestoneRejected(uint256 indexed milestoneIndex, uint256 votesFor, uint256 votesAgainst, uint256 rejectionCount);
    event RefundClaimed(address indexed donor, uint256 amount);
    event CampaignFinalized(bool successful, uint256 totalRaised);
    event CampaignDeadlocked(uint256 indexed milestoneIndex, uint256 rejectionCount);

    error OnlyNGO();
    error OnlyDonors();
    error CampaignInactive();
    error CampaignStillActive();
    error AlreadyVoted();
    error VotingNotActive();
    error InsufficientBalance();
    error QuorumNotMet();
    error VoteFailed();
    error FundsAlreadyReleased();
    error NoMilestonesLeft();
    error InvalidMilestoneSetup();
    error RefundNotAvailable();
    error TransferFailed();
    error NoContribution();
    error GoalNotReached();
    error CampaignIsDeadlocked();

    modifier onlyNGO() {
        if (msg.sender != ngoAddress) revert OnlyNGO();
        _;
    }

    modifier onlyDonors() {
        if (donorContributions[msg.sender] == 0) revert OnlyDonors();
        _;
    }

    modifier campaignIsActive() {
        _autoFinalizeIfExpired();
        if (!campaignActive) revert CampaignInactive();
        _;
    }

    constructor(
        address _ngo,
        string memory _mission,
        uint256 _goal,
        uint256 _durationSeconds,
        string[] memory _mDescs,
        uint256[] memory _mAmounts,
        bool[] memory _mIsImpact
    ) {
        require(_ngo != address(0), "Invalid NGO address");
        require(_goal > 0, "Goal must be positive");
        require(
            _mDescs.length == _mAmounts.length && _mDescs.length == _mIsImpact.length,
            "Array length mismatch"
        );
        require(_mDescs.length > 0, "At least one milestone required");

        uint256 totalMilestoneAmount;
        for (uint256 i = 0; i < _mAmounts.length; i++) {
            require(_mAmounts[i] > 0, "Milestone amount must be positive");
            totalMilestoneAmount += _mAmounts[i];
        }
        if (totalMilestoneAmount > _goal) revert InvalidMilestoneSetup();

        ngoAddress = _ngo;
        manager = msg.sender;
        mission = _mission;
        targetGoal = _goal;
        campaignDeadline = block.timestamp + _durationSeconds;

        for (uint256 i = 0; i < _mDescs.length; i++) {
            milestones.push(Milestone({
                description: _mDescs[i],
                amountToRelease: _mAmounts[i],
                votesFor: 0,
                votesAgainst: 0,
                voteDeadline: 0,
                fundsReleased: false,
                votingActive: false,
                isImpact: _mIsImpact[i],
                rejectionCount: 0
            }));
        }
    }

    function _isFullyDelivered() internal view returns (bool) {
        return currentMilestoneIndex >= milestones.length;
    }

    function _finalSuccessState() internal view returns (bool) {
        return totalRaised >= targetGoal && _isFullyDelivered();
    }

    function _autoFinalizeIfExpired() internal {
        if (campaignActive && block.timestamp >= campaignDeadline) {
            campaignActive = false;
            campaignSuccessful = _finalSuccessState();
            emit CampaignFinalized(campaignSuccessful, totalRaised);
        }
    }

    function donate() external payable campaignIsActive {
        require(block.timestamp < campaignDeadline, "Campaign deadline passed");
        require(msg.value > 0, "Must donate positive amount");

        if (!isDonor[msg.sender]) {
            donorList.push(msg.sender);
            isDonor[msg.sender] = true;
        }

        donorContributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit DonationReceived(msg.sender, msg.value, totalRaised);
    }

    function startMilestoneVoting() external onlyNGO {
        _autoFinalizeIfExpired();
        if (!campaignActive) revert CampaignInactive();
        if (totalRaised < targetGoal) revert GoalNotReached();
        if (deadlocked) revert CampaignIsDeadlocked();
        if (currentMilestoneIndex >= milestones.length) revert NoMilestonesLeft();

        Milestone storage m = milestones[currentMilestoneIndex];
        require(!m.votingActive, "Voting already active");
        require(!m.fundsReleased, "Milestone already completed");

        m.votingActive = true;
        milestoneVotingRound[currentMilestoneIndex]++;
        m.voteDeadline = block.timestamp + VOTING_PERIOD;
        m.votesFor = 0;
        m.votesAgainst = 0;

        emit MilestoneVotingStarted(currentMilestoneIndex, m.voteDeadline);
    }

    function vote(bool _support) external onlyDonors {
        _autoFinalizeIfExpired();
        if (!campaignActive) revert CampaignInactive();

        Milestone storage m = milestones[currentMilestoneIndex];

        if (!m.votingActive) revert VotingNotActive();
        require(block.timestamp < m.voteDeadline, "Voting period ended");
        uint256 round = milestoneVotingRound[currentMilestoneIndex];
        if (hasVoted[currentMilestoneIndex][round][msg.sender]) revert AlreadyVoted();

        uint256 weight = donorContributions[msg.sender];

        if (_support) {
            m.votesFor += weight;
        } else {
            m.votesAgainst += weight;
        }

        hasVoted[currentMilestoneIndex][round][msg.sender] = true;

        emit VoteCast(currentMilestoneIndex, msg.sender, _support, weight);
    }

    function releaseFunds() external onlyNGO {
        _autoFinalizeIfExpired();
        if (!campaignActive) revert CampaignInactive();
        if (currentMilestoneIndex >= milestones.length) revert NoMilestonesLeft();

        Milestone storage m = milestones[currentMilestoneIndex];

        if (!m.votingActive) revert VotingNotActive();
        require(block.timestamp >= m.voteDeadline, "Voting still in progress");
        if (m.fundsReleased) revert FundsAlreadyReleased();

        uint256 totalVotes = m.votesFor + m.votesAgainst;
        uint256 requiredQuorum = (totalRaised * MIN_QUORUM_PERCENT) / 100;
        if (totalVotes < requiredQuorum || m.votesFor <= m.votesAgainst) {
            m.votingActive = false;
            m.rejectionCount++;

            emit MilestoneRejected(currentMilestoneIndex, m.votesFor, m.votesAgainst, m.rejectionCount);

            if (m.rejectionCount >= MAX_MILESTONE_REJECTIONS) {
                deadlocked = true;
                campaignActive = false;
                campaignSuccessful = false;
                emit CampaignDeadlocked(currentMilestoneIndex, m.rejectionCount);
            }

            return;
        }

        if (address(this).balance < m.amountToRelease) revert InsufficientBalance();

        m.fundsReleased = true;
        m.votingActive = false;

        if (m.isImpact) {
            impactSpent += m.amountToRelease;
        } else {
            adminSpent += m.amountToRelease;
        }

        currentMilestoneIndex++;

        (bool success, ) = payable(ngoAddress).call{value: m.amountToRelease}("");
        if (!success) revert TransferFailed();

        emit FundsReleased(currentMilestoneIndex - 1, m.amountToRelease, m.isImpact);

        if (_isFullyDelivered()) {
            campaignActive = false;
            campaignSuccessful = true;
            emit CampaignFinalized(true, totalRaised);
        }
    }

    function finalizeCampaign() external {
        require(block.timestamp >= campaignDeadline, "Campaign not ended");
        require(campaignActive, "Already finalized");

        campaignActive = false;
        campaignSuccessful = _finalSuccessState();

        emit CampaignFinalized(campaignSuccessful, totalRaised);
    }

    function claimRefund() external {
        _autoFinalizeIfExpired();

        if (campaignActive) revert CampaignStillActive();
        if (campaignSuccessful && !deadlocked) revert RefundNotAvailable();

        uint256 contribution = donorContributions[msg.sender];
        if (contribution == 0) revert NoContribution();

        uint256 totalSpent = adminSpent + impactSpent;
        uint256 availableForRefund = totalRaised - totalSpent;
        uint256 refundAmount = (contribution * availableForRefund) / totalRaised;
        require(refundAmount > 0, "No refund available");

        uint256 contractBalance = address(this).balance;
        if (refundAmount > contractBalance) {
            refundAmount = contractBalance;
        }

        donorContributions[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        if (!success) revert TransferFailed();

        emit RefundClaimed(msg.sender, refundAmount);
    }

    function getRemainingFunds() external view returns (uint256) {
        return address(this).balance;
    }

    function getMilestoneCount() external view returns (uint256) {
        return milestones.length;
    }

    function getMilestone(uint256 _index) external view returns (
        string memory description,
        uint256 amountToRelease,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 voteDeadline,
        bool fundsReleased,
        bool votingActive,
        bool isImpact,
        uint256 rejectionCount
    ) {
        require(_index < milestones.length, "Invalid index");
        Milestone storage m = milestones[_index];
        return (
            m.description,
            m.amountToRelease,
            m.votesFor,
            m.votesAgainst,
            m.voteDeadline,
            m.fundsReleased,
            m.votingActive,
            m.isImpact,
            m.rejectionCount
        );
    }

    function getDonorsPaginated(
        uint256 _offset,
        uint256 _limit
    ) external view returns (address[] memory donors, uint256 total) {
        total = donorList.length;
        if (_offset >= total) return (new address[](0), total);

        uint256 end = _offset + _limit;
        if (end > total) end = total;

        uint256 length = end - _offset;
        donors = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            donors[i] = donorList[_offset + i];
        }
        return (donors, total);
    }

    function getDonorCount() external view returns (uint256) {
        return donorList.length;
    }

    function getCampaignStats() external view returns (
        uint256 _totalRaised,
        uint256 _targetGoal,
        uint256 _adminSpent,
        uint256 _impactSpent,
        uint256 _donorCount,
        uint256 _currentMilestone,
        uint256 _totalMilestones,
        bool _active,
        bool _successful,
        uint256 _deadline,
        bool _deadlocked
    ) {
        return (
            totalRaised,
            targetGoal,
            adminSpent,
            impactSpent,
            donorList.length,
            currentMilestoneIndex,
            milestones.length,
            campaignActive,
            campaignSuccessful,
            campaignDeadline,
            deadlocked
        );
    }

    function hasVotedOnCurrent(address _voter) external view returns (bool) {
        return hasVoted[currentMilestoneIndex][milestoneVotingRound[currentMilestoneIndex]][_voter];
    }

    function getCurrentVotingProgress() external view returns (
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 totalVotes,
        uint256 quorumRequired,
        bool quorumMet,
        uint256 deadline,
        bool active,
        uint256 rejectionCount
    ) {
        if (currentMilestoneIndex >= milestones.length) {
            return (0, 0, 0, 0, false, 0, false, 0);
        }

        Milestone storage m = milestones[currentMilestoneIndex];
        uint256 total = m.votesFor + m.votesAgainst;
        uint256 required = (totalRaised * MIN_QUORUM_PERCENT) / 100;

        return (
            m.votesFor,
            m.votesAgainst,
            total,
            required,
            total >= required,
            m.voteDeadline,
            m.votingActive,
            m.rejectionCount
        );
    }

    receive() external payable {
        require(campaignActive, "Campaign inactive");
        require(block.timestamp < campaignDeadline, "Campaign deadline passed");
        require(msg.value > 0, "Must send ETH");

        if (!isDonor[msg.sender]) {
            donorList.push(msg.sender);
            isDonor[msg.sender] = true;
        }

        donorContributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit DonationReceived(msg.sender, msg.value, totalRaised);
    }
}
