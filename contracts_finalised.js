// ============================================================
// contracts_finalised.js — ABI definitions & network config
// v2 — includes NGO application system
// ============================================================

const NETWORK = {
  chainId: '0xa869', // Avalanche Fuji Testnet (43113 decimal)
  chainName: 'Avalanche Fuji Testnet',
  rpcUrls: ['https://api.avax-test.network/ext/bc/C/rpc'],
  nativeCurrency: { name: 'AVAX', symbol: 'AVAX', decimals: 18 },
  blockExplorerUrls: ['https://testnet.snowtrace.io/'],
};

// ⚠️  Replace this with your NEW deployed CharityManager address after redeploying
const MANAGER_ADDRESS = '0x436cb64A239a29b315a9B16deaC9b3737f762dce';

const MANAGER_ABI = [
  // ── View ──
  'function getCampaignsPaginated(uint256 _offset, uint256 _limit) external view returns (address[] campaigns, uint256 total)',
  'function getCampaignCount() external view returns (uint256)',
  'function getCampaignsByNGO(address _ngo) external view returns (address[])',
  'function getNGOInfo(address _ngo) external view returns (string name, string registrationNumber, uint256 verifiedAt, bool isActive, bool isVerified, uint256 campaignCount)',
  'function getPlatformStats() external view returns (uint256 totalCampaigns, uint256 totalVerifiedNGOs, bool isPaused, address admin)',
  'function isVerifiedNGO(address) external view returns (bool)',
  'function isRegisteredCampaign(address) external view returns (bool)',
  'function platformAdmin() external view returns (address)',
  'function paused() external view returns (bool)',
  'function pendingAdmin() external view returns (address)',
  'function verifiedNGOCount() external view returns (uint256)',
  // ── Application view ──
  'function getPendingApplications() external view returns (address[])',
  'function getPendingApplicationCount() external view returns (uint256)',
  'function getApplication(address _applicant) external view returns (string name, string registrationNumber, string website, string description, uint256 appliedAt, uint8 status)',
  'function ngoApplications(address) external view returns (string name, string registrationNumber, string website, string description, uint256 appliedAt, uint8 status)',
  // ── Write — Admin ──
  'function verifyNGO(address _ngo, string _name, string _registrationNumber) external',
  'function revokeNGO(address _ngo, string _reason) external',
  'function approveNGOApplication(address _applicant) external',
  'function rejectNGOApplication(address _applicant, string _reason) external',
  'function pausePlatform() external',
  'function unpausePlatform() external',
  'function transferAdmin(address _newAdmin) external',
  'function cancelAdminTransfer() external',
  'function acceptAdmin() external',
  // ── Write — NGO ──
  'function createCampaign(string _mission, uint256 _goal, uint256 _durationDays, string[] _mDescs, uint256[] _mAmounts, bool[] _mIsImpact) external returns (address)',
  // ── Write — Applicant ──
  'function applyAsNGO(string _name, string _registrationNumber, string _website, string _description) external',
  // ── Events ──
  'event NGOVerified(address indexed ngo, string name, string registrationNumber)',
  'event NGORevoked(address indexed ngo, string reason)',
  'event CampaignCreated(address indexed campaign, address indexed ngo, string mission, uint256 goal)',
  'event NGOApplied(address indexed applicant, string name, string registrationNumber)',
  'event NGOApplicationApproved(address indexed applicant, string name)',
  'event NGOApplicationRejected(address indexed applicant, string reason)',
];

