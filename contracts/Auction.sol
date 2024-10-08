// SPDX-License-Identifier: MIT
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
        BidStatus status;
    }

    mapping(address => mapping (uint256 => Item)) public items; // NFT_contract_address => NFTId => Item
    mapping(address => mapping (uint256 => address[])) public bidders; // NFT_contract_address => NFTId => bidders
    mapping(address => mapping (uint256 => uint256[])) public bidPrices; // NFT_contract_address => NFTId => bidPrices
    mapping(address => mapping (uint256 => mapping(uint256 => BidStatus))) public bidStatus; // NFT_contract_address => NFTId => bidIndex => status

    address public feeReceiver;
    uint256 public fee;
    uint256 public totalItemsBids;
    uint256 public totalBids;
    uint256 public penaltyFee; // recommended 30%
    uint256 public constant FEE_DENOMINATOR = 10000;

    // Modifier
    // Constructor
    constructor(address _feeReceiver, uint256 _fee, uint256 _penaltyFee) Ownable(msg.sender) {
        feeReceiver = _feeReceiver;
        fee = _fee;
        penaltyFee = _penaltyFee;
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
            paymentToken: _paymentToken,
            status: BidStatus.Available
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

    // 10 20 30 40 50 100
    function cancelBid(address _nftAddress, uint256 _nftId, uint256 _bidIndex) external whenNotPaused nonReentrant {
        require(bidStatus[_nftAddress][_nftId][_bidIndex] == BidStatus.Available, "Auction: Bid is not available");
        Item storage _item = items[_nftAddress][_nftId];
        require(_item.status == BidStatus.Available, "Auction: Bid is not available");
        _item.status = BidStatus.Cancelled;
        address _bidder = bidders[_nftAddress][_nftId][_bidIndex];
        require(_bidder == msg.sender, "Auction: Only bidder can cancel the bid");
        uint256 _price = bidPrices[_nftAddress][_nftId][_bidIndex];
        require(_item.lastBidPrice > _price, "Auction: Cannot cancel last bid");

        bidStatus[_nftAddress][_nftId][_bidIndex] = BidStatus.Cancelled;
        uint256 _penalty = _price * penaltyFee / FEE_DENOMINATOR;
        _transferToken(_bidder, _item.paymentToken, _price - _penalty);
        _transferToken(feeReceiver, _item.paymentToken, _penalty);
        emit BidCancelled(_nftAddress, _nftId, _bidder, _price);
    }

    function acceptBid(address _nftAddress, uint256 _nftId) external nonReentrant {
        Item storage _item = items[_nftAddress][_nftId];
        require(_item.status == BidStatus.Available, "Auction: Bid is not available");
        require(_item.owner == msg.sender, "Auction: Only owner can accept the bid");
        address _highestBidder = _item.highestBidder;
        uint256 _price = _item.lastBidPrice;
        uint256 _feeAmount = _price * fee / FEE_DENOMINATOR;
        uint256 _sellerAmount = _price - _feeAmount;
        _item.status = BidStatus.Accepted;
        bidStatus[_nftAddress][_nftId][bidders[_nftAddress][_nftId].length - 1] = BidStatus.Accepted;
        _transferToken(_item.owner, _item.paymentToken, _sellerAmount);
        _transferToken(feeReceiver, _item.paymentToken, _feeAmount);

        // back money to other bidders
        for (uint256 i = 0; i < bidders[_nftAddress][_nftId].length; i++) {
            if (bidStatus[_nftAddress][_nftId][i] == BidStatus.Available) {
                uint256 _bidPrice = bidPrices[_nftAddress][_nftId][i];
                address _bidder = bidders[_nftAddress][_nftId][i];
                _transferToken(_bidder, _item.paymentToken, _bidPrice);
                bidStatus[_nftAddress][_nftId][i] = BidStatus.Cancelled;
            }
        }
        IERC721(_nftAddress).transferFrom(address(this), _highestBidder, _nftId);
        emit BidAccepted(_nftAddress, _nftId, _highestBidder, _price);
    }

    // cancel auction
    // owner can cancel auction
    // back nft to owner
    // back money to bidders
    function cancelAuction(address _nftAddress, uint256 _nftId) external nonReentrant whenNotPaused {
        Item storage _item = items[_nftAddress][_nftId];
        require(_item.status == BidStatus.Available, "Auction: Auction is not available");
        require(_item.owner == msg.sender, "Auction: Only owner can cancel the auction");

        // Set auction status to Cancelled
        _item.status = BidStatus.Cancelled;

        // Transfer NFT back to the owner
        IERC721(_nftAddress).transferFrom(address(this), _item.owner, _nftId);

        // Refund all bidders
        for (uint256 i = 0; i < bidders[_nftAddress][_nftId].length; i++) {
            if (bidStatus[_nftAddress][_nftId][i] == BidStatus.Available) {
                address _bidder = bidders[_nftAddress][_nftId][i];
                uint256 _bidAmount = bidPrices[_nftAddress][_nftId][i];
                _transferToken(_bidder, _item.paymentToken, _bidAmount);
                bidStatus[_nftAddress][_nftId][i] = BidStatus.Cancelled;
            }
        }

        emit AuctionCancelled(_nftAddress, _nftId, _item.owner);
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
        bidPrices[_nftAddress][_nftId].push(_price);
        uint256 _totalBids = bidders[_nftAddress][_nftId].length;
        bidStatus[_nftAddress][_nftId][_totalBids - 1] = BidStatus.Available;
        _item.status = BidStatus.Available;
    }

    function _transferToken(address _receiver, address _token, uint256 _amount) internal {
        if (_token == address(0)) {
            payable(_receiver).transfer(_amount);
        } else {
            IERC20(_token).safeTransfer(_receiver, _amount);
        }
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

    function changePenaltyFee(uint256 _penaltyFee) external onlyOwner {
        penaltyFee = _penaltyFee;
    }

    // Events
    event AuctionCreated(address indexed nftAddress, uint256 indexed nftId, address indexed paymentToken, uint256 minPrice);
    event Bid(address indexed nftAddress, uint256 indexed nftId, address indexed bidder, uint256 price);
    event BidCancelled(address indexed nftAddress, uint256 indexed nftId, address indexed bidder, uint256 price);
    event BidAccepted(address indexed nftAddress, uint256 indexed nftId, address indexed bidder, uint256 price);
    event AuctionCancelled(address indexed nftAddress, uint256 indexed nftId, address indexed owner);

    // Fallback functions
    fallback() external {
        revert("Auction: Invalid function called");
    }
}