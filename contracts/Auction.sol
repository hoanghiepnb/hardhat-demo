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
    mapping(address => mapping (uint256 => address[])) public bidders; // NFT_contract_address => NFTId => bidders
    mapping(address => mapping (uint256 => mapping(uint256 => BidStatus))) public bidStatus; // NFT_contract_address => NFTId => bidIndex => status

    address public feeReceiver;
    uint256 public fee;
    uint256 public totalItemsBids;
    uint256 public totalBids;
    uint256 public penaltyFee; // recommended 30%
    uint256 public constant FEE_DENOMINATOR = 10000;

    // Modifier
    // Constructor
    constructor(address _feeReceiver, uint256 _fee) Ownable(msg.sender) {
        feeReceiver = _feeReceiver;
        fee = _fee;
    }
    // External functions

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

    // bid item 1 : 10, 11, 20, 30,
    function bid(address _nftAddress, uint256 _nftId, uint256 _price) external whenNotPaused nonReentrant payable {
        Item memory _item = items[_nftAddress][_nftId];
        address _bidder = msg.sender;
        if (_item.paymentToken != address (0))  { // payment token is ERC20
            require(_price > _item.lastBidPrice, "Auction: Bid price should be greater than last bid price");
            IERC20(_item.paymentToken).safeTransferFrom(_bidder, address(this), _price);
            _updateBidData(_nftAddress, _nftId, _bidder, _price);
        } else { // payment token is native token (ETH, BNB)
            uint256 _bidValue = msg.value;
            require(_bidValue > _item.lastBidPrice, "Auction: Bid price should be greater than last bid price");
            _updateBidData(_nftAddress, _nftId, _bidder, _bidValue);
        }
        emit Bid(_nftAddress, _nftId, _bidder, _price);
    }

    function cancelBid(address _nftAddress, uint256 _nftId, uint256 _bidIndex) external whenNotPaused nonReentrant {
        require(bidStatus[_nftAddress][_nftId][_bidIndex] == BidStatus.Available, "Auction: Bid is not available");
        Item storage _item = items[_nftAddress][_nftId];
        address _bidder = bidders[_nftAddress][_nftId][_bidIndex];
        uint256 _price = _item.lastBidPrice;
        if (_item.paymentToken != address(0)) {
            IERC20(_item.paymentToken).safeTransfer(_bidder, _price);
        } else {
            payable(_bidder).transfer(_price);
        }
        bidStatus[_nftAddress][_nftId][_bidIndex] = BidStatus.Cancelled;
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

    function _updateBidData(address _nftAddress, uint256 _nftId, address _bidder, uint256 _price) internal {
        Item storage _item = items[_nftAddress][_nftId];
        _item.lastBidPrice = _price;
        _item.highestBidder = _bidder;
        bidders[_nftAddress][_nftId].push(_bidder);
        uint256 totalBids = bidders[_nftAddress][_nftId].length;
        bidStatus[_nftAddress][_nftId][totalBids - 1] = BidStatus.Available;
    }

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
    event Bid(address indexed nftAddress, uint256 indexed nftId, address indexed bidder, uint256 price);

    // Fallback functions
    fallback() external {
        revert("Auction: Invalid function called");
    }
}