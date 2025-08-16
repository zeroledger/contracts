const { VerifyPlugin } = require("@dgma/hardhat-sol-bundler/plugins/Verify");

const config = {
  Template: {},
};

module.exports = {
  hardhat: {
    config: config,
  },
  localhost: { lockFile: "./local.deployment-lock.json", config: config },
  arbitrumSepolia: {
    lockFile: "./deployment-lock.json",
    verify: true,
    plugins: [VerifyPlugin],
    config: config,
  },
  baseSepolia: {
    lockFile: "./deployment-lock.json",
    verify: true,
    plugins: [VerifyPlugin],
    config: config,
  },
  opSepolia: {
    lockFile: "./deployment-lock.json",
    verify: true,
    plugins: [VerifyPlugin],
    config: config,
  },
};
