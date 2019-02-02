function getPrivateKeyProvider() {
  const PrivateKeyProvider = require('truffle-privatekey-provider');
  return new PrivateKeyProvider(process.env.PRI, process.env.URL || 'https://ropsten.infura.io/8Q30zi3TAqlJ6JSCwcul');
}

module.exports = {
  networks: {
    testrpc: {
      host: "localhost",
      port: 8545,
      network_id: "*",
      gas: 4500000, // Gas limit used for deploys
      gasPrice: 10000000000 // 10 gwei
    },
    production: {
      provider: process.env.PRI && getPrivateKeyProvider(),
      network_id: '*',
      gas: 4500000, // Gas limit used for deploys
      gasPrice: 10000000000 // 10 gwei
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  },
  // https://truffle.readthedocs.io/en/beta/advanced/configuration/
  mocha: {
    bail: true
  }
};
