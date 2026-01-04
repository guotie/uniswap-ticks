# Uniswap Ticks Query

Powerful and efficient Solidity contracts designed to query liquidity ticks from Uniswap V3 and its major forks (PancakeSwap V3, Aerodrome V3).

## Features

- **Multi-Protocol Support**: Compatible with Uniswap V3, PancakeSwap V3, and Aerodrome V3.
- **Efficient Querying**: Optimized to retrieve multiple liquidity ticks and pool state in a single call.
- **Gas Optimized**: Uses assembly and packed encoding for minimal gas consumption.
- **Flexible Data Retrieval**: Supports fetching specific ticks or entire ranges within a word.

## Documentation

For more information and detailed API documentation, visit [uint256.xyz](https://uint256.xyz).

## Deployment Addresses

The contracts are deployed on **Base Mainnet**:

| Contract | Address | Explorer |
| :--- | :--- | :--- |
| **UniswapV3PoolQuery** | `0xDf7acDFaab84FE57c999aEf080749845C97ca038` | [Basescan](https://basescan.org/address/0xdf7acdfaab84fe57c999aEf080749845C97ca038) |
| **PancakeV3Query** | `0x398FbFe61579090aEcC613a25BdeCffBa8D60313` | [Basescan](https://basescan.org/address/0x398fbfe61579090aecc613a25bdecffba8d60313) |
| **AerodromeV3Query** | `0xB369A9B58bE84783F47E66c244F79567E36367B1` | [Basescan](https://basescan.org/address/0xb369a9b58be84783f47e66c244f79567e36367b1) |

## Quick Start

### Prerequisites

Ensure you have [Foundry](https://book.getfoundry.sh/getting-started/installation) installed.

### Build

Compile the smart contracts:

```shell
forge build
```

### Format

Format the codebase:

```shell
forge fmt
```

## License

This project is licensed under the UNLICENSED License.
