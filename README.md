# Flash Loan Arbitrage Bot

A collection of Solidity smart contracts that execute arbitrage opportunities using flash loans and Uniswap V3 pools.

## Overview

This repository contains multiple arbitrage contracts, each optimized for different use cases:

1. **[FlashLoanArbitrage](./docs/FlashLoanArbitrage.md)** - Uses Aave V3 flash loans for multi-token, cross-pool arbitrage
2. **[UniswapFlashArbitrage](./docs/UniswapFlashArbitrage.md)** - Uses Uniswap V3 native flash swaps for zero-fee, same-pool arbitrage

## Quick Comparison

| Feature | FlashLoanArbitrage | UniswapFlashArbitrage |
|---------|-------------------|----------------------|
| **Flash Loan Source** | Aave V3 Pool | Uniswap V3 Pool |
| **Supported Tokens** | 100+ Aave-supported tokens | 2 tokens per pool (token0/token1) |
| **Fees** | 0.05% - 0.09% of borrowed amount | Zero fees (only pay back what you borrow) |
| **Best For** | Multi-token, cross-pool arbitrage | Same-pool pair arbitrage |
| **Gas Cost** | ~50,000 - 70,000 gas | ~40,000 - 60,000 gas |
| **Flexibility** | High (multiple tokens, multiple pools) | Medium (single pool pair) |

## Contracts

### [FlashLoanArbitrage](./docs/FlashLoanArbitrage.md)

**Use when:** You need to arbitrage across multiple token pairs or want access to 100+ tokens.

- ✅ Borrow any Aave-supported token
- ✅ Execute complex multi-hop routes
- ✅ Cross-pool arbitrage
- ✅ Higher liquidity (Aave aggregates liquidity)

[Read Full Documentation →](./docs/FlashLoanArbitrage.md)

### [UniswapFlashArbitrage](./docs/UniswapFlashArbitrage.md)

**Use when:** You're arbitraging within a single pool pair and want zero fees.

- ✅ Zero flash loan fees
- ✅ Direct pool access
- ✅ Lower gas costs
- ✅ Simple deployment (no Aave pool needed)

[Read Full Documentation →](./docs/UniswapFlashArbitrage.md)

## Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- [Node.js](https://nodejs.org/) and npm installed

### Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd flash-loan-arbitrage
   ```

2. **Install Foundry dependencies (git submodules):**
   ```bash
   forge install
   ```
   This will install:
   - `forge-std` - Foundry standard library
   - `v3-core` - Uniswap V3 Core contracts
   - `openzeppelin-contracts-upgradeable` - OpenZeppelin contracts
   - `openzeppelin-foundry-upgrades` - OpenZeppelin Foundry upgrades
   
   **Note:** If cloning fresh, you may also need:
   ```bash
   git submodule update --init --recursive
   ```

3. **Install npm dependencies:**
   ```bash
   npm install
   ```
   This will install:
   - `@aave/core-v3` - Aave V3 Core contracts (for Solidity interfaces)
   
   **Note:** `package-lock.json` is committed to ensure consistent versions.

4. **Set up environment variables:**
   
   Create a `.env` file in the root directory:
   ```bash
   cp .env.example .env
   # Then edit .env and fill in your values
   ```
   
   Add the following environment variables to your `.env` file:
   
   **Required for FlashLoanArbitrage deployment:**
   ```bash
   # Your private key
   PRIVATE_KEY=your_private_key_here
   
   # Aave V3 Pool address for your target network (Base example)
   AAVE_POOL_ADDRESS=0xA238Dd80C259a72e81d7e4664a9801593F98d1c5
   ```
   
   **Required for UniswapFlashArbitrage deployment:**
   ```bash
   # Your private key
   PRIVATE_KEY=your_private_key_here
   ```
   
   **Optional variables:**
   ```bash
   # Minimum profit threshold in wei (default: 0.001 ETH)
   MIN_PROFIT_WEI=1000000000000000
   
   # For checking/updating deployed contract
   FLASH_LOAN_CONTRACT_ADDRESS=0x...
   NEW_MIN_PROFIT_WEI=1
   
   # For contract verification (Base)
   BASESCAN_API_KEY=your_basescan_api_key
   
   # For fork tests (optional)
   HTTP_RPC_URL=https://mainnet.base.org
   CHAIN_ID=8453
   ```
   
   **Security Note:** Never commit your `.env` file. It's already in `.gitignore`.

5. **Build the project:**
   ```bash
   forge build
   ```

## Usage 

### Build

```bash
forge build
```

### Test

```bash
# Test all contracts
forge test

# Test specific contract
forge test --match-contract FlashLoanArbitrageTest
forge test --match-contract UniswapFlashArbitrageTest
```

### Format

```bash
forge fmt
```

### Deploy

**FlashLoanArbitrage:**
```bash
forge script script/Deploy.s.sol:DeployFlashLoanArbitrage --rpc-url base --broadcast
```

**UniswapFlashArbitrage:**
```bash
# Create deployment script first, then:
forge script script/DeployUniswapFlash.s.sol:DeployUniswapFlashArbitrage --rpc-url base --broadcast
```

## Project Structure

```
flash-loan-arbitrage/
├── src/
│   ├── FlashLoanArbitrage.sol          # Aave flash loan arbitrage contract
│   └── UniswapFlashArbitrage.sol        # Uniswap flash swap arbitrage contract
├── script/                              # Deployment scripts
├── test/                                # Test files
│   ├── FlashLoanArbitrage.t.sol
│   ├── UniswapFlashArbitrage.t.sol
│   └── mocks/                           # Mock contracts for testing
├── docs/                                # Contract-specific documentation
│   ├── FlashLoanArbitrage.md
│   └── UniswapFlashArbitrage.md
├── lib/                                 # Foundry dependencies (git submodules)
├── node_modules/                        # npm dependencies
├── foundry.toml                         # Foundry configuration
├── remappings.txt                       # Solidity import remappings
└── package.json                         # npm dependencies
```

## Common Patterns

### Gas Optimization

Both contracts use **direct pool swaps** instead of SwapRouter for optimal gas efficiency:

- **Direct `pool.swap()`**: ~99,000 gas per swap
- **SwapRouter**: ~107,000 gas per swap
- **Savings**: ~9,500-11,500 gas per swap

This is critical for arbitrage profitability.

### Security Features

Both contracts implement:
- ✅ Reentrancy protection (`nonReentrant` modifier)
- ✅ Owner-only access control
- ✅ Route validation (ensures routes end with borrowed token)
- ✅ Minimum profit checks
- ✅ Callback validation

## Dependencies

### Foundry Dependencies (via `forge install`)
- `forge-std` - Testing and scripting utilities
- `v3-core` - Uniswap V3 interfaces
- `openzeppelin-contracts-upgradeable` - OpenZeppelin contracts

### npm Dependencies (via `npm install`)
- `@aave/core-v3` - Aave V3 interfaces (required for FlashLoanArbitrage)

## Documentation

- [FlashLoanArbitrage Documentation](./docs/FlashLoanArbitrage.md) - Detailed guide for Aave flash loan arbitrage
- [UniswapFlashArbitrage Documentation](./docs/UniswapFlashArbitrage.md) - Detailed guide for Uniswap flash swap arbitrage
- [Foundry Book](https://book.getfoundry.sh/)
- [Aave V3 Documentation](https://docs.aave.com/)
- [Uniswap V3 Documentation](https://docs.uniswap.org/contracts/v3/overview)

## Contributing

This is a portfolio project demonstrating flash loan arbitrage implementations. Contributions and feedback are welcome!

## License

MIT
