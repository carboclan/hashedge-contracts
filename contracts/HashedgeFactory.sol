pragma solidity ^0.4.24;

import "./UniswapExchange.sol";

contract FactoryInterface {
  address[] public tokenList;
  mapping(address => address) tokenToExchange;
  mapping(address => address) exchangeToToken;
  function launchExchange(address _token) public returns (address exchange);
  function getExchangeCount() public view returns (uint exchangeCount);
  function tokenToExchangeLookup(address _token) public view returns (address exchange);
  function exchangeToTokenLookup(address _exchange) public view returns (address token);
  event ExchangeLaunch(address indexed exchange, address indexed token);
}

contract HashedgeFactory is FactoryInterface {
  event ExchangeCreated(address indexed exchange, address indexed token);

  // index of tokens with registered exchanges
  address[] public tokenList;
  mapping(string => address) symbolToToken;
  mapping(address => address) tokenToExchange;
  mapping(address => address) exchangeToToken;

  function createExchange(
    uint256 _target, string _name, string _symbol, uint8 _decimals, uint256 _totalSupply,
    string _hashType, string _currencyType, string _hashRateUnit, uint256 _tokenSize,
    uint256 _startTs, uint256 _endTs, uint256 _strikePrice
  ) public returns (address exchange) {
    require(symbolToToken[_symbol] == address(0));
    require(_target > 0);
    require(bytes(_name).length > 0);
    require(bytes(_symbol).length > 0);
    require(_decimals > 0);
    require(_totalSupply > 0);
    require(bytes(_hashType).length > 0);
    require(bytes(_currencyType).length > 0);
    require(bytes(_hashRateUnit).length > 0);
    require(_tokenSize > 0);
    require(_startTs > now);
    require(_endTs > _startTs);
    require(_strikePrice > 0);

    HashRateOptionsToken token = new HashRateOptionsToken(
      _name,
      _symbol,
      _decimals
    );

    token.setInfo(
      _hashType,
      _currencyType,
      _hashRateUnit,
      _tokenSize,
      _startTs,
      _endTs,
      _strikePrice
    );

    UniswapExchange newExchange = new UniswapExchange(token, _target, _totalSupply);
    token.transferOwnership(newExchange);
    tokenList.push(token);
    symbolToToken[_symbol] = token;
    tokenToExchange[token] = newExchange;
    exchangeToToken[newExchange] = token;
    emit ExchangeCreated(newExchange, token);
    return newExchange;
  }

  function getExchangeCount() public view returns (uint exchangeCount) {
    return tokenList.length;
  }

  function tokenToExchangeLookup(address _token) public view returns (address exchange) {
    return tokenToExchange[_token];
  }

  function exchangeToTokenLookup(address _exchange) public view returns (address token) {
    return exchangeToToken[_exchange];
  }
}
