pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/math/SafeMath.sol";

import "./HashedgeFactory.sol";
import "./HashRateOptionsToken.sol";

contract UniswapExchange {
  using SafeMath for uint256;

  /// EVENTS
  event EthToTokenPurchase(address indexed buyer, uint256 indexed ethIn, uint256 indexed tokensOut);
  event TokenToEthPurchase(address indexed buyer, uint256 indexed tokensIn, uint256 indexed ethOut);
  event Investment(address indexed liquidityProvider, uint256 indexed sharesPurchased);
  event Divestment(address indexed liquidityProvider, uint256 indexed sharesBurned);

  /// CONSTANTS
  uint256 public constant TOKEN_SUPPLY_RATE = 10; // token in exchange = 1 / TOKEN_SUPPLY_RATE = 10%
  uint256 public constant FEE_RATE = 500;         // fee = 1/feeRate = 0.2%

  /// STORAGE
  address public issuer;
  uint256 public target;
  uint256 public tokenSupply;

  uint256 public ethPool;
  uint256 public tokenPool;
  uint256 public profitPool;
  uint256 public invariant;
  uint256 public totalShares;
  address public tokenAddress;
  address public factoryAddress;
  mapping(address => uint256) shares;
  HashRateOptionsToken token;
  FactoryInterface factory;

/// MODIFIERS
//  modifier exchangeInitialized() {
//    require(invariant > 0 && totalShares > 0);
//    _;
//  }

  modifier whenTradable() {
    token.totalSupply() > 0;
    _;
  }

  modifier whenNotTradable() {
    token.totalSupply() == 0;
    _;
  }

  constructor(address _tokenAddress, address _issuer, uint256 _target, uint256 _tokenSupply) public {
    tokenAddress = _tokenAddress;
    issuer = _issuer;
    factoryAddress = msg.sender;
    target = _target;
    tokenSupply = _tokenSupply;
    token = HashRateOptionsToken(tokenAddress);
    factory = FactoryInterface(factoryAddress);
  }

  function tradable() public view returns(bool) {
    return token.totalSupply() > 0;
  }

  /// FALLBACK FUNCTION
  function() public payable {
    require(msg.value != 0);
    ethToToken(msg.sender, msg.sender, msg.value, 1);
  }

/// EXTERNAL FUNCTIONS
//  function initializeExchange(uint256 _tokenAmount) external payable {
//    require(invariant == 0 && totalShares == 0);
//    // Prevents share cost from being too high or too low - potentially needs work
//    require(msg.value >= 10000 && _tokenAmount >= 10000 && msg.value <= 5*10**18);
//    ethPool = msg.value;
//    tokenPool = _tokenAmount;
//    invariant = ethPool.mul(tokenPool);
//    shares[msg.sender] = 1000;
//    totalShares = 1000;
//    require(token.transferFrom(msg.sender, address(this), _tokenAmount));
//  }

  // Buyer swaps ETH for Tokens
  function ethToTokenSwap(
    uint256 _minTokens,
    uint256 _timeout
  )
  external
  payable
  {
    require(msg.value > 0 && _minTokens > 0 && now < _timeout);
    ethToToken(msg.sender, msg.sender, msg.value,  _minTokens);
  }

  // Payer pays in ETH, recipient receives Tokens
  function ethToTokenPayment(
    uint256 _minTokens,
    uint256 _timeout,
    address _recipient
  )
  external
  payable
  {
    require(msg.value > 0 && _minTokens > 0 && now < _timeout);
    require(_recipient != address(0) && _recipient != address(this));
    ethToToken(msg.sender, _recipient, msg.value,  _minTokens);
  }

  // Buyer swaps Tokens for ETH
  function tokenToEthSwap(
    uint256 _tokenAmount,
    uint256 _minEth,
    uint256 _timeout
  )
  external
  {
    require(_tokenAmount > 0 && _minEth > 0 && now < _timeout);
    tokenToEth(msg.sender, msg.sender, _tokenAmount, _minEth);
  }

  // Payer pays in Tokens, recipient receives ETH
  function tokenToEthPayment(
    uint256 _tokenAmount,
    uint256 _minEth,
    uint256 _timeout,
    address _recipient
  )
  external
  {
    require(_tokenAmount > 0 && _minEth > 0 && now < _timeout);
    require(_recipient != address(0) && _recipient != address(this));
    tokenToEth(msg.sender, _recipient, _tokenAmount, _minEth);
  }

  // Buyer swaps Tokens in current exchange for Tokens of provided address
  function tokenToTokenSwap(
    address _tokenPurchased,                  // Must be a token with an attached Uniswap exchange
    uint256 _tokensSold,
    uint256 _minTokensReceived,
    uint256 _timeout
  )
  external
  {
    require(_tokensSold > 0 && _minTokensReceived > 0 && now < _timeout);
    tokenToTokenOut(_tokenPurchased, msg.sender, msg.sender, _tokensSold, _minTokensReceived);
  }

  // Payer pays in exchange Token, recipient receives Tokens of provided address
  function tokenToTokenPayment(
    address _tokenPurchased,
    address _recipient,
    uint256 _tokensSold,
    uint256 _minTokensReceived,
    uint256 _timeout
  )
  external
  {
    require(_tokensSold > 0 && _minTokensReceived > 0 && now < _timeout);
    require(_recipient != address(0) && _recipient != address(this));
    tokenToTokenOut(_tokenPurchased, msg.sender, _recipient, _tokensSold, _minTokensReceived);
  }

  // Function called by another Uniswap exchange in Token to Token swaps and payments
  function tokenToTokenIn(
    address _recipient,
    uint256 _minTokens
  )
  external
  payable
  returns (bool)
  {
    require(msg.value > 0);
    address exchangeToken = factory.exchangeToTokenLookup(msg.sender);
    require(exchangeToken != address(0));   // Only a Uniswap exchange can call this function
    ethToToken(msg.sender, _recipient, msg.value, _minTokens);
    return true;
  }

  // Invest liquidity and receive market shares
  function investLiquidity()
  external
  payable
  whenNotTradable
  {
    require(msg.value > 0);
    uint256 sharesPurchased = msg.value;
    if (totalShares.add(sharesPurchased) > target) {
      sharesPurchased = target.sub(totalShares);
    }

    shares[msg.sender] = shares[msg.sender].add(sharesPurchased);
    totalShares = totalShares.add(sharesPurchased);
    ethPool = ethPool.add(msg.value);
    emit Investment(msg.sender, sharesPurchased);
    if (totalShares == target) {
      if (msg.value > sharesPurchased) {
        msg.sender.transfer(msg.value - sharesPurchased);
      }

      token.issue(tokenSupply);
      tokenPool = token.totalSupply() / TOKEN_SUPPLY_RATE;
      invariant = ethPool.mul(tokenPool);
    }
  }

  // Divest market shares and receive liquidity
  function divestLiquidity(
    uint256 _sharesBurned,
    uint256 _minTokens
  )
  external
  {
    require(_sharesBurned > 0);
    uint256 ethTotalDivested = ethPool.mul(_sharesBurned).div(totalShares);
    uint256 profitDivested = profitPool.mul(_sharesBurned).div(totalShares);

    shares[msg.sender] = shares[msg.sender].sub(_sharesBurned);
    uint256 ethDivested = _sharesBurned.add(profitDivested);
    ethPool = ethPool.sub(ethTotalDivested);
    profitPool = profitPool.sub(profitDivested);
    msg.sender.transfer(ethDivested);

    if (tradable()) {
      uint256 tokensDivested = tokenPool.mul(_sharesBurned).div(totalShares);
      totalShares = totalShares.sub(_sharesBurned);

      require(tokensDivested >= _minTokens);
      tokenPool = tokenPool.sub(tokensDivested);
      if (totalShares == 0) {
        invariant = 0;
      } else {
        invariant = ethPool.mul(tokenPool);
      }
      emit Divestment(msg.sender, _sharesBurned);

      if (ethTotalDivested > ethDivested) {
        issuer.transfer(ethTotalDivested - ethDivested);
      }

      uint256 tokenTotal = token.totalSupply().sub(token.totalSupply().div(TOKEN_SUPPLY_RATE));
      uint256 releasedToIssuer = tokenTotal.sub(tokenTotal.mul(totalShares).div(target));
      require(token.transfer(issuer, tokensDivested + releasedToIssuer));
    } else {
      totalShares = totalShares.sub(_sharesBurned);
    }
  }

  // View share balance of an address
  function getShares(
    address _provider
  )
  external
  view
  returns(uint256 _shares)
  {
    return shares[_provider];
  }

  /// INTERNAL FUNCTIONS
  function ethToToken(
    address buyer,
    address recipient,
    uint256 ethIn,
    uint256 minTokensOut
  )
  internal
  whenTradable
  {
    uint256 fee = ethIn.div(FEE_RATE);
    profitPool = profitPool.add(fee);
    uint256 newEthPool = ethPool.add(ethIn);
    uint256 tempEthPool = newEthPool.sub(fee);
    uint256 newTokenPool = invariant.div(tempEthPool);
    uint256 tokensOut = tokenPool.sub(newTokenPool);
    require(tokensOut >= minTokensOut && tokensOut <= tokenPool);
    ethPool = newEthPool;
    tokenPool = newTokenPool;
    invariant = newEthPool.mul(newTokenPool);
    emit EthToTokenPurchase(buyer, ethIn, tokensOut);
    require(token.transfer(recipient, tokensOut));
  }

  function tokenToEth(
    address buyer,
    address recipient,
    uint256 tokensIn,
    uint256 minEthOut
  )
  internal
  whenTradable
  {
    uint256 newTokenPool = tokenPool.add(tokensIn);
    uint256 newEthPool = invariant.div(newTokenPool);
    uint256 tempEthOut = ethPool.sub(newEthPool);
    uint256 fee = tempEthOut.div(FEE_RATE);
    uint256 ethOut = tempEthOut.sub(fee);
    profitPool = profitPool.add(fee);
    require(ethOut >= minEthOut && ethOut <= ethPool);
    tokenPool = newTokenPool;
    ethPool = newEthPool;
    invariant = newEthPool.mul(newTokenPool);
    emit TokenToEthPurchase(buyer, tokensIn, ethOut);
    require(token.transferFrom(buyer, address(this), tokensIn));
    recipient.transfer(ethOut);
  }

  function tokenToTokenOut(
    address tokenPurchased,
    address buyer,
    address recipient,
    uint256 tokensIn,
    uint256 minTokensOut
  )
  internal
  whenTradable
  {
    require(tokenPurchased != address(0) && tokenPurchased != address(this));
    address exchangeAddress = factory.tokenToExchangeLookup(tokenPurchased);
    require(exchangeAddress != address(0) && exchangeAddress != address(this));
    uint256 newTokenPool = tokenPool.add(tokensIn);
    uint256 newEthPool = invariant.div(newTokenPool);
    uint256 tempEthOut = ethPool.sub(newEthPool);
    uint256 fee = tempEthOut.div(FEE_RATE);
    uint256 ethOut = tempEthOut.sub(fee);
    profitPool = profitPool.add(fee);
    require(ethOut <= ethPool);
    UniswapExchange exchange = UniswapExchange(exchangeAddress);
    emit TokenToEthPurchase(buyer, tokensIn, ethOut);
    tokenPool = newTokenPool;
    ethPool = newEthPool;
    invariant = newEthPool.mul(newTokenPool);
    require(token.transferFrom(buyer, address(this), tokensIn));
    require(exchange.tokenToTokenIn.value(ethOut)(recipient, minTokensOut));
  }
}