const CAMPAIGN_ABI = [
  'function mission() external view returns (string)',
  'function targetGoal() external view returns (uint256)',
  'function campaignDeadline() external view returns (uint256)',
  'function totalRaised() external view returns (uint256)',
  'function adminSpent() external view returns (uint256)',
  'function impactSpent() external view returns (uint256)',
  'function currentMilestoneIndex() external view returns (uint256)',
  'function campaignActive() external view returns (bool)',
  'function campaignSuccessful() external view returns (bool)',
  'function deadlocked() external view returns (bool)',
  'function ngoAddress() external view returns (address)',
  'function donorContributions(address) external view returns (uint256)',
  'function hasVotedOnCurrent(address _voter) external view returns (bool)',
  'function getMilestoneCount() external view returns (uint256)',
  'function getMilestone(uint256 _index) external view returns (string description, uint256 amountToRelease, uint256 votesFor, uint256 votesAgainst, uint256 voteDeadline, bool fundsReleased, bool votingActive, bool isImpact, uint256 rejectionCount)',
  'function getCampaignStats() external view returns (uint256 _totalRaised, uint256 _targetGoal, uint256 _adminSpent, uint256 _impactSpent, uint256 _donorCount, uint256 _currentMilestone, uint256 _totalMilestones, bool _active, bool _successful, uint256 _deadline, bool _deadlocked)',
  'function getCurrentVotingProgress() external view returns (uint256 votesFor, uint256 votesAgainst, uint256 totalVotes, uint256 quorumRequired, bool quorumMet, uint256 deadline, bool active, uint256 rejectionCount)',
  'function getDonorCount() external view returns (uint256)',
  'function getDonorsPaginated(uint256 _offset, uint256 _limit) external view returns (address[] donors, uint256 total)',
  'function getRemainingFunds() external view returns (uint256)',
  'function donate() external payable',
  'function vote(bool _support) external',
  'function claimRefund() external',
  'function startMilestoneVoting() external',
  'function releaseFunds() external',
  'function finalizeCampaign() external',
  'event DonationReceived(address indexed donor, uint256 amount, uint256 newTotal)',
  'event VoteCast(uint256 indexed milestoneIndex, address indexed voter, bool support, uint256 weight)',
  'event FundsReleased(uint256 indexed milestoneIndex, uint256 amount, bool isImpact)',
  'event MilestoneRejected(uint256 indexed milestoneIndex, uint256 votesFor, uint256 votesAgainst, uint256 rejectionCount)',
  'event RefundClaimed(address indexed donor, uint256 amount)',
  'event CampaignDeadlocked(uint256 indexed milestoneIndex, uint256 rejectionCount)',
  'event CampaignFinalized(bool successful, uint256 totalRaised)',
];

// Application status enum mapping
const APP_STATUS = { 0: 'None', 1: 'Pending', 2: 'Approved', 3: 'Rejected' };
const APP_STATUS_BADGE = {
  0: 'badge-neutral',
  1: 'badge-warning',
  2: 'badge-success',
  3: 'badge-danger'
};

// ─── Wallet helpers ───────────────────────────────────────────

async function connectWallet() {
  if (!window.ethereum) throw new Error('MetaMask not found. Please install it.');
  await switchToFuji();
  const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
  return accounts[0];
}

async function switchToFuji() {
  try {
    await window.ethereum.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: NETWORK.chainId }],
    });
  } catch (err) {
    if (err.code === 4902) {
      await window.ethereum.request({ method: 'wallet_addEthereumChain', params: [NETWORK] });
    } else throw err;
  }
}

function getProvider() {
  if (!window.ethereum) throw new Error('MetaMask not found.');
  return new ethers.providers.Web3Provider(window.ethereum);
}

function getSigner() { return getProvider().getSigner(); }

function getManagerContract(signerOrProvider) {
  return new ethers.Contract(MANAGER_ADDRESS, MANAGER_ABI, signerOrProvider || getProvider());
}

function getCampaignContract(address, signerOrProvider) {
  return new ethers.Contract(address, CAMPAIGN_ABI, signerOrProvider || getProvider());
}

// ─── Formatting helpers ───────────────────────────────────────

function fmtAVAX(wei) {
  if (!wei) return '0 AVAX';
  return parseFloat(ethers.utils.formatEther(wei)).toLocaleString(undefined, { maximumFractionDigits: 4 }) + ' AVAX';
}

function fmtAddr(addr) {
  if (!addr) return '—';
  return addr.slice(0, 6) + '…' + addr.slice(-4);
}

function fmtDate(ts) {
  if (!ts) return '—';
  return new Date(Number(ts) * 1000).toLocaleDateString('en-MY', { day: 'numeric', month: 'short', year: 'numeric' });
}

function fmtCountdown(ts) {
  const diff = Number(ts) * 1000 - Date.now();
  if (diff <= 0) return 'Ended';
  const d = Math.floor(diff / 86400000);
  const h = Math.floor((diff % 86400000) / 3600000);
  const m = Math.floor((diff % 3600000) / 60000);
  const s = Math.floor((diff % 60000) / 1000);
  if (d > 0) return `${d}d ${h}h left`;
  if (h > 0) return `${h}h ${m}m left`;
  if (m > 0) return `${m}m ${s}s left`;
  return `${s}s left`;
}

function pct(a, b) {
  if (!b || b.isZero()) return 0;
  return Math.min(100, Math.round(a.mul(100).div(b).toNumber()));
}

