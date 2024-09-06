//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract MarketPlace is Ownable, Pausable, ReentrancyGuard, IERC721Receiver {
    // accept only ROBOT contract
    // hold NFT in contract
    // transfer NFT to buyer
    // transfer payment to owner
    // 5% fee transfer to treasury
    // accept only payment in USDT

    using SafeERC20 for IERC20;

    enum Status {
        Open,
        Sold,
        Cancelled
    }

    struct Item {
        uint256 price;
        uint256 createdTime;
        address owner;
        Status status;
    }

    // Variables
    IERC721 public robotContract;
    IERC20 public USDT;
    address public treasury;
    uint256 public fee;
    uint256 public totalItemsSold;
    uint256 public totalItemsListed;

    mapping(uint256 => Item) public items; // NFTId => Item
    Item[] public itemsListed;
    uint256 public constant FEE_DENOMINATOR = 10000;
    // Modifier
    // Constructor
    constructor(IERC721 _robotContract, IERC20 _USDT, uint256 _fee, address _treasury) Ownable(msg.sender) {
        robotContract = _robotContract;
        USDT = _USDT;
        fee = _fee;
        treasury = _treasury;
    }

    // External functions

    // get NFT from owner's address
    // transfer NFT to marketplace contract
    // set price, owner, status
    function list(uint256 _tokenId, uint256 _price) external whenNotPaused nonReentrant {
        require(_price > 0, "MarketPlace: Price should be greater than zero");
        robotContract.safeTransferFrom(msg.sender, address(this), _tokenId);

        Item memory item = Item({
            price: _price,
            createdTime: block.timestamp,
            owner: msg.sender,
            status: Status.Open
        });
        items[_tokenId] = item;
        itemsListed.push(item);
        totalItemsListed++;
        emit Listed(_tokenId, _price, block.timestamp, msg.sender);
    }

    // calculate fee amount
    // transfer fee amount to treasury
    // transfer remaining amount to owner
    // update item status
    // transfer NFT to buyer
    function buy(uint256 _tokenId) external whenNotPaused nonReentrant {
        Item storage item = items[_tokenId];
        require(item.owner != address(0), "MarketPlace: Item not listed");
        require(item.status == Status.Open, "MarketPlace: Item is already sold");

        uint256 feeAmount = (item.price * fee) / FEE_DENOMINATOR;
        uint256 amount = item.price - feeAmount;
        USDT.safeTransferFrom(msg.sender, treasury, feeAmount);
        USDT.safeTransferFrom(msg.sender, item.owner, amount);
        // update item status
        item.status = Status.Sold;
        totalItemsSold++;
        robotContract.safeTransferFrom(address(this), msg.sender, _tokenId);
        emit Sold(_tokenId, item.price, msg.sender, item.owner);
    }

    // change price of NFT
    function changePrice(uint256 _tokenId, uint256 _price) external whenNotPaused nonReentrant {
        require (_price > 0, "MarketPlace: Price should be greater than zero");
        Item storage item = items[_tokenId];
        require(item.owner == msg.sender, "MarketPlace: Only owner can change price");
        item.price = _price;
    }

    // update item status
    // transfer NFT to owner
    function cancelSale(uint256 _tokenId) external whenNotPaused nonReentrant {
        Item storage item = items[_tokenId];
        require(item.owner == msg.sender, "MarketPlace: Only owner can cancel sale");
        require(item.status == Status.Open, "MarketPlace: Item is already sold");
        item.status = Status.Cancelled;
        robotContract.safeTransferFrom(address(this), msg.sender, _tokenId);
        emit Cancelled(_tokenId, msg.sender);
    }

    // IERC721Receiver functions
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // View functions
    function getItemsListed() external view returns (Item[] memory) {
        return itemsListed;
    }

    // Internal functions
    // Private functions
    // Restricted functions

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setFee(uint256 _newFee) external onlyOwner {
        require(_newFee < FEE_DENOMINATOR, "MarketPlace: Fee should be less than 100%");
        fee = _newFee;
    }

    function setTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "MarketPlace: Treasury address cannot be zero");
        treasury = _newTreasury;
    }

    // Events
    event Listed(uint256 indexed tokenId, uint256 price, uint256 createdTime, address owner);
    event Sold(uint256 indexed tokenId, uint256 price, address buyer, address seller);
    event Cancelled(uint256 indexed tokenId, address owner);
}