pragma solidity ^0.4.24;

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

}
