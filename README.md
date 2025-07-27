# Quadratic-voting-system-for-DAOs-in-Solidity
A secure, gas-efficient smart contract implementing a quadratic voting system for DAO governance using ERC20 tokens.

Final year project on secure and scalable DAO voting mechanisms using Solidity and ERC20.

---

# 🪙 Quadratic Voting Smart Contract for DAOs

This repository contains a Solidity smart contract that implements a **quadratic voting system for DAOs (Decentralized Autonomous Organizations)**. The contract allows participants to register, propose initiatives, vote using quadratic weighting and execute approved proposals - all **on-chain**.

> The complete design rationale and analysis are detailed in the project's technical report (Spanish only): `Rummikub-Technical-Report.pdf`.

## Documentation
- **QuadraticVoting.sol:** Main smart contract handling proposals, voting, staking, etc.
- **ERC20Token.sol:** Custom token implementation extending OpenZeppelin’s ERC20.
- **IExecutableProposal.sol:** Interface for external proposal contracts.

## Features

- **Quadratic Voting**: Vote costs grow quadratically (1, 4, 9, ...).
- **Two Proposal Types**:
  - Funding proposals with a budget.
  - Signaling proposals (no budget, non-binding).
- **Dynamic Threshold Approval**: Proposals are approved once a calculated threshold is met.
- **ERC20 Token Integration**: Users vote using a dedicated ERC20 token created during deployment.
- **Gas efficient architecture**: Avoids loops in critical functions using `pull over push` pattern.
- **Secure and modular**:
  - Proposal execution through interfaces.
  - Protection against common vulnerabilities.

## 🔐 Security Measures

| Vulnerability                | Mitigation                                                                 | Code Reference                                       |
|-----------------------------|----------------------------------------------------------------------------|------------------------------------------------------|
| **Overflow/Underflow**      | Solidity ^0.8.0 prevents them by default                                   | All arithmetic operations                            |
| **Unchecked Arithmetic**    | Used only where overflow is realistically impossible                       | `nProposals`, `nParticipants`, `withdrawFromProposal()` |
| **Reentrancy**              | Guarded using `lock` modifier                                              | `stake()`, `withdrawFromProposal()`, `executeSignaling()` |
| **DelegateCall Attack**     | No delegateCall used. Owner is set via constructor                         | Constructor                                          |
| **tx.origin misuse**        | Only uses `msg.sender` for access control                                  | All modifiers                                        |
| **Block Timestamp Abuse**   | Contract logic does not rely on block timestamps                           | —                                                    |
| **Denial of Service (DoS)** | Avoided using "pull over push" design in `closeVoting()`                   | `executeSignaling()`, memory design                  |

🔁 Reentrancy Attacks
Protection: The contract uses a lock variable (a classic mutex pattern) to prevent reentrancy on sensitive functions.

Applied in:

stake()

withdrawFromProposal()

checkAndExecuteProposal()

executeSignaling()

Why it's important: Prevents a malicious contract from recursively calling vulnerable functions before the state is updated.

🧬 DelegateCall / Parity Wallet Attack
Protection: The contract does not use delegatecall.

Ownership is set directly via the constructor and is never altered externally.

Why it matters: Prevents unintentional code execution in the context of your contract — the flaw behind the infamous Parity Wallet hack.

🔗 tx.origin Exploits
Protection: All access control is enforced using msg.sender, never tx.origin.

Why it matters: Using tx.origin can allow phishing-style attacks where users unknowingly trigger functions from a malicious contract.

🕒 Timestamp Manipulation
Protection: The contract does not use block.timestamp for logic, so it’s immune to miners influencing voting timing.

🚫 Denial of Service (DoS) via Loops
Problem: Iterating over large arrays (e.g., during closeVoting) can cause DoS due to gas limits.

Solution: We implemented the "favor pull over push" pattern:

Participants reclaim their own tokens via withdrawFromProposal.

Signaling proposals are executed individually via executeSignaling.

Benefit: No unbounded loops remain in the contract; gas usage is predictable and user-driven.

---

## Usage Example

Open voting (only owner):
```
contract.openVoting({ value: 8000 });
```

Add participant and buy tokens:
```
contract.addParticipant({ value: 500 });
```

Create proposals:
```
contract.addProposal("Title", "Description", 2000, addressOfProposalContract);
```

Vote (stake):
```
contract.stake(2, proposalId); // Uses 4 tokens
```

Withdraw votes:
```
contract.withdrawFromProposal(1, proposalId); // Gets 1 token back
```

Execute signaling:
```
contract.executeSignaling(proposalId);
```
## Disclaimer
The original assignment statement is not included in this repository. However, this contract and its documentation are based on a real academic project focused on DAO governance and secure voting systems. The code is original, reviewed and tested.
---

## Authors
**Javier Jerez Reinoso**
**Pablo Chicharro Gómez**
Computer Science engineers

---
