pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Auction is Ownable, Pausable, ReentrancyGuard, IERC721Receiver{
    using SafeERC20 for IERC20;
    // Variables
    enum BidStatus {
        Available,
        Cancelled,
        Accepted
    }

    struct Item {
        uint256 lastBidPrice;
        uint256 minPrice;
        uint256 createdTime;
        address owner;
        address highestBidder;
        address paymentToken;
    }

    mapping(address => mapping (uint256 => Item)) public items; // NFT_contract_address => NFTId => Item
    mapping(address => mapping (uint256 => uint256[])) public bidders; // NFT_contract_address => NFTId => bidders
    mapping(address => mapping (uint256 => mapping(uint256 => BidStatus))) public bidStatus; // NFT_contract_address => NFTId => bidIndex => status

    address public feeReceiver;
    uint256 public fee;
    uint256 public totalItemsBids;
    uint256 public totalBids;
    uint256 public constant FEE_DENOMINATOR = 10000;

    // Modifier
    // Constructor
    constructor(address _feeReceiver, uint256 _fee) Ownable(msg.sender) {
        feeReceiver = _feeReceiver;
        fee = _fee;
    }
    // External functions

    // IERC721Receiver functions
    function createAuction(address _nftAddress, uint256 _nftId, address _paymentToken, uint256 _minPrice) external whenNotPaused nonReentrant {
        require(_minPrice > 0, "Auction: Price should be greater than zero");
        IERC721(_nftAddress).transferFrom(msg.sender, address(this), _nftId);
        items[_nftAddress][_nftId] = Item({
            lastBidPrice: 0,
            minPrice: _minPrice,
            createdTime: block.timestamp,
            owner: msg.sender,
            highestBidder: address(0),
            paymentToken: _paymentToken
        });
        totalItemsBids++;
        emit AuctionCreated(_nftAddress, _nftId, _paymentToken, _minPrice);
    }

    function bid() external {

    }

    function cancelBid() external {

    }

    function acceptBid() external {

    }

    function cancelAuction() external {

    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // View functions
    // Internal functions
    // Private functions
    // Restricted functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function changeFeeReceiver(address _feeReceiver) external onlyOwner {
        feeReceiver = _feeReceiver;
    }

    function changeFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    // Events
    event AuctionCreated(address indexed nftAddress, uint256 indexed nftId, address indexed paymentToken, uint256 minPrice);

    // Fallback functions
    fallback() external {
        revert("Auction: Invalid function called");
    }
}