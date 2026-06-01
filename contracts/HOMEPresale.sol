// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title HOME Presale Contract
 * @notice Accepts USDT (BEP-20) on BSC for $HOME token private sale
 * @dev Deploy on BSC Mainnet (Chain ID 56) or Testnet (97)
 *
 * USDT BSC Address: 0x55d398326f99059fF775485246999027B3197955
 *
 * Tiers:
 *   Seed:    $0.08/token, 30% bonus, 1,000-50,000 USDT
 *   Private: $0.10/token, 15% bonus,   500-30,000 USDT
 *   Public:  $0.15/token,  5% bonus,   100-10,000 USDT
 *
 * Caps: Soft = 150,000 USDT | Hard = 500,000 USDT
 */
contract HOMEPresale {
    // ── Errors ──
    error NotOwner();
    error PresaleNotActive();
    error BelowMinimum(uint256 min);
    error AboveMaximum(uint256 max);
    error HardCapReached();
    error TierFull();
    error TransferFailed();
    error InvalidTier();

    // ── Events ──
    event Contributed(
        address indexed user,
        string tier,
        uint256 usdtAmount,
        uint256 tokenAmount,
        uint256 bonusTokens,
        uint256 timestamp
    );
    event CapsUpdated(uint256 softCap, uint256 hardCap);
    event TierUpdated(string tier, uint256 price, uint256 maxContributors);
    event PresaleToggled(bool active);
    event FundsWithdrawn(address to, uint256 amount);

    // ── Structs ──
    struct Tier {
        uint256 price;           // USDT wei per token (e.g., 0.08 * 1e18)
        uint256 bonusBps;        // Bonus in basis points (3000 = 30%)
        uint256 minContribution; // Min USDT wei
        uint256 maxContribution; // Max USDT wei per wallet
        uint256 contributorCount;
        uint256 maxContributors; // 0 = unlimited
    }

    // ── State ──
    IERC20 public immutable usdt;
    address public immutable treasuryWallet;
    address public immutable owner;
    uint256 public immutable deployTime;

    uint256 public totalRaised;          // Total USDT received (wei)
    uint256 public softCap;              // 150,000 USDT (wei)
    uint256 public hardCap;              // 500,000 USDT (wei)
    bool public isActive = true;

    mapping(string => Tier) public tiers;
    mapping(address => uint256) public contributions;   // USDT contributed per wallet
    mapping(address => uint256) public tokensOwed;      // $HOME tokens owed per wallet
    mapping(address => string) public userTier;          // Which tier each user chose
    string[] public tierKeys;                             // ["seed", "private", "public"]
    address[] public contributors;                        // List of all contributor addresses

    // ── Constructor ──
    constructor(
        address _usdt,
        address _treasuryWallet
    ) {
        require(_usdt != address(0), "Invalid USDT");
        require(_treasuryWallet != address(0), "Invalid wallet");

        usdt = IERC20(_usdt);
        treasuryWallet = _treasuryWallet;
        owner = msg.sender;
        deployTime = block.timestamp;

        // Caps: 150k / 500k USDT
        softCap = 150_000 * 1e18;
        hardCap = 500_000 * 1e18;

        // Seed tier: $0.08, 30% bonus, 1k-50k USDT, max 500 contributors
        _setTier("seed",      0.08 ether, 3000, 1_000 ether, 50_000 ether, 500);
        // Private tier: $0.10, 15% bonus, 500-30k USDT, max 1000 contributors
        _setTier("private",   0.10 ether, 1500,   500 ether, 30_000 ether, 1000);
        // Public tier: $0.15, 5% bonus, 100-10k USDT, unlimited
        _setTier("public",    0.15 ether,  500,   100 ether, 10_000 ether, 0);
    }

    function _setTier(
        string memory _key,
        uint256 _price,
        uint256 _bonusBps,
        uint256 _min,
        uint256 _max,
        uint256 _maxContributors
    ) internal {
        tiers[_key] = Tier(_price, _bonusBps, _min, _max, 0, _maxContributors);
        tierKeys.push(_key);
    }

    // ── Public: Contribute ──

    /**
     * @notice Contribute USDT to the presale
     * @param _amount Amount of USDT to contribute (in wei, 18 decimals)
     * @param _tier  Tier key: "seed", "private", or "public"
     *
     * Flow:
     *   1. User calls USDT.approve(presaleAddress, _amount) first
     *   2. User calls contribute(_amount, "private")
     *   3. Contract transfers USDT from user → treasuryWallet
     *   4. Contract records contribution + calculates $HOME tokens owed
     */
    function contribute(uint256 _amount, string calldata _tier) external {
        if (!isActive) revert PresaleNotActive();
        if (totalRaised + _amount > hardCap) revert HardCapReached();

        Tier storage tier = tiers[_tier];
        if (tier.price == 0) revert InvalidTier();
        if (_amount < tier.minContribution) revert BelowMinimum(tier.minContribution);
        if (_amount > tier.maxContribution) revert AboveMaximum(tier.maxContribution);
        if (tier.maxContributors > 0 && tier.contributorCount >= tier.maxContributors) revert TierFull();

        // Calculate tokens
        // tokens = (_amount / price) * 1e18
        uint256 baseTokens = (_amount * 1e18) / tier.price;
        uint256 bonusTokens = (baseTokens * tier.bonusBps) / 10_000;
        uint256 totalTokens = baseTokens + bonusTokens;

        // Transfer USDT from user to treasury
        bool success = usdt.transferFrom(msg.sender, treasuryWallet, _amount);
        if (!success) revert TransferFailed();

        // Update state
        contributions[msg.sender] += _amount;
        tokensOwed[msg.sender] += totalTokens;
        totalRaised += _amount;

        // Track tier
        if (bytes(userTier[msg.sender]).length == 0) {
            userTier[msg.sender] = _tier;
            tier.contributorCount++;
            contributors.push(msg.sender);
        }

        emit Contributed(msg.sender, _tier, _amount, baseTokens, bonusTokens, block.timestamp);
    }

    // ── View: User Info ──

    /**
     * @notice Get full contribution info for a user
     */
    function getUserInfo(address _user) external view returns (
        uint256 _contributed,
        uint256 _tokensOwed,
        string memory _tier,
        uint256 _tierBonusBps
    ) {
        _contributed = contributions[_user];
        _tokensOwed = tokensOwed[_user];
        _tier = userTier[_user];
        if (bytes(_tier).length > 0) {
            _tierBonusBps = tiers[_tier].bonusBps;
        }
    }

    /**
     * @notice Get progress toward caps
     */
    function getProgress() external view returns (
        uint256 _totalRaised,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _contributorCount,
        bool _softCapReached,
        bool _isActive
    ) {
        _totalRaised = totalRaised;
        _softCap = softCap;
        _hardCap = hardCap;
        _contributorCount = contributors.length;
        _softCapReached = totalRaised >= softCap;
        _isActive = isActive;
    }

    /**
     * @notice Get tier info
     */
    function getTierInfo(string calldata _key) external view returns (
        uint256 price,
        uint256 bonusBps,
        uint256 minContrib,
        uint256 maxContrib,
        uint256 contributorCount,
        uint256 maxContributors
    ) {
        Tier storage t = tiers[_key];
        return (t.price, t.bonusBps, t.minContribution, t.maxContribution,
                t.contributorCount, t.maxContributors);
    }

    /**
     * @notice Get all contributor addresses (paginated)
     */
    function getContributorCount() external view returns (uint256) {
        return contributors.length;
    }

    // ── Owner: Admin ──

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function updateCaps(uint256 _softCap, uint256 _hardCap) external onlyOwner {
        softCap = _softCap;
        hardCap = _hardCap;
        emit CapsUpdated(_softCap, _hardCap);
    }

    function updateTier(
        string calldata _key,
        uint256 _price,
        uint256 _bonusBps,
        uint256 _min,
        uint256 _max,
        uint256 _maxContributors
    ) external onlyOwner {
        tiers[_key] = Tier(_price, _bonusBps, _min, _max,
                           tiers[_key].contributorCount, _maxContributors);
        emit TierUpdated(_key, _price, _maxContributors);
    }

    function togglePresale() external onlyOwner {
        isActive = !isActive;
        emit PresaleToggled(isActive);
    }

    /**
     * @notice Withdraw any BNB accidentally sent to contract
     */
    function withdrawBNB() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool ok, ) = treasuryWallet.call{value: balance}("");
            require(ok, "BNB withdraw failed");
        }
    }

    /**
     * @notice Emergency: recover tokens other than USDT sent to contract
     */
    function recoverToken(address _token) external onlyOwner {
        require(_token != address(usdt), "Cannot recover USDT");
        IERC20 tok = IERC20(_token);
        uint256 bal = tok.balanceOf(address(this));
        if (bal > 0) tok.transfer(treasuryWallet, bal);
    }

    // ── Receive (reject accidental BNB sends) ──
    receive() external payable {
        // Accept BNB but log it — owner can withdraw via withdrawBNB()
    }
}

// ── Interface ──

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint8);
}
