// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @title TokenSale -- the contract is template for token sale .
 *
 * @dev This contract includes the following functionality:
 *  - Purchase for ETH & for ERC20 token.
 *  - Withdraw unused token amount.
 *  - Claim purchased amount.
 */
contract TokenSale is OwnableUpgradeable, AccessControlUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public startTime;
    uint256 public endTime;

    uint256 public totalSaleAmount;
    uint256 public alreadyEarned;

    uint256 public transactionLimit;
    uint256 public tokenToTokenRatio;
    uint256 public tokenToEthRatio;

    bool public activeLimitMode;
    address public saleToken;
    address public currencyToken;

    /// @dev bayer -> token amount
    mapping(address => uint256) public purchasedTokenAmount;
    /// @dev user -> limit amount
    mapping(address => uint256) public limitedForUser;

    ///errors
    error InvalidEthAmount();
    error InvalidAmount();
    error OutOfTotalSale();
    error EarlyClaimCall();
    error EarlyPurchaseCall();
    error DelayPurchaseCall();
    error OutOfUserLimit();
    error OutOfTransactionLimit();
    error EarlyWithdrawCall();

    /// events
    event EndTimeSettled(uint256 indexed time);
    event LimitModeChanged(bool indexed status);
    event AmountSettled(uint256 indexed amount);
    event StartTimeSettled(uint256 indexed time);
    event SaleTokenSettled(address indexed _addr);
    event AmountTransferred(uint256 indexed amount);
    event CurrencyTokenSettled(address indexed _addr);
    event TransactionLimitSettled(uint256 indexed limitAmount);
    event Withdrawn(address indexed _addr, uint256 indexed amount);
    event TokensEarned(address indexed _addr, uint256 indexed amount);
    event TokensClaimed(address indexed _addr, uint256 indexed amount);
    event UserLimitSettled(address indexed _addr, uint256 indexed amount);
    event RatiosSettled(uint256 indexed ethRatio, uint256 indexed tokenRatio);

    function initialize(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _tokenToTokenRatio,
        uint256 _tokenToEthRatio,
        address _saleToken,
        address _currencyToken
    ) external initializer {
        __Ownable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        setStartTime(_startTime);
        setEndTime(_endTime);
        setRatio(_tokenToEthRatio, _tokenToTokenRatio);
        setSaleToken(_saleToken);
        setCurrencyToken(_currencyToken);
    }

        function setSaleAmount(uint256 newAmount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        totalSaleAmount = newAmount;

        IERC20Upgradeable(saleToken).transferFrom(msg.sender, address(this), newAmount);

        emit AmountTransferred(newAmount);
        emit AmountSettled(newAmount);
    }


    function purchaseTokenEth() public payable {
        if (msg.value < 0) revert InvalidEthAmount();

        uint256 _tokensToBeEarned = msg.value * tokenToEthRatio;
        purchase(_tokensToBeEarned);
    }

    function purchaseToken(uint256 tokenAmount) public {
        if (tokenAmount < 0) revert InvalidAmount();

        uint256 _tokensToBeEarned = tokenAmount * tokenToTokenRatio;
        purchase(_tokensToBeEarned);

        IERC20Upgradeable(currencyToken).transferFrom(msg.sender, address(this), tokenAmount);
    }

    function purchase(uint256 tokensToBeEarned) internal {
        if (block.timestamp < startTime) revert EarlyPurchaseCall();
        if (block.timestamp > endTime) revert DelayPurchaseCall();

        if (activeLimitMode) {
            if (limitedForUser[msg.sender] < tokensToBeEarned) revert OutOfUserLimit();
            if (transactionLimit < tokensToBeEarned) revert OutOfTransactionLimit();
        }

        if (alreadyEarned + tokensToBeEarned > totalSaleAmount) revert OutOfTotalSale();

        alreadyEarned += tokensToBeEarned;
        purchasedTokenAmount[msg.sender] += tokensToBeEarned;

        emit TokensEarned(msg.sender, tokensToBeEarned);
    }

    function claim() public {
        if (block.timestamp < endTime) revert EarlyClaimCall();

        uint256 amount = purchasedTokenAmount[msg.sender];
        purchasedTokenAmount[msg.sender] = 0;

        IERC20Upgradeable(saleToken).transfer(msg.sender, amount);

        emit TokensClaimed(msg.sender, amount);
    }

    function withdrawUnusedTokenBalance() public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (block.timestamp < endTime) revert EarlyWithdrawCall();

        uint256 currentBalance = IERC20Upgradeable(saleToken).balanceOf(address(this));
        IERC20Upgradeable(saleToken).transfer(msg.sender, currentBalance);

        emit Withdrawn(msg.sender, currentBalance);
    }

    function isLimitModeActive() public view returns (bool) {
        return activeLimitMode;
    }

    /// setters
    function setLimitMode(bool _status) public onlyRole(DEFAULT_ADMIN_ROLE) {
        activeLimitMode = _status;

        emit LimitModeChanged(_status);
    }

    function setUserLimit(address user, uint256 _limitAmount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        limitedForUser[user] = _limitAmount;

        emit UserLimitSettled(user, _limitAmount);
    }

    function setTransactionLimit(uint256 _transactionLimit) public onlyRole(DEFAULT_ADMIN_ROLE) {
        transactionLimit = _transactionLimit;

        emit TransactionLimitSettled(_transactionLimit);
    }

    function setRatio(uint256 newEthRatio, uint256 newTokenRatio) public onlyRole(DEFAULT_ADMIN_ROLE) {
       tokenToEthRatio  = newEthRatio;
       tokenToTokenRatio  = newTokenRatio;

        emit RatiosSettled(newEthRatio, newTokenRatio);
    }

    function setCurrencyToken(address addr) public onlyRole(DEFAULT_ADMIN_ROLE) {
        currencyToken = addr;

        emit CurrencyTokenSettled(addr);
    }

    function setSaleToken(address addr) public onlyRole(DEFAULT_ADMIN_ROLE) {
        saleToken = addr;

        emit SaleTokenSettled(addr);
    }

    function setStartTime(uint256 newTime) public onlyRole(DEFAULT_ADMIN_ROLE) {
        startTime = newTime;

        emit StartTimeSettled(newTime);
    }

    function setEndTime(uint256 newTime) public onlyRole(DEFAULT_ADMIN_ROLE) {
        endTime = newTime;

        emit EndTimeSettled(newTime);
    }

    // _______________ Gap reserved space _______________

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new variables without shifting
     * down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps.
     */
    uint256[48] private gap;
}
