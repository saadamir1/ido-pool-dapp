# IDO Pool DApp

A decentralized application for Initial DEX Offering (IDO) token sales with ERC-20 payment integration and refund mechanisms.

## Overview

This IDO Pool DApp allows:
- Token sales using custom ERC-20 token as payment (not native ETH)
- Refund mechanisms for both users and admins
- Secure token distribution after IDO completion
- Complete admin control for IDO management

## Features

- **ERC-20 Payment**: Accept payments in any ERC-20 token
- **Refund Mechanisms**: Allow users to claim refunds under specific conditions
- **Admin Controls**: Start/end IDO, enable/disable refunds, withdraw funds
- **Security**: Protection against reentrancy attacks and other vulnerabilities
- **User-friendly Interface**: Simple UI for participants and admins

## Quick Start Guide

### Prerequisites
- MetaMask wallet extension
- Node.js installed
- Basic understanding of blockchain and smart contracts

### Deployment Steps

1. **Deploy Mock Tokens for Testing (Optional)**

```
// Deploy via Remix IDE or Hardhat
// Deploy MockERC20 for both IDO token and payment token:
MockERC20(name, symbol, initialSupply)
// Example:
// IDO Token: MockERC20("IDO Token", "IDO", "1000000000000000000000000")
// Payment Token: MockERC20("Payment Token", "PAY", "1000000000000000000000000")
```

2. **Deploy the IDO Pool Contract**

```
// Deploy via Remix IDE or Hardhat:
IDOPool(
    idoTokenAddress,
    paymentTokenAddress,
    tokenPrice,
    softCap,
    hardCap,
    minContribution,
    maxContribution
)

// Example parameters:
// idoTokenAddress: Address of your IDO token
// paymentTokenAddress: Address of the payment token
// tokenPrice: "100000000000000000" (0.1 token per IDO token)
// softCap: "10000000000000000000" (10 tokens)
// hardCap: "100000000000000000000" (100 tokens)
// minContribution: "1000000000000000000" (1 token)
// maxContribution: "10000000000000000000" (10 tokens)
```

3. **Update Contract Address in Frontend**

Open `index.html` and update the contract addresses:

```javascript
// Line 182 - Replace with your deployed contract address
const idoPoolAddress = "0xYourIDOPoolContractAddress";
```

4. **Run the Frontend**

```bash
# Install a simple HTTP server
npm init -y
npm install http-server

# Run the server
npx http-server
```

5. **Access the DApp**

Open your browser and navigate to `http://localhost:8080`

## Testing Guide

### Contract Setup
1. Deploy the IDO and payment token contracts
2. Deploy the IDO Pool contract with appropriate parameters
3. Transfer IDO tokens to the IDO Pool contract

### User Testing
1. Connect MetaMask wallet
2. Approve payment tokens for the IDO Pool contract
3. Contribute to the IDO
4. Claim tokens after IDO ends
5. Test refund functionality if conditions are met

### Admin Testing
1. Start the IDO with appropriate timing parameters
2. End the IDO (optionally early)
3. Enable/disable refunds
4. Withdraw raised funds after successful IDO
5. Withdraw unsold tokens if any

## Security Considerations

- The contract uses OpenZeppelin's SafeERC20 for secure token transfers
- ReentrancyGuard prevents reentrancy attacks during token operations
- Ownable pattern restricts sensitive functions to contract owner
- All user operations are properly validated before execution

## Notes for Developers

- Test thoroughly on testnet before deploying to mainnet
- Ensure contract parameters align with your tokenomics
- Consider adding more detailed events for better front-end tracking
- Use proper error messages for better user experience

## License

MIT