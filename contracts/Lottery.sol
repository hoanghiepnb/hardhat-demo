pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Lottery is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    enum Status {
        Open,
        Closed
    }

    // Variables
    struct RoundData {
        uint256 startTime;
        uint256 endTime;
        uint256 totalReward;
        uint256 totalTickets;
        uint256 luckyNumber;
        Status status;
    }

    // mua ve 10 5 lan
    mapping(uint256 => RoundData) public rounds;
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public userTickets; // user => roundIndex => ticketNumber => count
    mapping(uint256 => mapping(uint256 => uint256)) public ticketsPerRound; // roundIndex => number => count
    mapping(uint256 => mapping(uint256 => EnumerableSet.AddressSet)) private ticketHolders; // roundIndex => number => user
    mapping(address => uint256) public pendingRewards; // user => reward

    IERC20 public USDT;
    uint256 public currentRoundIndex;
    uint256 public megaRewardPercentage; // default 50%

    uint256 public ticketPrice;
    uint256 public constant ONE_HUNDRED_PERCENT = 10000;

    // Modifier
    modifier onlyOperator() {
        require(msg.sender == owner(), "Lottery: Only operator can call this function");
        _;
    }

    // Constructor
    constructor(IERC20 _USDT, uint256 _ticketPrice, uint256 _megaRePer) Ownable(msg.sender) {
        USDT = _USDT;
        ticketPrice = _ticketPrice;
        megaRewardPercentage = _megaRePer;
        currentRoundIndex = 1;
    }

    // External functions
    function buyTicket(uint256[] calldata _ticketNumbers, uint256[] calldata _amounts) external whenNotPaused nonReentrant {
        RoundData storage _currentRound = rounds[currentRoundIndex];
        require(_ticketNumbers.length == _amounts.length, "Lottery: Invalid input");
        require(_ticketNumbers.length > 0, "Lottery: Invalid input");

        require(block.timestamp >= _currentRound.startTime, "Lottery: Round not started yet");
        require(_currentRound.status == Status.Open, "Lottery: Round is closed");
        uint256 _totalAmount = 0;
        address _buyer = msg.sender;

        for (uint256 i = 0; i < _ticketNumbers.length; i++) {
            uint256 _ticketNumber = _ticketNumbers[i];
            uint256 _amount = _amounts[i];
            userTickets[_buyer][currentRoundIndex][_ticketNumber] += _amount;
            ticketsPerRound[currentRoundIndex][_ticketNumber] += _amount;
            ticketHolders[currentRoundIndex][_ticketNumber].add(_buyer);
        }
        _currentRound.totalTickets += _ticketNumbers.length;
        _currentRound.totalReward += _totalAmount * ticketPrice;
        USDT.transferFrom(_buyer, address(this), _totalAmount * ticketPrice);
        emit TicketBought(_buyer, currentRoundIndex, _ticketNumbers, _amounts);
    }

    function claimReward() external whenNotPaused nonReentrant {
        if (pendingRewards[msg.sender] > 0) {
            pendingRewards[msg.sender] = 0;
            USDT.safeTransfer(msg.sender, pendingRewards[msg.sender]);
        }
    }

    // View functions
    // Internal functions
    function _finishRound(uint256 _luckyNumber) internal {
        RoundData storage _currentRound = rounds[currentRoundIndex];
        _currentRound.luckyNumber = _luckyNumber;
        _currentRound.status = Status.Closed;
        _currentRound.endTime = block.timestamp;

        // check user has bought lucky number | check megaPrize
        if (ticketsPerRound[currentRoundIndex][_luckyNumber] > 0) { // have winner
            address[] memory _winners = ticketHolders[currentRoundIndex][_luckyNumber].values();
            uint256 _megaReward = _currentRound.totalReward * megaRewardPercentage / ONE_HUNDRED_PERCENT;
            uint256 _totalTicketWithLuckyNumber = ticketsPerRound[currentRoundIndex][_luckyNumber];
            for (uint256 i = 0; i < _winners.length; i++) {
                address _winner = _winners[i];
                uint256 _userTickets = userTickets[_winner][currentRoundIndex][_luckyNumber];
                pendingRewards[_winner] += _megaReward * _userTickets / _totalTicketWithLuckyNumber;
            }

        } else {

        }

        currentRoundIndex++;
    }

    // Restricted functions
    function pause() external onlyOwner{}
    function unpause() external onlyOwner{}
    function changeTicketPrice(uint256 _ticketPrice) external onlyOwner{}
    function changeMegaRewardPercentage(uint256 _megaRePer) external onlyOwner{}

    function finishCurrentRound() external onlyOperator{}

    // Event
    event TicketBought(address indexed user, uint256 roundIndex, uint256[] ticketNumbers, uint256[] amounts);

}