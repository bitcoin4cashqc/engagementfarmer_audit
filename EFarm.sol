// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract EFarm is ERC20, Ownable, AccessControl, ReentrancyGuard {
    uint256 public constant MAX_SUPPLY = 1_000_000_000_000e18; // 1 trillion tokens
    uint256 public constant INITIAL_SUPPLY = 111_111_110_000e18; // 11.1111% of total supply

    uint8 public constant MAX_PHASE = 8;

    bytes32 public constant PHASE_ADMIN_ROLE = keccak256("PHASE_ADMIN_ROLE");
    bytes32 public constant TOKEN_MINTER_ROLE = keccak256("TOKEN_MINTER_ROLE");
    bytes32 public constant TOKEN_BURNER_ROLE = keccak256("TOKEN_BURNER_ROLE");
    bytes32 public constant FREEZER_ROLE = keccak256("FREEZER_ROLE");

    uint8 public currentPhase;
    mapping(uint8 => uint256) public phaseLimit;
    mapping(uint8 => bool) public phaseClosed;

    uint256 private awarded;

    bool public isFrozen;

    // Replacing the UserPhaseData struct with an internal balance
    mapping(address => uint256) public userBalances; // Tracks user internal balances for rewards

    constructor(address initialOwner) ERC20("EFarm", "FARM") Ownable(initialOwner) {
        _mint(initialOwner, INITIAL_SUPPLY);
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(PHASE_ADMIN_ROLE, initialOwner);
        _grantRole(TOKEN_MINTER_ROLE, initialOwner);
        _grantRole(TOKEN_BURNER_ROLE, initialOwner);
        _grantRole(FREEZER_ROLE, initialOwner);

        awarded = 0;
    }

    modifier validPhase(uint8 phase) {
        require(phase < MAX_PHASE, "invalid phase");
        _;
    }

    function mint(address to, uint256 amount) external onlyRole(TOKEN_MINTER_ROLE) notFrozen {
        require(totalSupply() + amount <= MAX_SUPPLY, "EFarm: cap exceeded");
        _mint(to, amount);
    }

    function burn(uint256 amount) external onlyRole(TOKEN_BURNER_ROLE) notFrozen {
        _burn(msg.sender, amount);
    }

    function assignRoles(address account, bool[] memory roles) external onlyOwner {
        require(roles.length == 4, "Invalid roles array length");
        if (roles[0]) _grantRole(PHASE_ADMIN_ROLE, account);
        if (roles[1]) _grantRole(TOKEN_MINTER_ROLE, account);
        if (roles[2]) _grantRole(TOKEN_BURNER_ROLE, account);
        if (roles[3]) _grantRole(FREEZER_ROLE, account);
    }

    function setPhaseLimits(uint8[] memory phases, uint256[] memory limits)
        external
        onlyRole(PHASE_ADMIN_ROLE)
        notFrozen
    {
        require(phases.length <= MAX_PHASE, "Too many phases");
        require(phases.length == limits.length, "Mismatched array lengths");
        uint256 totalLimits = 0;

        for (uint256 i = 0; i < phases.length; i++) {
            phaseLimit[phases[i]] = limits[i];
            totalLimits += limits[i];
        }

        require(totalLimits <= INITIAL_SUPPLY, "Total limits exceed initial supply");
    }

    function updateTokenAmounts(address[] memory users, uint256[] memory tokenAmounts)
    external
    onlyRole(PHASE_ADMIN_ROLE)
    notFrozen
    {
        require(users.length == tokenAmounts.length, "Users and tokenAmounts length mismatch");
        require(!phaseClosed[currentPhase], "Phase already closed");

        uint256 phaseTotal = awarded;  // Total amount of tokens distributed in this phase
        for (uint256 i = 0; i < users.length; i++) {
            userBalances[users[i]] = tokenAmounts[i];  // Directly update the user's balance
            phaseTotal += tokenAmounts[i];  // Add the new token amount to the phase total
        }

        require(phaseTotal <= phaseLimit[currentPhase], "Phase limit exceeded");
        awarded = phaseTotal;  // Update the awarded total
    }

    function closeCurrentPhase() external onlyRole(PHASE_ADMIN_ROLE) notFrozen {
        require(!phaseClosed[currentPhase], "Phase already closed");
        phaseClosed[currentPhase] = true;
        currentPhase++;
        awarded = 0;
    }

    function claimRewards() external notFrozen nonReentrant {
        uint256 amount = userBalances[msg.sender];
        require(amount > 0, "No tokens to claim");

        userBalances[msg.sender] = 0; // Reset the user's balance

        require(balanceOf(owner()) >= amount, "Insufficient token reserve for payout");

        _transfer(owner(), msg.sender, amount);
    }

    function getCurrentPhase() external view returns (uint8) {
        return currentPhase;
    }

    function getPhaseLimits() external view returns (uint8[] memory, uint256[] memory) {
        uint8[] memory phases = new uint8[](MAX_PHASE);
        uint256[] memory limits = new uint256[](MAX_PHASE);

        for (uint8 i = 0; i < MAX_PHASE; i++) {
            phases[i] = i;
            limits[i] = phaseLimit[i];
        }

        return (phases, limits);
    }

    function getCurrentPhaseRewards() external view returns (uint256) {
        return awarded;
    }

    function isPhaseClosed(uint8 phase) external view validPhase(phase) returns (bool) {
        return phaseClosed[phase];
    }

    function getTokenAmountsByAddress(address user) external view returns (uint256) {
        return userBalances[user]; // Return the user's balance
    }

    modifier notFrozen() {
        require(!isFrozen, "Contract is frozen");
        _;
    }

    function freezeContract() external onlyRole(FREEZER_ROLE) {
        isFrozen = true;
    }

    function unfreezeContract() external onlyRole(FREEZER_ROLE) {
        isFrozen = false;
    }
}
