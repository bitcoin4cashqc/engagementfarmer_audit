# EFarm Contract Overview

## Good Points:

- **OpenZeppelin Basic Contracts**: 
  - The use of OpenZeppelin’s `ERC20`, `AccessControl`, and `ReentrancyGuard` ensures security, modularity, and prevents reentrancy attacks.

- **Access Control System**:
  - Roles like `PHASE_ADMIN_ROLE`, `TOKEN_MINTER_ROLE`, and `TOKEN_BURNER_ROLE` provide well-defined access, making the contract modular and easily governable.

---

## Areas to Improve:

### 1. Struct Usage for User Giveaways (Committed)

- **Current**: Each user's giveaway is managed via a struct (`UserPhaseData`) that stores both `tokenAmount` and `claimed` status.
  
- **Improvement**: 
  - Instead of using a struct, maintain an internal balance for each user. This reduces complexity and gas costs involved in storing and updating multiple values. 
  - The backend can increase the balance directly, and the user decreases it when claiming rewards.
  - Example: 
    ```solidity
    mapping(address => uint256) public userInternal; 
    uint256 toClaim = userInternal[userWallet];
    ```
    This tracks each user's internal balance.

---

### 2. Mass Distributions via Backend

- **Current**: The backend updates token amounts for each user, but users still have to call a separate `claimRewards` function, incurring additional gas.

- **Improvement**: 
  - The backend can directly distribute tokens to users without them needing to claim. Instead of updating a user's internal balance and then having them claim, the backend could transfer the tokens directly, saving gas by eliminating the extra `claimRewards` call.
  - This shifts more gas costs to the backend, but simplifies the user experience, particularly for non-crypto-savvy users.
  - If users don't have to buy crypto, they could be more incentivized to participate, as they would receive tokens without needing to spend or interact with a smart contract (other than installing a wallet like MetaMask).

---

### 3. Storing Phase Tokens in Contract (Committed)

- **Current**: Tokens to be distributed in each phase are stored with the contract’s `owner()` address, requiring transfers from the owner to users upon claiming.

- **Improvement**: 
  - Store the tokens within the contract itself, making the token distribution process more gas-efficient and straightforward.
  - This eliminates the need for owner approval or transfers, and increases security since the tokens are no longer held by an Externally Owned Address (EOA).

---

### 4. User Data Struct Optimization (Committed)

- **Current**: The `UserPhaseData` struct stores `tokenAmount` and `claimed` status, both stored separately for each phase.

- **Improvement**: 
  - Track only the token amount and eliminate the `claimed` status under the direct distribution model. 
  - If you need to display data about when tokens were given, you can use an event or store the data locally.
  - Events can track when the backend gives tokens, and you can store additional details like tweet data in a local database. This allows you to display the data in the app without requiring Web3 interaction.
  
---

### 5. Redundant Functions

- **Current**: Functions like `getTokenAmountsByAddress` return arrays of data, which can be gas-intensive to both deploy and call on-chain.

- **Improvement**: 
  - Consider removing these functions. You can call public variables or mappings directly from a contract without needing a function (e.g., `userInternal[phase][userWallet] = uint256`). 
  - Additionally, you can query all events (such as claims) users have made by leveraging emitted events.

---

## Short Explanation:

By eliminating unnecessary structs and optimizing token distribution, you can significantly reduce gas costs. Using internal balances for users and distributing tokens directly during batch updates, while storing phase tokens within the contract, will simplify the architecture and lower overall transaction fees. Removing the need for users to claim rewards and optimizing phase and user data tracking leads to more streamlined operations.

---

## Conclusion:

The major improvements focus on:
- Removing reliance on `owner()` as an Externally Owned Address (EOA) for holding the to-be-distributed tokens.
- Using mappings instead of structs for phase and user phase data.
- Implementing more efficient storage and distribution mechanisms to optimize the contract for lower gas usage and better scalability.
