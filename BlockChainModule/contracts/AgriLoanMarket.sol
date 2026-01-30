// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title AgriLoanMarket
 * @dev Collateralized lending market for agricultural yield tokens
 * Farmers can use yield tokens as collateral for loans
 */
contract AgriLoanMarket is AccessControl, ReentrancyGuard {
    
    bytes32 public constant LENDER_ROLE = keccak256("LENDER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    /**
     * @dev Loan struct
     */
    struct Loan {
        uint256 loanId;
        address farmer;
        address lender;
        address tokenContract;
        uint256 tokenId;
        uint256 tokenAmount;      // Amount of tokens used as collateral
        uint256 loanAmount;       // Loan amount in wei
        uint256 interestRate;     // Percentage (e.g., 5 = 5%)
        uint256 duration;         // Loan duration in seconds
        uint256 startTime;
        uint256 endTime;
        bool isRepaid;
        bool isLiquidated;
        bool isActive;
    }
    
    /**
     * @dev Interest rate model based on prediction confidence
     */
    struct InterestModel {
        uint256 minConfidence;    // Minimum confidence threshold
        uint256 rate;             // Interest rate for this tier
    }
    
    // Loan ID -> Loan details
    mapping(uint256 => Loan) public loans;
    uint256 public nextLoanId = 1;
    
    // Token ID -> locked amount
    mapping(uint256 => uint256) public lockedTokens;
    
    // Interest rate tiers
    InterestModel[] public interestRates;
    
    // LTV (Loan-to-Value) ratio
    uint256 public ltv = 70; // 70% default LTV
    
    // Platform fee (in basis points)
    uint256 public platformFee = 100; // 1%
    
    // Treasury address
    address public treasury;
    
    event LoanCreated(
        uint256 indexed loanId,
        address indexed farmer,
        uint256 tokenId,
        uint256 loanAmount,
        uint256 interestRate
    );
    
    event LoanRepaid(
        uint256 indexed loanId,
        uint256 repaymentAmount
    );
    
    event LoanLiquidated(
        uint256 indexed loanId,
        address indexed liquidator
    );
    
    event TokensLocked(
        uint256 indexed tokenId,
        uint256 amount
    );
    
    event TokensReleased(
        uint256 indexed tokenId,
        uint256 amount
    );
    
    constructor(address _treasury) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        treasury = _treasury;
        
        // Initialize interest rate tiers
        interestRates.push(InterestModel({minConfidence: 80, rate: 3}));   // 80%+ -> 3%
        interestRates.push(InterestModel({minConfidence: 60, rate: 5}));   // 60-79% -> 5%
        interestRates.push(InterestModel({minConfidence: 40, rate: 8}));   // 40-59% -> 8%
        interestRates.push(InterestModel({minConfidence: 0, rate: 12}));   // <40% -> 12%
    }
    
    /**
     * @dev Create a new collateralized loan
     * @param tokenContract Address of the ERC1155 token contract
     * @param tokenId Token to use as collateral
     * @param tokenAmount Amount of tokens
     * @param loanDurationDays Loan duration in days
     * @return loanId The ID of the created loan
     */
    function createLoan(
        address tokenContract,
        uint256 tokenId,
        uint256 tokenAmount,
        uint256 loanDurationDays,
        uint256 predictionConfidence
    ) external payable nonReentrant returns (uint256) {
        require(tokenContract != address(0), "Invalid token contract");
        require(tokenAmount > 0, "Amount must be greater than 0");
        require(loanDurationDays > 0, "Duration must be greater than 0");
        require(predictionConfidence <= 100, "Invalid confidence");
        
        // Calculate loan amount based on LTV and confidence
        uint256 maxLoanAmount = (tokenAmount * ltv) / 100;
        require(msg.value > 0 && msg.value <= maxLoanAmount, "Invalid loan amount");
        
        // Get interest rate based on confidence
        uint256 interestRate = getInterestRate(predictionConfidence);
        
        uint256 loanId = nextLoanId++;
        uint256 duration = loanDurationDays * 1 days;
        
        loans[loanId] = Loan({
            loanId: loanId,
            farmer: msg.sender,
            lender: address(0),  // Protocol-based lending
            tokenContract: tokenContract,
            tokenId: tokenId,
            tokenAmount: tokenAmount,
            loanAmount: msg.value,
            interestRate: interestRate,
            duration: duration,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            isRepaid: false,
            isLiquidated: false,
            isActive: true
        });
        
        // Transfer tokens from farmer to contract (lock them)
        IERC1155(tokenContract).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            tokenAmount,
            ""
        );
        
        lockedTokens[tokenId] += tokenAmount;
        
        emit LoanCreated(loanId, msg.sender, tokenId, msg.value, interestRate);
        
        return loanId;
    }
    
    /**
     * @dev Get interest rate based on prediction confidence
     */
    function getInterestRate(uint256 confidence) 
        public 
        view 
        returns (uint256) 
    {
        for (uint256 i = 0; i < interestRates.length; i++) {
            if (confidence >= interestRates[i].minConfidence) {
                return interestRates[i].rate;
            }
        }
        return 12; // Default fallback
    }
    
    /**
     * @dev Repay a loan
     */
    function repayLoan(uint256 loanId) 
        external 
        payable 
        nonReentrant 
    {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan not active");
        require(!loan.isRepaid, "Already repaid");
        require(!loan.isLiquidated, "Loan liquidated");
        require(msg.sender == loan.farmer, "Not loan owner");
        
        // Calculate repayment amount with interest
        uint256 interest = (loan.loanAmount * loan.interestRate) / 100;
        uint256 totalRepayment = loan.loanAmount + interest;
        
        require(msg.value >= totalRepayment, "Insufficient repayment");
        
        loan.isRepaid = true;
        loan.isActive = false;
        
        // Release locked tokens
        IERC1155(loan.tokenContract).safeTransferFrom(
            address(this),
            loan.farmer,
            loan.tokenId,
            loan.tokenAmount,
            ""
        );
        
        lockedTokens[loan.tokenId] -= loan.tokenAmount;
        
        // Transfer fee to treasury
        uint256 fee = (interest * platformFee) / 10000;
        (bool success, ) = payable(treasury).call{value: fee}("");
        require(success, "Treasury transfer failed");
        
        // Return excess payment
        uint256 excess = msg.value - totalRepayment;
        if (excess > 0) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: excess}("");
            require(refundSuccess, "Refund failed");
        }
        
        emit LoanRepaid(loanId, totalRepayment);
    }
    
    /**
     * @dev Liquidate a loan if it's defaulted
     */
    function liquidateLoan(uint256 loanId) 
        external 
        nonReentrant 
    {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan not active");
        require(!loan.isRepaid, "Already repaid");
        require(!loan.isLiquidated, "Already liquidated");
        require(block.timestamp > loan.endTime, "Loan not yet due");
        
        loan.isLiquidated = true;
        loan.isActive = false;
        
        // Tokens go to treasury for liquidation
        IERC1155(loan.tokenContract).safeTransferFrom(
            address(this),
            treasury,
            loan.tokenId,
            loan.tokenAmount,
            ""
        );
        
        lockedTokens[loan.tokenId] -= loan.tokenAmount;
        
        emit LoanLiquidated(loanId, msg.sender);
    }
    
    /**
     * @dev Get loan details
     */
    function getLoan(uint256 loanId)
        external
        view
        returns (Loan memory)
    {
        return loans[loanId];
    }
    
    /**
     * @dev Calculate repayment amount for a loan
     */
    function calculateRepayment(uint256 loanId)
        external
        view
        returns (uint256)
    {
        Loan memory loan = loans[loanId];
        uint256 interest = (loan.loanAmount * loan.interestRate) / 100;
        return loan.loanAmount + interest;
    }
    
    /**
     * @dev Update LTV ratio
     */
    function setLTV(uint256 _ltv)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_ltv > 0 && _ltv <= 100, "Invalid LTV");
        ltv = _ltv;
    }
    
    /**
     * @dev Update treasury address
     */
    function setTreasury(address _treasury)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_treasury != address(0), "Invalid address");
        treasury = _treasury;
    }
    
    /**
     * @dev ERC1155 receiver
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
    
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
