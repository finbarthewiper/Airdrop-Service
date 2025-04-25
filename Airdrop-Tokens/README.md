# Token Airdrop Distribution Smart Contract

## Overview

This Clarity smart contract manages token airdrops to eligible recipients on the Stacks blockchain. It provides a complete system for distributing tokens to whitelisted addresses with robust administrative controls, eligibility verification, and transparent event logging.

## Features

- **Recipient Management**: Add or remove eligible recipients individually or in batches
- **Token Distribution**: Allow whitelisted users to claim their allocated tokens
- **Administrative Controls**: Modify distribution parameters like reward size and lockup periods
- **Token Recovery**: Reclaim unclaimed tokens after a specified waiting period
- **Event Logging**: Track all important actions performed through the contract

## Contract Variables

### Administrative Constants
- `admin-address`: The contract deployer who has exclusive administrative privileges
- Various error constants (e.g., `ERR-ADMIN-ONLY`, `ERR-USER-NOT-ELIGIBLE`)

### State Variables
- `distribution-active`: Boolean flag indicating if token distribution is active
- `tokens-sent-total`: Running total of tokens that have been claimed
- `reward-size`: Amount of tokens allocated per recipient
- `launch-block`: Block height when the airdrop was initiated
- `lockup-duration`: Number of blocks before unclaimed tokens can be reclaimed

### Data Maps
- `whitelist`: Tracks which addresses are eligible for the airdrop
- `claim-ledger`: Records which addresses have claimed their tokens and how much
- `event-history`: Stores a log of all significant contract events

## Public Functions

### Administrative Functions

#### `whitelist-address`
Adds a specific address to the whitelist of eligible recipients.
```clarity
(define-public (whitelist-address (user principal))
```

#### `remove-from-whitelist`
Removes an address from the whitelist of eligible recipients.
```clarity
(define-public (remove-from-whitelist (user principal))
```

#### `batch-whitelist`
Adds multiple addresses to the whitelist in a single transaction (up to 200).
```clarity
(define-public (batch-whitelist (users (list 200 principal)))
```

#### `change-reward-amount`
Updates the token amount allocated to each eligible recipient.
```clarity
(define-public (change-reward-amount (new-amount uint))
```

#### `update-lockup-period`
Changes the waiting period before unclaimed tokens can be reclaimed.
```clarity
(define-public (update-lockup-period (new-duration uint))
```

### Distribution Functions

#### `redeem-tokens`
Allows eligible recipients to claim their allocated tokens.
```clarity
(define-public (redeem-tokens)
```

#### `burn-unclaimed-tokens`
Allows the admin to reclaim unclaimed tokens after the lockup period.
```clarity
(define-public (burn-unclaimed-tokens)
```

### Read-Only Functions

#### `check-distribution-status`
Returns whether the distribution is currently active.
```clarity
(define-read-only (check-distribution-status)
```

#### `is-whitelisted`
Checks if an address is eligible for the airdrop.
```clarity
(define-read-only (is-whitelisted (address principal))
```

#### `has-redeemed`
Checks if an address has already claimed their tokens.
```clarity
(define-read-only (has-redeemed (address principal))
```

#### `get-redeemed-amount`
Returns the amount of tokens claimed by a specific address.
```clarity
(define-read-only (get-redeemed-amount (address principal))
```

#### `get-total-distributed`
Returns the total number of tokens distributed so far.
```clarity
(define-read-only (get-total-distributed)
```

#### `get-reward-amount`
Returns the current token allocation per recipient.
```clarity
(define-read-only (get-reward-amount)
```

#### `get-lockup-period`
Returns the current lockup period duration.
```clarity
(define-read-only (get-lockup-period)
```

#### `get-launch-block`
Returns the block height when the airdrop was initiated.
```clarity
(define-read-only (get-launch-block)
```

#### `get-transaction-log`
Retrieves detailed information about a specific event.
```clarity
(define-read-only (get-transaction-log (event-id uint))
```

## Usage Guide

### For Administrators

1. **Deploy the Contract**:
   - Upon deployment, the contract mints the total token supply to the admin address.

2. **Manage Eligible Recipients**:
   - Add recipients individually with `whitelist-address`.
   - Add multiple recipients with `batch-whitelist`.
   - Remove recipients with `remove-from-whitelist`.

3. **Configure Distribution Parameters**:
   - Modify token amount per recipient with `change-reward-amount`.
   - Adjust the lockup period with `update-lockup-period`.

4. **Reclaim Unclaimed Tokens**:
   - After the lockup period, call `burn-unclaimed-tokens` to reclaim unclaimed tokens.

### For Recipients

1. **Check Eligibility**:
   - Verify if you're eligible using `is-whitelisted`.

2. **Claim Tokens**:
   - If eligible, call `redeem-tokens` to receive your allocated tokens.

3. **Verify Receipt**:
   - Confirm your claimed amount with `get-redeemed-amount`.

## Security Considerations

- All administrative functions are restricted to the contract deployer
- Token amounts and eligibility are verified before execution
- Distribution can be paused if needed
- Events are logged for transparency and auditability
- Unclaimed tokens can only be reclaimed after the lockup period

## Error Codes

| Code | Description |
|------|-------------|
| 100  | Operation restricted to admin |
| 101  | Tokens already claimed by this address |
| 102  | Address not eligible for airdrop |
| 103  | Insufficient token balance for distribution |
| 104  | Token distribution is currently paused |
| 105  | Invalid token amount specified |
| 106  | Reclamation attempted before lockup period |
| 107  | Recipient already exists in whitelist |
| 108  | Invalid timeframe specified |

## Implementation Notes

- The contract initializes by minting 1 billion tokens to the admin address
- Events are tracked using an incrementing ID system
- Token distribution requires active distribution status, valid whitelist status, and sufficient token balance