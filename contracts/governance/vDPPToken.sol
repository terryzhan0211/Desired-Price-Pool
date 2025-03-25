// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title vDPP Token
 * @dev Governance token for the Desired Price Pool protocol
 * Includes voting capabilities and is used for governance and incentives
 */
contract vDPPToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    // Cap on total supply - rename to avoid shadowing the cap() function
    uint256 private immutable _maxCap;
    
    /**
     * @dev Constructor that initializes the token with a name, symbol, and cap
     * @param initialSupply Initial amount to mint to the deployer
     * @param maxSupplyCap Maximum supply cap - renamed parameter to avoid shadowing
     */
    constructor(
        uint256 initialSupply,
        uint256 maxSupplyCap
    ) ERC20("Desired Price Pool Governance Token", "vDPP") 
      ERC20Permit("Desired Price Pool Governance Token")
      Ownable(msg.sender) {
        require(maxSupplyCap > 0, "vDPP: cap is 0");
        require(initialSupply <= maxSupplyCap, "vDPP: initial supply exceeds cap");
        
        _maxCap = maxSupplyCap;
        _mint(msg.sender, initialSupply);
    }
    
    /**
     * @dev Function to mint tokens
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= _maxCap, "vDPP: cap exceeded");
        _mint(to, amount);
    }
    
    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view returns (uint256) {
        return _maxCap;
    }
    
    // The following functions are overrides required by Solidity
    
    /**
     * @dev Override _update to update delegation values
     */
    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    /**
     * @dev Override nonces to resolve the contract inheritance issue
     * Must specify both parent contracts that implement nonces
     */
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /**
     * @dev Override clock method
     * Need to use Votes which is the base contract that actually defines clock()
     */
    function clock() public view override returns (uint48) {
        return super.clock();
    }

    /**
     * @dev Override CLOCK_MODE method
     * Need to use Votes which is the base contract that actually defines CLOCK_MODE()
     */
    function CLOCK_MODE() public view override returns (string memory) {
        return super.CLOCK_MODE();
    }
}