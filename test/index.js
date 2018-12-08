const HashedgeFactory = artifacts.require('./HashedgeFactory.sol');
const UniswapExchange = artifacts.require('./UniswapExchange.sol');

contract('TestAll', async accounts => {
  let hashedgeFactory;

  async function deploy() {
    hashedgeFactory = await HashedgeFactory.new();
  }

  describe('process', function() {
    before(deploy);

    it('should have correct state.', async function() {
      assert.equal(0, await hashedgeFactory.getExchangeCount());
    });

    it('should be corret.', async function () {
      await hashedgeFactory.createExchange(
        web3.toWei(10, 'ether'), 'BTC OPT TEST', 'BTC_DEC', 100,
        'PoW', 'BTC', 'TH/s', 1,
        Date.now() / 1000 + 3600, Date.now() / 1000 + 3600 * 24, web3.toWei(1, 'ether')
      );

      assert.equal(1, await hashedgeFactory.getExchangeCount());
      const tokenAddr = await hashedgeFactory.tokenList(0);
      const xhgAddr = await hashedgeFactory.tokenToExchangeLookup(tokenAddr);
      const xhg = UniswapExchange.at(xhgAddr);

      assert.equal(false, await xhg.tradable());
      await xhg.investLiquidity({ from: accounts[1], value: web3.toWei(1, 'ether') });
      assert.equal(web3.toWei(1, 'ether'), await xhg.getShares(accounts[1]));
      await xhg.investLiquidity({ from: accounts[2], value: web3.toWei(10, 'ether') });
      assert.equal(web3.toWei(9, 'ether'), await xhg.getShares(accounts[2]));
      assert.equal(true, await xhg.tradable());
    });
  });
});
