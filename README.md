# 🪙 Quadratic Voting Smart Contract for DAOs

This repository contains a secure and gas-efficient `Solidity` smart contract that implements a **quadratic voting system for DAOs `(Decentralized Autonomous Organizations)`** using ERC20 tokens. The contract allows participants to register, propose initiatives, vote using quadratic weighting and execute approved proposals, everything **on-chain**.

> The complete design rationale and analysis are detailed in the project's technical report (Spanish only): `Technical-Report.pdf`.

## Structure
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

## Security Measures

| Vulnerability                | Mitigation                                                                 | Code Reference                                       |
|-----------------------------|----------------------------------------------------------------------------|------------------------------------------------------|
| **Overflow/Underflow**      | Solidity ^0.8.0 prevents them by default                                   | All arithmetic operations                            |
| **Unchecked Arithmetic**    | Used only where overflow is realistically impossible                       | `nProposals`, `nParticipants`, `withdrawFromProposal()` |
| **Reentrancy**              | Guarded using `lock` modifier                                              | `stake()`, `withdrawFromProposal()`, `executeSignaling()` |
| **DelegateCall Attack**     | No delegateCall used. Owner is set via constructor                         | Constructor                                          |
| **tx.origin misuse**        | Only uses `msg.sender` for access control                                  | All modifiers                                        |
| **Block Timestamp Abuse**   | Contract logic does not rely on block timestamps                           | -                                                    |
| **Denial of Service (DoS)** | Avoided using "pull over push" design in `closeVoting()`                   | `executeSignaling()`, memory design                  |

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

> Computer Science engineers

---
