// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title IDOPool
 * @dev A contract for Initial DEX Offering (IDO) that accepts payments in ERC-20 tokens
 * and provides refund mechanisms
 */
contract IDOPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Token being sold in the IDO
    IERC20 public idoToken;
    // Token used for payment
    IERC20 public paymentToken;
    
    // IDO configuration
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public tokenPrice; // How many payment tokens for 1 IDO token (in smallest units)
    uint256 public minContribution;
    uint256 public maxContribution;

    // IDO timing
    uint256 public startTime;
    uint256 public endTime;
    uint256 public claimTime;
    
    // Refund settings
    bool public refundEnabled = false;
    bool public refundAllowed = true;
    
    // IDO state
    uint256 public totalRaised;
    uint256 public totalTokensClaimed;
    bool public finalized = false;
    
    // User contributions
    mapping(address => uint256) public contributions;
    mapping(address => bool) public hasClaimedTokens;
    mapping(address => bool) public hasClaimedRefund;
    
    // Events
    event Contributed(address indexed user, uint256 amount);
    event TokensClaimed(address indexed user, uint256 amount);
    event RefundClaimed(address indexed user, uint256 amount);
    event IDOStarted(uint256 startTime, uint256 endTime);
    event IDOEnded();
    event RefundEnabled();
    event RefundDisabled();

    /**
     * @dev Initialize the IDO Pool with token addresses and parameters
     * @param _idoToken Address of the token being sold
     * @param _paymentToken Address of the token used for payment
     * @param _tokenPrice How many payment tokens for 1 IDO token (in smallest units)
     * @param _softCap Minimum amount to raise
     * @param _hardCap Maximum amount to raise
     * @param _minContribution Minimum contribution allowed per user
     * @param _maxContribution Maximum contribution allowed per user
     */
    constructor(
        address _idoToken,
        address _paymentToken,
        uint256 _tokenPrice,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _minContribution,
        uint256 _maxContribution
    ) {
        require(_idoToken != address(0), "IDO token address cannot be zero");
        require(_paymentToken != address(0), "Payment token address cannot be zero");
        require(_tokenPrice > 0, "Token price must be greater than zero");
        require(_softCap > 0, "Soft cap must be greater than zero");
        require(_hardCap >= _softCap, "Hard cap must be greater than or equal to soft cap");
        require(_minContribution > 0, "Min contribution must be greater than zero");
        require(_maxContribution >= _minContribution, "Max contribution must be greater than or equal to min contribution");
        
        idoToken = IERC20(_idoToken);
        paymentToken = IERC20(_paymentToken);
        tokenPrice = _tokenPrice;
        softCap = _softCap;
        hardCap = _hardCap;
        minContribution = _minContribution;
        maxContribution = _maxContribution;
    }
    
    /**
     * @dev Start the IDO pool
     * @param _startTime The start time of the IDO
     * @param _endTime The end time of the IDO
     * @param _claimTime The time when tokens can be claimed
     */
    function startIDO(uint256 _startTime, uint256 _endTime, uint256 _claimTime) external onlyOwner {
        require(_startTime >= block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_claimTime >= _endTime, "Claim time must be after end time");
        require(startTime == 0, "IDO already started");
        
        startTime = _startTime;
        endTime = _endTime;
        claimTime = _claimTime;
        
        emit IDOStarted(_startTime, _endTime);
    }
    
    /**
     * @dev Contribute to the IDO pool
     * @param _amount The amount of payment tokens to contribute
     */
    function contribute(uint256 _amount) external nonReentrant {
        require(block.timestamp >= startTime, "IDO not started yet");
        require(block.timestamp <= endTime, "IDO ended");
        require(!refundEnabled, "Refunds are enabled, cannot contribute");
        require(_amount >= minContribution, "Contribution below minimum");
        require(contributions[msg.sender] + _amount <= maxContribution, "Contribution above maximum");
        require(totalRaised + _amount <= hardCap, "Hard cap reached");
        
        contributions[msg.sender] += _amount;
        totalRaised += _amount;
        
        // Transfer payment tokens from user to contract
        paymentToken.safeTransferFrom(msg.sender, address(this), _amount);
        
        emit Contributed(msg.sender, _amount);
    }
    
    /**
     * @dev Claim IDO tokens after the IDO ends
     */
    function claimTokens() external nonReentrant {
        require(block.timestamp >= claimTime, "Claiming not available yet");
        require(!refundEnabled, "Refunds are enabled, cannot claim tokens");
        require(totalRaised >= softCap, "Soft cap not reached");
        require(contributions[msg.sender] > 0, "No contribution found");
        require(!hasClaimedTokens[msg.sender], "Tokens already claimed");
        
        uint256 tokenAmount = calculateTokenAmount(contributions[msg.sender]);
        hasClaimedTokens[msg.sender] = true;
        totalTokensClaimed += tokenAmount;
        
        // Transfer IDO tokens to user
        idoToken.safeTransfer(msg.sender, tokenAmount);
        
        emit TokensClaimed(msg.sender, tokenAmount);
    }
    
    /**
     * @dev Calculate the amount of IDO tokens for a given contribution
     * @param _contributionAmount The amount of payment tokens contributed
     * @return The amount of IDO tokens to receive
     */
    function calculateTokenAmount(uint256 _contributionAmount) public view returns (uint256) {
        return (_contributionAmount * 10**18) / tokenPrice;
    }
    
    /**
     * @dev Claim refund if eligible
     */
    function claimRefund() external nonReentrant {
        require(refundAllowed, "Refunds not allowed");
        require(
            refundEnabled || 
            (block.timestamp > endTime && totalRaised < softCap), 
            "Refunds not available"
        );
        require(contributions[msg.sender] > 0, "No contribution found");
        require(!hasClaimedRefund[msg.sender], "Refund already claimed");
        require(!hasClaimedTokens[msg.sender], "Cannot refund after claiming tokens");
        
        uint256 refundAmount = contributions[msg.sender];
        hasClaimedRefund[msg.sender] = true;
        
        // Transfer payment tokens back to user
        paymentToken.safeTransfer(msg.sender, refundAmount);
        
        emit RefundClaimed(msg.sender, refundAmount);
    }
    
    /**
     * @dev Enable refunds (only owner)
     */
    function enableRefunds() external onlyOwner {
        refundEnabled = true;
        refundAllowed = true;
        emit RefundEnabled();
    }
    
    /**
     * @dev Disable refunds (only owner)
     */
    function disableRefunds() external onlyOwner {
        refundAllowed = false;
        emit RefundDisabled();
    }
    
    /**
     * @dev End the IDO early (only owner)
     */
    function endIDO() external onlyOwner {
        require(block.timestamp >= startTime, "IDO not started yet");
        require(block.timestamp < endTime, "IDO already ended");
        
        endTime = block.timestamp;
        emit IDOEnded();
    }
    
    /**
     * @dev Withdraw unsold tokens (only owner)
     */
    function withdrawUnsoldTokens() external onlyOwner {
        require(block.timestamp > endTime, "IDO not ended yet");
        require(totalRaised >= softCap, "Soft cap not reached");
        
        uint256 totalTokensForSale = (hardCap * 10**18) / tokenPrice;
        uint256 unsoldTokens = totalTokensForSale - totalTokensClaimed;
        
        if (unsoldTokens > 0) {
            idoToken.safeTransfer(owner(), unsoldTokens);
        }
    }
    
    /**
     * @dev Withdraw raised funds (only owner)
     */
    function withdrawRaisedFunds() external onlyOwner {
        require(block.timestamp > endTime, "IDO not ended yet");
        require(totalRaised >= softCap, "Soft cap not reached");
        require(!refundEnabled, "Refunds are enabled");
        
        paymentToken.safeTransfer(owner(), totalRaised);
    }
    
    /**
     * @dev Update token price (only owner)
     * @param _newTokenPrice New token price
     */
    function updateTokenPrice(uint256 _newTokenPrice) external onlyOwner {
        require(startTime == 0, "Cannot update price after IDO started");
        require(_newTokenPrice > 0, "Token price must be greater than zero");
        
        tokenPrice = _newTokenPrice;
    }
}