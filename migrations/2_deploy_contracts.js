const HashedgeFactory = artifacts.require('./HashedgeFactory.sol');

module.exports = async function(deployer) {
  deployer.then(async () => {
    await deployer.deploy(HashedgeFactory);

    const hashedgeFactory = require('../build/contracts/HashedgeFactory').abi;
    const hashRateOptionsToken = require('../build/contracts/HashRateOptionsToken').abi;
    const uniswapExchange = require('../build/contracts/UniswapExchange').abi;

    console.log(      __dirname + '/../build/abi.json');
    require('fs').writeFileSync(
      __dirname + '/../build/abi.json',
      new Buffer(JSON.stringify({ hashedgeFactory, hashRateOptionsToken, uniswapExchange }, 2, 2))
    );
  });
};
