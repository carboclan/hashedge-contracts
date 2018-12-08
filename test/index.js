const HashRateOptionsToken = artifacts.require('./HashRateOptionsToken.sol');
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
      const token = HashRateOptionsToken.at(tokenAddr);
      const xhgAddr = await hashedgeFactory.tokenToExchangeLookup(tokenAddr);
      const xhg = UniswapExchange.at(xhgAddr);

      assert.equal(false, await xhg.tradable());
      await xhg.investLiquidity({ from: accounts[1], value: web3.toWei(1, 'ether') });
      assert.equal(web3.toWei(1, 'ether'), await xhg.getShares(accounts[1]));
      await xhg.investLiquidity({ from: accounts[2], value: web3.toWei(4, 'ether') });
      assert.equal(web3.toWei(4, 'ether'), await xhg.getShares(accounts[2]));
      assert.equal(false, await xhg.tradable());
      await xhg.investLiquidity({ from: accounts[3], value: web3.toWei(6, 'ether') });
      assert.equal(web3.toWei(5, 'ether'), await xhg.getShares(accounts[3]));
      assert.equal(true, await xhg.tradable());

      console.log(
        web3.fromWei(await web3.eth.getBalance(accounts[1])).toString(),
        web3.fromWei(await xhg.profitPool()).toString()
      );
      await xhg.divestLiquidity(web3.toWei(1, 'ether'), 0, { from: accounts[1] });
      console.log(
        web3.fromWei(await web3.eth.getBalance(accounts[1])).toString(),
        web3.fromWei(await xhg.profitPool()).toString()
      );
      assert.equal(0, await xhg.getShares(accounts[1]));
      assert.equal(web3.toWei(10, 'ether'), await token.balanceOf(accounts[0]));

      await xhg.ethToTokenSwap(1, Date.now() / 1000 + 60, { value: web3.toWei(10, 'ether'), from: accounts[5] });
      const balance = await token.balanceOf(accounts[5]);
      console.log(web3.fromWei(balance).toString());
      await token.approve(xhgAddr, balance, { from: accounts[5] });
      await xhg.tokenToEthSwap(balance, 1, Date.now() / 1000 + 60, { from: accounts[5] });
      assert.equal(0, await token.balanceOf(accounts[5]));
      console.log(web3.fromWei(await web3.eth.getBalance(accounts[5])).toString());

      console.log(
        web3.fromWei(await web3.eth.getBalance(accounts[2])).toString(),
        web3.fromWei(await xhg.profitPool()).toString()
      );
      await xhg.divestLiquidity(web3.toWei(1, 'ether'), 0, { from: accounts[2] });
      console.log(
        web3.fromWei(await web3.eth.getBalance(accounts[2])).toString(),
        web3.fromWei(await xhg.profitPool()).toString()
      );
    });
  });
});