function getCampaignLifecycle(stats) {
  const now = Math.floor(Date.now() / 1000);
  const campaignDeadline = stats._deadline;
  const totalRaised = stats._totalRaised;
  const targetGoal = stats._targetGoal;
  const deadlocked = Boolean(stats._deadlocked);
  const campaignSuccessful = stats._successful;
  const campaignActive = stats._active;
  const currentMilestoneIndex = stats._currentMilestone;
  const totalMilestones = stats._totalMilestones;
  const isExpired = Number(campaignDeadline) <= now;
  const conditionDeadlocked = deadlocked === true;
  const conditionFundingFailure = isExpired && totalRaised.lt(targetGoal);
  const conditionAbandoned = isExpired && totalRaised.gte(targetGoal) && currentMilestoneIndex.lt(totalMilestones);
  const fullyDelivered = totalRaised.gte(targetGoal) && currentMilestoneIndex.gte(totalMilestones);
  const contractRefundsActive = conditionDeadlocked || (!campaignActive && campaignSuccessful === false);
  const needsContractUpgradeForAbandonedRefund = !contractRefundsActive && conditionAbandoned && !campaignActive && campaignSuccessful === true;
  const refundsActive = contractRefundsActive;
  const shouldHideDonate = isExpired || deadlocked;
  const shouldFinalizeExpired = (conditionFundingFailure || conditionAbandoned) && campaignActive;
  const canAutoFinalizeOnRefund = conditionFundingFailure || conditionAbandoned;
  const shouldShowRefundPanel = refundsActive || shouldFinalizeExpired;

  return {
    campaignDeadline,
    totalRaised,
    targetGoal,
    deadlocked,
    campaignSuccessful,
    campaignActive,
    currentMilestoneIndex,
    totalMilestones,
    isExpired,
    conditionDeadlocked,
    conditionFundingFailure,
    conditionAbandoned,
    fullyDelivered,
    contractRefundsActive,
    needsContractUpgradeForAbandonedRefund,
    refundsActive,
    shouldHideDonate,
    shouldFinalizeExpired,
    canAutoFinalizeOnRefund,
    shouldShowRefundPanel,
  };
}

function statusBadge(active, successful, deadlocked, lifecycle) {
  if (lifecycle?.refundsActive) return { label: 'Campaign Failed - Refunds Active', cls: 'badge-danger' };
  if (lifecycle?.shouldFinalizeExpired) return { label: 'Campaign Expired - Refund Ready', cls: 'badge-warning' };
  if (deadlocked) return { label: 'Deadlocked', cls: 'badge-danger' };
  if (lifecycle?.fullyDelivered) return { label: 'Successful', cls: 'badge-success' };
  if (!active && successful) return { label: 'Successful', cls: 'badge-success' };
  if (!active && !successful) return { label: 'Failed', cls: 'badge-danger' };
  return { label: 'Active', cls: 'badge-active' };
}

// ─── Toast ───────────────────────────────────────────────────

function toast(msg, type = 'info') {
  const el = document.createElement('div');
  el.className = `toast toast-${type}`;
  el.textContent = msg;
  document.getElementById('toast-root')?.appendChild(el);
  setTimeout(() => el.classList.add('show'), 10);
  setTimeout(() => { el.classList.remove('show'); setTimeout(() => el.remove(), 300); }, 4000);
}

// ─── Tx helper ───────────────────────────────────────────────

const CUSTOM_ERROR_SELECTORS = {
  '0x0b4d6981': 'RefundNotAvailable',
};

function txErrorMessage(err) {
  const data = typeof err?.data === 'string'
    ? err.data
    : typeof err?.error?.data === 'string'
      ? err.error.data
      : '';
  const selector = data.slice(0, 10);
  if (CUSTOM_ERROR_SELECTORS[selector]) return `${CUSTOM_ERROR_SELECTORS[selector]}()`;
  return err?.reason || err?.data?.message || err?.error?.message || err?.message || 'Transaction failed';
}

async function sendTx(fn) {
  try {
    toast('Confirm in MetaMask…', 'info');
    const tx = await fn();
    toast('Transaction sent, waiting…', 'info');
    await tx.wait();
    toast('Transaction confirmed ✓', 'success');
    return true;
  } catch (err) {
    const msg = txErrorMessage(err);
    toast(msg, 'error');
    console.error(err);
    return false;
  }
}
