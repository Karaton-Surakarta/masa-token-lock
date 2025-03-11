# MASA Token Distributor

A secure and efficient smart contract solution for phased token distribution on Ethereum and compatible blockchains.

## Overview

MASA Token Distributor provides a secure mechanism for distributing MASA tokens to eligible users in multiple phases. The system uses Merkle proofs to verify user eligibility and distributes tokens in four monthly batches, each releasing 25% of the total allocation to users.

## Key Features

- **Phased Distribution**: Releases 25% of a user's total token allocation each month
- **Merkle Proof Verification**: Ensures only eligible users can claim tokens
- **Claim Threshold Control**: Owner can enable new phases by incrementing the claim threshold
- **Secure Implementation**: Built with OpenZeppelin contracts for security
- **Gas Optimization**: Uses Merkle proofs for efficient verification
- **Reentrancy Protection**: Prevents exploitation through reentrancy attacks
- **Flexible Administration**: Allows updating the Merkle root when needed

## Distribution Phases

The distribution operates in four phases, each unlocking 25% of the total allocation:

1. **Phase 1**: First 25% of tokens become claimable
2. **Phase 2**: Second 25% becomes claimable (total 50%)
3. **Phase 3**: Third 25% becomes claimable (total 75%)
4. **Phase 4**: Final 25% becomes claimable (total 100%)

Each phase is enabled by the contract owner by updating the claim count threshold.

## Contract Documentation

### MasaDistributor.sol

The main contract that manages the phased token distribution:

- `claim(uint256 _amount, bytes32[] calldata _proof)`: Allows users to claim their allocated tokens for the current phase
- `updateClaimCountThreshold(uint256 _newThreshold)`: Enables new distribution phases by increasing the claim threshold
- `updateMerkleRoot(bytes32 _newRoot)`: Updates the Merkle root to modify the distribution list
- `withdrawTokens(address _token)`: Allows the owner to withdraw tokens from the contract
- `checkCanClaim(address _user, uint256 _amount, bytes32[] calldata _proof)`: Verifies if a user can claim the specified amount

## Distribution Mechanism

1. A Merkle tree is generated off-chain containing all user addresses and their total allocation amounts
2. Users can claim 25% of their allocation in each distribution phase
3. The contract owner increases the claim threshold to enable each new phase
4. Users provide Merkle proofs with their claim to verify eligibility

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) v16+ and npm/pnpm
- [Hardhat](https://hardhat.org/)
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (optional)

### Installation

1. Clone the repository:

```shell
git clone https://github.com/yourusername/masa-token-distributor.git
cd masa-token-distributor
```

2. Install dependencies:

```shell
pnpm install
```

## Development and Testing

This project uses both Hardhat and Foundry environments, with the hardhat-foundry plugin to integrate them. Primary testing is done using Foundry for its speed and comprehensive testing capabilities.

### Compiling Contracts

```shell
# Using Hardhat
npx hardhat compile

# Using Foundry
forge build
```

### Running Tests

```shell
# Primary testing with Foundry
forge test -vv

# Additional Hardhat tests (if any)
npx hardhat test
```

### Coverage Reports

```shell
forge coverage
```

### Generating Merkle Tree

Before using the contract, you need to generate a Merkle tree with the list of recipients and their token allocations. The project includes scripts to generate both the Merkle tree and proofs:

```shell
npx hardhat run scripts/generate-merkle-tree.js
```

### Deploying the Distributor

```shell
# Using Hardhat
npx hardhat run scripts/deploy.js --network <network_name>

# Using Foundry
forge script scripts/Deploy.s.sol --rpc-url <rpc_url> --broadcast --verify
```

## Contract Interaction Examples

### Claiming Tokens

Users can claim their tokens by providing their allocation amount and a valid Merkle proof:

```javascript
// Frontend example (ethers.js)
const amount = ethers.utils.parseEther("1000"); // 1000 MASA tokens
const proof = [
  /* Merkle proof from backend */
];
await distributor.claim(amount, proof);
```

### Enabling New Distribution Phase

The contract owner can enable new distribution phases:

```javascript
// For enabling the second distribution phase (50% total)
await distributor.updateClaimCountThreshold(2);
```

## Security Considerations

- Merkle proofs are cryptographically secure and gas-efficient for large distribution lists
- The contract uses ReentrancyGuard to prevent reentrancy attacks
- The contract owner has limited privileges to maintain the distribution process
- Users can verify their inclusion in the Merkle tree through the provided verification functions

## License

This project is licensed under the [MIT License](LICENSE).
