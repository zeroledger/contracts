# Sol Starter Template

[![Quality Gate](https://github.com/dgma/sol-starter/actions/workflows/quality-gate.yml/badge.svg)](https://github.com/dgma/sol-starter/actions/workflows/quality-gate.yml)

A comprehensive Solidity development template that combines Foundry and Hardhat for optimal smart contract development experience.

## Features

- **Dual Testing Framework**: Foundry for fast unit tests and Hardhat for integration tests
- **Modern Tooling**: Latest versions of Foundry, Hardhat, and OpenZeppelin contracts
- **Code Quality**: Pre-configured formatting, linting, and pre-commit hooks
- **Multi-Network Support**: Ready-to-use configurations for multiple testnets
- **Deployment Ready**: Automated deployment scripts with hardhat-sol-bundler
- **Gas Optimization**: Built-in gas reporting and optimization settings

## Requirements

- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you've done it right if you can run `git --version`
- [Node.js](https://nodejs.org/en) (v18 or higher)
- [Foundry / Foundryup](https://github.com/gakonst/foundry) for unit testing and development
- [Hardhat](https://hardhat.org/docs) for integration tests & deployment
- Optional: [Docker](https://www.docker.com/) for containerized development

## Quick Start

1. **Clone and install dependencies:**
```sh
git clone https://github.com/dgma/sol-starter.git
cd sol-starter
npm install
npx husky install
```

2. **Install Foundry dependencies:**
```sh
forge install foundry-rs/forge-std
```

3. **Set up environment variables:**
```sh
cp .env.example .env
# Edit .env with your configuration
```

4. **Run tests:**
```sh
# Unit tests with Foundry
forge test -vvv

# Integration tests with Hardhat
npm run int

# All tests
npm run test
```

## Available Scripts

### Development
- `npm run compile` - Compile contracts with Hardhat
- `npm run format` - Format Solidity code with Forge
- `npm run lint` - Lint Solidity code with Solhint
- `npm run gas` - Generate gas report

### Testing
- `npm run test` - Run all tests (Foundry + Hardhat)
- `npm run unit:all` - Run all Foundry unit tests
- `npm run int` - Run Hardhat integration tests

### Deployment
- `npm run deploy` - Deploy to specified network
- `npm run deploy:hh` - Deploy to Hardhat network
- `npm run deploy:localhost` - Deploy to localhost
- `npm run deploy:t` - Deploy to Optimism Sepolia

### Maintenance
- `npm run clean` - Clean all build artifacts and dependencies

## Project Structure

```
sol-starter/
├── src/                    # Smart contract source files
├── test/                   # Foundry unit tests
├── integration/            # Hardhat integration tests
├── lib/                    # Foundry dependencies
├── artifacts/              # Hardhat compilation artifacts
├── cache/                  # Foundry cache
├── foundry.toml           # Foundry configuration
├── hardhat.config.js      # Hardhat configuration
└── deployment.config.js   # Deployment configuration
```


### Environment Variables

Create a `.env` file with the following variables:

```env
# Private key for deployment (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# RPC URLs
SEPOLIA_RPC=https://sepolia.infura.io/v3/your_project_id
ARBITRUM_SEPOLIA_RPC=https://sepolia-rollup.arbitrum.io/rpc
OP_SEPOLIA_RPC=https://sepolia.optimism.io

# API Keys for verification
ETHERSCAN_API_KEY=your_etherscan_api_key
ARBISCAN_API_KEY=your_arbiscan_api_key
OPSCAN_API_KEY=your_opscan_api_key
```

## Supported Networks

- **Local Development**: Hardhat, Localhost
- **Testnets**: Sepolia, Arbitrum Sepolia, Optimism Sepolia
- **Mainnets**: Configurable via hardhat.config.js

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Resources

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Hardhat Documentation](https://hardhat.org/docs)
- [hardhat-sol-bundler Documentation](https://github.com/dgma/hardhat-sol-bundler)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Solidity Documentation](https://docs.soliditylang.org/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions:

- Open an [issue](https://github.com/dgma/sol-starter/issues)
- Check the [documentation](https://github.com/dgma/sol-starter)
- Join our community discussions

---

**Note**: This is a development template. Always audit your smart contracts before deploying to production networks.
