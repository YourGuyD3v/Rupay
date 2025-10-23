// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Rupay} from "./Rupay.sol";
import {ChainlinkOracleLib} from "./libraries/ChainlinkOracleLib.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/*
 * @title RupIssuer
 * @author Shurjeel Khan
 * @notice This contract allows users to deposit collateral and mint Rupay (RUP) stablecoins.
 * The contract uses Chainlink oracles to fetch real-time price data for collateral valuation.
 * It includes mechanisms for pausing operations, managing price feeds, and ensuring the health of the system.
 */
contract RupIssuer is ReentrancyGuard, Pausable, Ownable {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
    error RupIssuer__NotZeroAddress();
    error RupIssuer__AmountMustBeMoreThanZero();
    error RupIssuer__ParamsLengthMismatch();
    error RupIssuer__TransferFailed();
    error RupIssuer__TokenNotAllowed(address token);
    error RupIssuer__UserNotHealthy(uint256 healthFactor);
    error RupIssuer__MintFailed();
    error RupIssuer__UserHealthy(uint256 healthFactor);
    error RupIssuer__TokenIsNotAllowed(address token);
    error RupIssuer__TokenAlreadySet(address token);
    error RupIssuer__UserHealthDidNotImprove(uint256 healthFactorBefore, uint256 healthFactorAfter);

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
    event PriceFeedUpdated(
        address indexed token, address indexed priceFeed, address indexed sequencerFeed, uint256 stalePriceThreshold
    );
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event RupMinted(address indexed user, uint256 amount);
    event Paused();
    event Unpaused();
    event CollateralRedeemed(address indexed user, address indexed to, address indexed token, uint256 amount);
    event RupBurned(address indexed user, uint256 amount);
    event AccountsLiquidated(
        address indexed user,
        address indexed liquidator,
        address indexed token,
        uint256 debtCovered,
        uint256 collateralRedeemed
    );

    /*//////////////////////////////////////////////////////////////
                            State Variables
    //////////////////////////////////////////////////////////////*/

    struct PriceFeed {
        address priceFeed; // Chainlink Price Feed address
        address sequencerFeed; // Chainlink Sequencer Uptime Feed address (address(0) for L1)
        uint256 stalePriceThreshold; // Maximum age of price data in seconds before considered stale
    }

    mapping(address token => PriceFeed) private s_PriceFeeds; // token address to PriceFeed struct
    mapping(address user => mapping(address token => uint256 amount)) private s_CollateralDeposits; // user address to token address to amount deposited
    mapping(address user => uint256 amount) private s_RupMinted; // user address to amount of RUP minted

    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200%
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18; // 1.0
    uint256 private constant LIQUIDATION_BONUS = 5; // 5%
    address[] private s_CollateralTokens; // list of allowed collateral tokens
    Rupay private immutable i_rupay;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) {
            revert RupIssuer__AmountMustBeMoreThanZero();
        }
        _;
    }

    modifier isValidToken(address token) {
        if (s_PriceFeeds[token].priceFeed == address(0)) {
            revert RupIssuer__TokenIsNotAllowed(token);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address[] memory _tokens,
        address[] memory _pricefeed,
        address[] memory _sequencerFeed,
        uint256[] memory _stalePriceThreshold,
        address rupayAddress
    ) Ownable(msg.sender) {
        if (
            _tokens.length != _pricefeed.length || _tokens.length != _sequencerFeed.length
                || _tokens.length != _stalePriceThreshold.length
        ) {
            revert RupIssuer__ParamsLengthMismatch();
        }

        if (rupayAddress == address(0)) {
            revert RupIssuer__NotZeroAddress();
        }

        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_tokens[i] == address(0) || _pricefeed[i] == address(0)) {
                revert RupIssuer__NotZeroAddress();
            }
            if (s_PriceFeeds[_tokens[i]].priceFeed != address(0)) {
                revert RupIssuer__TokenAlreadySet(_tokens[i]);
            }
            s_PriceFeeds[_tokens[i]] = PriceFeed({
                priceFeed: _pricefeed[i],
                sequencerFeed: _sequencerFeed[i],
                stalePriceThreshold: _stalePriceThreshold[i]
            });
            s_CollateralTokens.push(_tokens[i]);
        }
        i_rupay = Rupay(address(rupayAddress));
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice deposit collateral and mint RUP tokens
     * @param token address of the colateral token to be deposited
     * @param amountCollateral amount of the colateral token to be deposited
     * @param amountToMint amount of RUP to be minted
     */
    function depositAndMint(address token, uint256 amountCollateral, uint256 amountToMint)
        external
        whenNotPaused
        nonReentrant
    {
        _deposit(token, amountCollateral);
        _mintRup(amountToMint);
    }

    /**
     * @notice deposit collateral
     * @param token address of the colateral token to be deposited
     * @param amountCollateral amount of the colateral token to be deposited
     */
    function deposit(address token, uint256 amountCollateral)
        external
        whenNotPaused
        nonReentrant
    {
        _deposit(token, amountCollateral);
    }

    /**
     * @notice mint RUP tokens
     * @param amountToMint amount of RUP to be minted
     */
    function mint(uint256 amountToMint) external whenNotPaused nonReentrant {
        _mintRup(amountToMint);
    }

    /**
     * @notice burn RUP and redeem collateral
     * @param token address of the colateral token to be redeemed
     * @param amountToBurn amount of RUP to be burned
     * @param amountCollateral amount of the colateral token to be redeemed
     */
    function redeem(address token, uint256 amountToBurn, uint256 amountCollateral)
        external
        whenNotPaused
        nonReentrant
    {
        _burnRup(amountToBurn, msg.sender, msg.sender);
        _redeemCollateral(token, amountCollateral, msg.sender, msg.sender);
        _healthFactorCheck(msg.sender);
    }

    /**
     * @notice burn RUP tokens
     * @param amountToBurn amount of RUP to be burned
     */
    function burn(uint256 amountToBurn) external whenNotPaused nonReentrant {
        _burnRup(amountToBurn, msg.sender, msg.sender);
        _healthFactorCheck(msg.sender);
    }

    /**
     * @notice redeem collateral
     * @param token address of the colateral token to be redeemed
     * @param amountCollateral amount of the colateral token to be redeemed
     */
    function redeemCollateral(address token, uint256 amountCollateral)
        external
        whenNotPaused
        nonReentrant
    {
        _redeemCollateral(token, amountCollateral, msg.sender, msg.sender);
        _healthFactorCheck(msg.sender);
    }

    /**
     * @notice anyone can liquidate an undercollateralized account and receive a bonus
     * @param user address of the user to be liquidated
     * @param debtToCover amount of RUP debt to be covered
     * @param token address of the colateral token to be redeemed
     */
    function liquidate(address user, uint256 debtToCover, address token)
        external
        isValidToken(token)
        nonZeroAmount(debtToCover)
        nonReentrant
        whenNotPaused
    {
        uint256 userHealthFactorBef = _calHealthFactor(user);
        if (userHealthFactorBef >= MIN_HEALTH_FACTOR) {
            revert RupIssuer__UserHealthy(userHealthFactorBef);
        }

        uint256 tokenAmountFromUsd = getTokenAmountFromUsd(token, debtToCover);
        uint256 bonus = (tokenAmountFromUsd * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromUsd + bonus;

        uint256 totalDepositedCollateral = s_CollateralDeposits[user][token];
        if (tokenAmountFromUsd < totalDepositedCollateral && totalCollateralToRedeem > totalDepositedCollateral) {
            totalCollateralToRedeem = totalDepositedCollateral;
            }

        _redeemCollateral(token, totalCollateralToRedeem, user, msg.sender);
        _burnRup(debtToCover, user, msg.sender);

        uint256 healthFactorAft = _calHealthFactor(user);

        if (healthFactorAft <= userHealthFactorBef) {
            revert RupIssuer__UserHealthDidNotImprove(userHealthFactorBef, healthFactorAft);
        }

        emit AccountsLiquidated(user, msg.sender, token, debtToCover, totalCollateralToRedeem);
    }

    /**
     * @param _token address of the colateral token
     * @param _feed feed struct containing price feed details
     */
    function managePriceFeed(address _token, PriceFeed memory _feed) external onlyOwner {
        if (_token == address(0) || _feed.priceFeed == address(0)) {
            revert RupIssuer__NotZeroAddress();
        }
        if (s_PriceFeeds[_token].priceFeed == address(0)) {
            s_CollateralTokens.push(_token);
        }
        s_PriceFeeds[_token] = _feed;
        emit PriceFeedUpdated(_token, _feed.priceFeed, _feed.sequencerFeed, _feed.stalePriceThreshold);
    }

    /**
     * @notice pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _token address of the colateral token to be deposited
     * @param _amount amount of the colateral token to be deposited
     */
    function _deposit(address _token, uint256 _amount) internal nonZeroAmount(_amount) isValidToken(_token) {
        s_CollateralDeposits[msg.sender][_token] += _amount;
        emit CollateralDeposited(msg.sender, _token, _amount);
        bool success = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert RupIssuer__TransferFailed();
        }
    }

    /**
     * @param amount amount of RUP to be minted
     */
    function _mintRup(uint256 amount) internal nonZeroAmount(amount) {
        s_RupMinted[msg.sender] += amount;
        _healthFactorCheck(msg.sender);
        emit RupMinted(msg.sender, amount);
        bool success = i_rupay.mint(msg.sender, amount);
        if (!success) {
            revert RupIssuer__MintFailed();
        }
    }

    /**
     * @notice burn RUP tokens
     * @param amount amount of RUP to be burned
     * @param burner address whose RUP balance will be reduced
     * @param from address from which RUP will be transferred
     */
    function _burnRup(uint256 amount, address burner, address from) internal nonZeroAmount(amount) {
        s_RupMinted[burner] -= amount;
        emit RupBurned(burner, amount);
        bool success = i_rupay.transferFrom(from, address(this), amount);
        if (!success) {
            revert RupIssuer__TransferFailed();
        }
        i_rupay.burn(amount);
    }

    /**
     * @notice redeem collateral
     * @param token address of the colateral token to be redeemed
     * @param amount amount of the colateral token to be redeemed
     * @param from address from which collateral will be deducted
     * @param to address to which collateral will be sent
     */
    function _redeemCollateral(address token, uint256 amount, address from, address to)
        internal
        nonZeroAmount(amount)
        isValidToken(token)
    {
        s_CollateralDeposits[from][token] -= amount;
        emit CollateralRedeemed(from, to, token, amount);
        bool success = IERC20(token).transfer(to, amount);
        if (!success) {
            revert RupIssuer__TransferFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                INTERNAL AND PRIVATE VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _handleDecimals(uint8 chainlinkPricefeedDecimals, uint8 tokenDecimals, int256 price, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        // Normalize price to 18 decimals
        uint256 normalizedPrice = SafeCast.toUint256(price) * (10 ** (18 - chainlinkPricefeedDecimals));

        // Normalize amount to 18 decimals (if needed)
        uint256 normalizedAmount = amount * (10 ** (18 - tokenDecimals));

        // Calculate: (price * amount) / 1e18
        return (normalizedPrice * normalizedAmount) / PRECISION;
    }

    function _userInfo(address user) internal view returns (uint256 totalRupMinted, uint256 totalCollateral) {
        uint256 rupMinted = s_RupMinted[user];
        uint256 collateral = _totalUserCollateral(user);
        return (rupMinted, collateral);
    }

    function _totalUserCollateral(address user) internal view returns (uint256 totalCollateralValue) {
        for (uint256 i = 0; i < s_CollateralTokens.length; i++) {
            address token = s_CollateralTokens[i];
            uint256 amount = s_CollateralDeposits[user][token];
            uint256 valueInUsd = getPriceInUsd(token, amount);
            totalCollateralValue += valueInUsd;
        }

        return totalCollateralValue;
    }

    function _calHealthFactor(address user) internal view returns (uint256) {
        (uint256 totalRupMinted, uint256 totalCollateral) = _userInfo(user);
        if (totalRupMinted == 0) return type(uint256).max;
        uint256 totalCollateralAdjusted = (totalCollateral * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        uint256 healthFactor = (totalCollateralAdjusted * PRECISION) / totalRupMinted;
        return healthFactor;
    }

    function _healthFactorCheck(address user) internal view {
        uint256 healthFactor = _calHealthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert RupIssuer__UserNotHealthy(healthFactor);
        }
    }

    /*//////////////////////////////////////////////////////////////
                PUBLIC AND EXTERNAL VIEW & PURE  FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getUserInfo(address user) external view returns (uint256 totalRupMinted, uint256 totalCollateral) {
        (uint256 rupMinted, uint256 collateral) = _userInfo(user);
        return (rupMinted, collateral);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_CollateralTokens;
    }

    function getCollateralTokensLength() external view returns (uint256) {
        return s_CollateralTokens.length;
    }

    function getTotalUserCollateral(address user) external view returns (uint256) {
        return _totalUserCollateral(user);
    }

    function getCollateralFromToken(address user, address token) external view returns (uint256) {
        return s_CollateralDeposits[user][token];
    }

    function getHealthStatus(address user) external view returns (uint256) {
        return _calHealthFactor(user);
    }

    function getIsValidToken(address token) external view returns (bool) {
        return s_PriceFeeds[token].priceFeed != address(0);
    }

    function getPriceInUsd(address token, uint256 amount) public view returns (uint256) {
        PriceFeed memory feed = s_PriceFeeds[token];
        if (feed.priceFeed == address(0)) {
            revert RupIssuer__TokenNotAllowed(token);
        }

        // Get price feed decimals, not token decimals
        uint8 priceFeedDecimals = AggregatorV3Interface(feed.priceFeed).decimals();

        int256 price = ChainlinkOracleLib.getPrice(feed.priceFeed, feed.sequencerFeed, feed.stalePriceThreshold);

        // Get token decimals for amount adjustment
        uint8 tokenDecimals = IERC20Metadata(token).decimals();

        uint256 adjustedAmount = _handleDecimals(priceFeedDecimals, tokenDecimals, price, amount);
        return adjustedAmount;
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmount) public view returns (uint256) {
        PriceFeed memory feed = s_PriceFeeds[token];
        if (feed.priceFeed == address(0)) {
            revert RupIssuer__TokenNotAllowed(token);
        }

        // Get price feed decimals, not token decimals
        uint8 priceFeedDecimals = AggregatorV3Interface(feed.priceFeed).decimals();

        int256 price = ChainlinkOracleLib.getPrice(feed.priceFeed, feed.sequencerFeed, feed.stalePriceThreshold);

        // Get token decimals for amount adjustment
        uint8 tokenDecimals = IERC20Metadata(token).decimals();

        // Normalize price to 18 decimals
        uint256 normalizedPrice = SafeCast.toUint256(price) * (10 ** (18 - priceFeedDecimals));

        // Calculate the token amount needed for the given USD amount
        uint256 tokenAmount = (usdAmount * PRECISION) / normalizedPrice;

        // Adjust for token decimals
        return tokenAmount / (10 ** (18 - tokenDecimals));
    }

    function getCollateralTokenInfo(address token) external view returns (PriceFeed memory) {
        return s_PriceFeeds[token];
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_PriceFeeds[token].priceFeed;
    }

    function getRupayAddress() external view returns (address) {
        return address(i_rupay);
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }
}
