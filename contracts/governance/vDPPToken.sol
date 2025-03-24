// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract vDPPToken is ERC20, ERC20Votes, Ownable {
    // Maximum supply caps for different allocation categories
    uint256 public constant MAX_LP_SUPPLY = 60_000_000 * 10**18; // 60% for Liquidity Providers
    uint256 public constant MAX_TREASURY_SUPPLY = 20_000_000 * 10**18; // 20% for Treasury
    uint256 public constant MAX_TEAM_SUPPLY = 15_000_000 * 10**18; // 15% for Team & Advisors
    uint256 public constant MAX_SEED_SUPPLY = 5_000_000 * 10**18; // 5% for Early Supporters

    // Track minted tokens for each category
    uint256 public lpMinted;
    uint256 public treasuryMinted;
    uint256 public teamMinted;
    uint256 public seedMinted;

    // DPP Hook contract address that can mint LP rewards
    address public dppHook;

    // Team vesting information
    uint256 public teamVestingStart;
    uint256 public teamVestingDuration = 4 * 365 days; // 4 years
    uint256 public teamVestingCliff = 365 days; // 1 year cliff

    constructor() ERC20("vDPP Governance Token", "vDPP") Ownable(msg.sender) ERC20Permit("vDPP") {
        teamVestingStart = block.timestamp;
        
        // Initial mint to treasury for initial operations
        _mint(msg.sender, 2_000_000 * 10**18); // 2M tokens
        treasuryMinted += 2_000_000 * 10**18;
    }

    // Set the DPP Hook contract address
    function setDPPHook(address _dppHook) external onlyOwner {
        dppHook = _dppHook;
    }

    // Mint tokens to liquidity providers (only callable by the DPP Hook)
    function mintLPRewards(address recipient, uint256 amount) external {
        require(msg.sender == dppHook, "Only DPP Hook can mint LP rewards");
        require(lpMinted + amount <= MAX_LP_SUPPLY, "Exceeds LP allocation");
        
        _mint(recipient, amount);
        lpMinted += amount;
    }

    // Mint tokens to the treasury (only owner)
    function mintTreasury(address recipient, uint256 amount) external onlyOwner {
        require(treasuryMinted + amount <= MAX_TREASURY_SUPPLY, "Exceeds treasury allocation");
        
        _mint(recipient, amount);
        treasuryMinted += amount;
    }

    // Mint tokens to team members with vesting (only owner)
    function mintTeam(address recipient, uint256 amount) external onlyOwner {
        require(teamMinted + amount <= MAX_TEAM_SUPPLY, "Exceeds team allocation");
        require(block.timestamp >= teamVestingStart + teamVestingCliff, "Vesting cliff not reached");
        
        uint256 vestedPercentage = ((block.timestamp - teamVestingStart) * 100) / teamVestingDuration;
        if (vestedPercentage > 100) vestedPercentage = 100;
        
        uint256 vestedAmount = (amount * vestedPercentage) / 100;
        require(vestedAmount > 0, "No tokens vested yet");
        
        _mint(recipient, vestedAmount);
        teamMinted += vestedAmount;
    }

    // Mint tokens to early supporters (only owner)
    function mintSeed(address recipient, uint256 amount) external onlyOwner {
        require(seedMinted + amount <= MAX_SEED_SUPPLY, "Exceeds seed allocation");
        
        _mint(recipient, amount);
        seedMinted += amount;
    }

    // Override required functions for ERC20Votes
    function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}