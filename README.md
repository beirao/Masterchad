# MasterChad

This repository contains two versions of staking contracts: a standard Solidity implementation (`Masterchef.sol`) and a highly optimized YUL-based implementation (`Masterchad.sol`).

## Overview

MasterChef contracts are designed to distribute token rewards to users who stake LP tokens in various pools. The system works as follows:

- Users deposit LP tokens into pools
- The contract distributes rewards proportionally based on allocation points
- Each pool has a different reward rate determined by its allocation points
- Rewards accumulate over time and can be claimed during deposit or withdrawal

## Contracts

### Masterchef.sol

The standard Solidity implementation that uses traditional data structures and coding patterns:

- Uses `struct` for `PoolInfo` and `UserInfo`
- Implements staking mechanism with reward distribution
- Simple and readable implementation

### Masterchad.sol

A highly optimized version that uses Yul for direct memory and storage manipulation:

- Uses custom storage layout for gas optimization
- Implements the same functionality but with significant gas savings
- Uses assembly for most operations to minimize bytecode size and execution cost
- Implements storage packing techniques for maximum efficiency

## Key Features

- **Token Distribution**: Automatic reward token distribution based on block times
- **Multiple Pools**: Support for multiple staking pools with different rewards
- **Fair Allocation**: Distribution of rewards based on contribution to the pool
- **Safe Transfers**: Protection against rounding errors in token transfers

## Usage

### Adding a New Pool

Only the owner can add a new pool:

```solidity
function add(uint256 _allocPoint, address _lpToken) public onlyOwner
```

### Depositing LP Tokens

Users can deposit LP tokens into a pool:

```solidity
function deposit(uint256 _pid, uint256 _amount) public
```

### Withdrawing LP Tokens

Users can withdraw their LP tokens and claim rewards:

```solidity
function withdraw(uint256 _pid, uint256 _amount) public
```

### Updating Pools

Update the reward variables for a specific pool:

```solidity
function updatePool(uint256 _pid) public
```

## Performance Comparison

The Masterchad (YUL) implementation offers significant gas savings compared to the standard Masterchef implementation:

- Lower deployment cost
- Reduced gas costs for deposits and withdrawals
- More efficient storage usage

## Gas Consumption Comparison

| Operation | MasterChef | MasterChad | Savings |
|-----------|------------|------------|---------|
| Deployment | 1,352,754 | 1,034,628 | 23.5% |
| Add Pool | 140,048 | 95,290 | 32.0% |
| Deposit (avg) | 114,385 | 107,026 | 6.4% |
| Withdraw (avg) | 113,951 | 98,251 | 13.8% |
| Get Pool Info | 2,570 | 1,818 | 29.3% |
| Get User Info | 1,336 | 1,225 | 8.3% |

MasterChad performs between 6% and 32% better than MasterChef on gas consumption across all operations, with an average improvement of approximately 19%. The most significant savings are seen in pool management operations and deployment costs.

## Documentation

https://book.getfoundry.sh/

## Usage

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

## License

MIT
