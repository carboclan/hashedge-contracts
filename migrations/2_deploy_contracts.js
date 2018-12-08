// const fs = require('fs');

const HashedgeFactory = artifacts.require('./HashedgeFactory.sol');

module.exports = async function(deployer) {
  deployer.then(async () => {
    await deployer.deploy(HashedgeFactory);
  });
};
