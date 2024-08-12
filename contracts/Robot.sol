// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract Robot is Ownable, Pausable, ReentrancyGuard, ERC721Burnable {
    // Variables
    string public URI;
    uint256 public totalSupply;
    // Modifier

    // Constructor
    constructor(string memory _name, string memory _symbol) Ownable(msg.sender) ERC721(_name, _symbol) {
    }

    // External functions
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override whenNotPaused {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override whenNotPaused {
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    // View functions

    // Internal functions
    function _baseURI() internal view override returns (string memory) {
        return URI;
    }

    // Private functions

    // Restricted functions
    function setURI(string memory _URI) external onlyOwner {
        URI = _URI;
    }

    function mint(address _to) external onlyOwner {
        _safeMint(_to, totalSupply++);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
    // Events
}