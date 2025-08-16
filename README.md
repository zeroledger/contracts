# ZeroLedger Contracts

[![Quality Gate](https://github.com/zeroledger/contracts/actions/workflows/quality-gate.yml/badge.svg)](https://github.com/zeroledger/contracts/actions/workflows/quality-gate.yml)

A privacy-preserving ERC20 token vault system using zero-knowledge proofs for confidential transactions on Ethereum and compatible blockchains.

## Overview

ZeroLedger enables private ERC20 token transfers by using cryptographic commitments and zero-knowledge proofs. Users can deposit, spend, and withdraw tokens while maintaining transaction privacy through the use of Circom circuits and PLONK proving system.

## Key Features

- **🔒 Private Deposits**: Deposit tokens with cryptographic commitments using Poseidon hashes
- **🔄 Confidential Spends**: Transfer tokens between commitments using ZK proofs without revealing amounts
- **📊 Multiple Input/Output Support**: Flexible transaction structures supporting various combinations (1-1, 1-2, 1-3, 2-1, 2-2, 2-3, 3-1, 3-2, 16-1)
- **💰 Fee Support**: Configurable fees for transactions with dedicated fee recipients
- **🔐 Metadata Encryption**: Optional encrypted metadata for commitments
- **⚡ PLONK Proving System**: Efficient zero-knowledge proof generation and verification
- **🌐 Multi-Network Support**: Deployable on Ethereum and compatible L2 networks
- **🛡️ Security**: Built with OpenZeppelin contracts and comprehensive testing

## Architecture

### Smart Contracts
- **Vault.sol**: Main contract managing deposits, spends, and withdrawals
- **Verifiers.sol**: ZK proof verification contracts for all circuit types
- **MockERC20.sol**: Test token for development and testing

### Zero-Knowledge Circuits
- **Deposit Circuit**: Validates 3 input commitments sum to total deposit amount
- **Spend Circuits**: Multiple variants supporting different input/output combinations:
  - `spend_11`: 1 input, 1 output
  - `spend_12`: 1 input, 2 outputs
  - `spend_13`: 1 input, 3 outputs
  - `spend_21`: 2 inputs, 1 output
  - `spend_22`: 2 inputs, 2 outputs
  - `spend_23`: 2 inputs, 3 outputs
  - `spend_31`: 3 inputs, 1 output
  - `spend_32`: 3 inputs, 2 outputs
  - `spend_161`: 16 inputs, 1 output

## Requirements

- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Node.js](https://nodejs.org/en) (v18 or higher)
- [Foundry](https://github.com/gakonst/foundry) for unit testing and development
- [Hardhat](https://hardhat.org/docs) for integration tests & deployment

## Quick Start

1. **Clone and install dependencies:**
```bash
git clone https://github.com/zeroledger/contracts.git
cd contracts
npm install
npx husky install
```

2. **Install Foundry dependencies:**
```bash
forge install foundry-rs/forge-std
```

3. **Set up environment variables:**
```bash
cp .env.example .env
# Edit .env with your configuration
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
contracts/
├── src/                    # Smart contract source files
│   ├── Vault.sol          # Main vault contract
│   ├── Vault.types.sol    # Type definitions
│   ├── Verifiers.sol      # ZK proof verifiers
│   ├── MockERC20.sol      # Test token
│   └── Inputs.lib.sol     # Input utilities
├── circuits/              # Zero-knowledge circuits
│   ├── circuits/          # Circom circuit definitions
│   ├── contracts/         # Generated verifier contracts
│   ├── test/             # Circuit tests
│   └── utils/            # Circuit utilities
├── test/                  # Foundry unit tests
├── integration/           # Hardhat integration tests
├── abi/                   # Contract ABIs
├── lib/                   # Foundry dependencies
├── artifacts/             # Hardhat compilation artifacts
└── cache/                 # Foundry cache
```

## Environment Variables

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

## Security

- **Audited Dependencies**: Uses OpenZeppelin contracts
- **Reentrancy Protection**: Built-in guards against reentrancy attacks
- **Access Control**: Proper authorization mechanisms
- **Zero-Knowledge Proofs**: Cryptographic privacy guarantees
- **Comprehensive Testing**: Extensive test coverage: In progress  

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Resources

- [ZeroLedger Protocol Documentation](https://github.com/zeroledger/protocol)
- [Foundry Documentation](https://book.getfoundry.sh/)
- [Hardhat Documentation](https://hardhat.org/docs)
- [Circom Documentation](https://docs.circom.io/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Solidity Documentation](https://docs.soliditylang.org/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions:

- Open an [issue](https://github.com/zeroledger/contracts/issues)
- Check the [documentation](https://github.com/zeroledger/protocol)
- Join our community discussions

---

**Note**: This is experimental software. Always audit your smart contracts before deploying to production networks.
