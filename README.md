# ZeroLedger Contracts

[![Quality Gate](https://github.com/zeroledger/contracts/actions/workflows/quality-gate.yml/badge.svg)](https://github.com/zeroledger/contracts/actions/workflows/quality-gate.yml)

A privacy-preserving ERC20 token vault system using zero-knowledge proofs for confidential transactions on Ethereum and compatible blockchains.

## Overview

ZeroLedger enables private ERC20 token transfers by using cryptographic commitments and zero-knowledge proofs. Users can deposit, spend, and withdraw tokens while maintaining transaction privacy through the use of Circom circuits and PLONK proving system.

## Key Features

- **🔒 Private Deposits**: Deposit tokens with cryptographic commitments using Poseidon hashes
- **🔄 Confidential Spends**: Transfer tokens between commitments using ZK proofs without revealing amounts
- **📊 Multiple Input/Output Support**: Flexible transaction structures supporting various combinations (1-1, 1-2, 1-3, 2-1, 2-2, 2-3, 3-1, 3-2, 3-3, 8-1, 16-1)
- **💰 Fee Support**: Configurable fees for transactions with dedicated fee recipients
- **🔐 Metadata Encryption**: Optional encrypted metadata for commitments
- **⚡ PLONK Proving System**: Efficient zero-knowledge proof generation and verification
- **🌐 Multi-Network Support**: Deployable on Ethereum and compatible L2 networks
- **🛡️ Security**: Built with OpenZeppelin contracts and comprehensive testing

## Architecture

### Smart Contracts

The ZeroLedger system consists of three main contracts designed for modularity and security:

- **Vault**: Core contract that stores and manages cryptographic commitments. Handles deposits, spends, and withdrawals while maintaining privacy through zero-knowledge proofs.

- **Forwarder**: Supports meta-transactions and batching operations. This contract is permissionless and enables users to execute transactions without paying gas fees directly, improving user experience and enabling complex transaction batching.

- **ProtocolManager**: Manages protocol-level parameters like fees and max protocol tvl.

- **Administrator**: Manages protocol contracts administrative functions like upgrades or emergency pausing

### Management & Security

**Multisig Governance**: All administrative functions, including fee updates, contract upgrades, and security measures, are managed through multisig wallets. This ensures that no single entity can make critical changes to the protocol.

- **Admin Multisig**: Controls protocol roles management
- **Maintainer Multisig**: Controls protocol contracts upgrades
- **Security Council Multisig**: Manages emergency pauses and security functions  
- **Treasury Manager Multisig**: Controls fee parameters and treasury operations

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
  - `spend_33`: 3 inputs, 3 outputs
  - `spend_82`: 8 inputs, 1 outputs
  - `spend_161`: 16 inputs, 1 output

## Requirements

- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Node.js](https://nodejs.org/en) (v18 or higher)
- [Foundry](https://github.com/gakonst/foundry) for unit testing and development
- [Hardhat](https://hardhat.org/docs) for integration tests & deployment

## Quick Start

1.**Clone and install dependencies:**

```bash
git clone https://github.com/zeroledger/contracts.git
cd contracts
npm install
npx husky install
```

2.**Install Foundry dependencies:**

```bash
forge install foundry-rs/forge-std
```

3.**Set up environment variables:**

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
- `npm run unit` - Run all Foundry unit tests
- `npm run int` - Run Hardhat integration tests

### Deployment

- `npm run deploy {network}` - Initial deploy to specified network

### Maintenance

- `npm run clean` - Clean all build artifacts and dependencies
- `VERSION_TAG={Version} npx hardhat ignition deploy ./ignition/modules/{Vault|Forwarder|ProtocolManager}.module.ts --network {network}` - Deploy new module version
- `FEES_CONFIG="{deposit};{spend};{withdraw}" TOKEN={token} npm run prepareFeesParams {network}` - create ready-to-set fees config for erc20 token

## Project Structure

```sh
contracts/
├── src/                      # Smart contract source files
│   ├── Administrator.sol     # Contract to admin roles for Forwarder, Vault, ProtocolManager contract administration
│   ├── Forwarder.sol         # Forwarder contract with ERC6492 support
│   ├── ProtocolManager.sol   # Contract to manage protocol parameters
│   ├── Vault.sol             # Main vault contract
│   ├── Vault.types.sol       # Vault types & interfaces
│   ├── Verifiers.sol          # ZK proof verifiers umbrella contract
│   ├── Roles.lib.sol         # Roles constants
│   └── Inputs.lib.sol        # Input utilities
├── helpers/                  # Helpers contracts
│   ├── MockERC20.sol         # Test token
│   └── Proxy.sol/            # ERC1967Proxy import
├── ignition/                 # Zero-knowledge circuits
│   ├── modules/              # hardhat ignition deployment modules
│   └── deployments/          # deployments artifacts
├── test/                     # Foundry unit tests
├── integration/              # Hardhat integration tests
├── circuits/                 # Zero-knowledge circuits (git module)
├── lib/                      # Foundry dependencies (git module)
└── abi/                      # Contract ABIs
```

## Environment Variables

Create a `.env` based on `.env.example`

## Supported Networks

- **Local Development**: Hardhat, Localhost
- **Testnets**: BaseSepolia

Networks are configurable via hardhat.config.js

## Security

- **Audited Dependencies**: Uses OpenZeppelin & solady contracts
- **Reentrancy Protection**: Built-in guards against reentrancy attacks
- **Access Control**: Proper authorization mechanisms with multisig governance
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
- [Solady Documentation](https://vectorized.github.io/solady/#/)
- [Solidity Documentation](https://docs.soliditylang.org/)

## License

This project is licensed under the GNU v3.0 License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions:

- Open an [issue](https://github.com/zeroledger/contracts/issues)
- Check the [documentation](https://github.com/zeroledger/protocol)
- Join our community discussions [telegram](https://t.me/+fCgwViQAehY0NTEy)

---

**Note**: This is experimental software. Always audit your smart contracts before deploying to production networks.
