# Rupay — Backend

Contract address (Sepolia)
### RupayIssuer
- 0xF2357a861393f95DBAA9356adf9ec14241d015D1     
 https://sepolia.etherscan.io/address/0xf2357a861393f95dbaa9356adf9ec14241d015d1

 ### Rupay (RUP)
 - 0x89D34DAC960300F710D19A23387E121633bc88c7    
 https://sepolia.etherscan.io/address/0x89D34DAC960300F710D19A23387E121633bc88c7

Overview
--------
Rupay is an over-collateralized USD-pegged stablecoin protocol. Users deposit supported collateral and mint RUP. This backend contains the core Solidity contracts, oracle integrations, tests and deployment scripts.

Highlights
- Chainlink oracle integration with freshness/sequencer checks.
- Deposit/mint and burn/redeem flows with liquidation mechanics.
- Extensive test coverage: unit tests, fuzzing and invariants using Foundry.
- Deployment scripts and network helper config for local and Sepolia deployments.
- Safety: Pausable and non-reentrant guards on critical flows.

## Getting Started

### Prerequisites

- [Git](https://git-scm.com/)
- [Foundry](https://book.getfoundry.sh/)

### Installation

1. Clone the repository
```bash
git clone https://github.com/YourGuyD3v/rupay.git
cd rupay
```

2. Install dependencies
```bash
forge install
```

3. Build the project
```bash
forge build
```

### Testing

Run all tests:
```bash
forge test
```

Run specific test:
```bash
forge test --mt <test_name>
```

Run with verbosity:
```bash
forge test -vvvv
```

### Deployment

1. Set up environment variables
```bash
cp .env.example .env
# Add your private key and RPC URLs
```

2. Deploy to network
```bash
forge script script/DeployRup.s.sol --rpc-url <RPC_URL> --broadcast --private-key <KEY>
```

## Project Structure

```
backend/
├── src/
│   ├── Rupay.sol               # ERC20 stablecoin
│   ├── RupIssuer.sol           # Collateral management, mint/redeem, liquidation
│   └── libraries/
│       └── ChainlinkOracleLib.sol
├── script/
│   ├── DeployRup.s.sol
│   └── HelperConfig.s.sol
├── test/
│   ├── unit/
│   └── fuzz/
├── foundry.toml
└── Makefile               # Deployment scripts
```

## Core Mechanics

- **Minting**: Users deposit collateral and mint RUP
- **Burning**: Users burn RUP to redeem collateral
- **Liquidation**: Positions below  (protocol-configured ratio) collateral ratio can be liquidated
- **Oracle**: Chainlink price feeds for collateral valuation and sequencer checks.

## License

MIT