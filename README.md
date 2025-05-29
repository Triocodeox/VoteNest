# 🗳️ VoteNest

**VoteNest** is a blockchain-based voting platform that enables **secure**, **transparent**, and **tamper-proof** voting for a wide range of use cases — from Decentralized Autonomous Organizations (DAOs) and online communities to corporate governance and governmental elections.

Built using **Clarity smart contracts** on the **Stacks blockchain**, VoteNest leverages blockchain immutability and decentralized logic to bring integrity and trust to the voting process.

---

## 🚀 Features

* ✅ **Decentralized Voting** — Run elections without centralized intermediaries.
* 🔒 **Tamper-Proof** — Immutable on-chain voting logic ensures results can't be altered.
* 👁️ **Transparent** — Anyone can audit votes and verify outcomes on the blockchain.
* 🧑‍🤝‍🧑 **Customizable Voter Eligibility** — Restrict or open voting as required.
* 🧱 **Modular Clarity Smart Contracts** — Clean, auditable, and reusable code structure.
* 🌍 **Multi-Use Case Ready** — DAOs, corporate boards, non-profits, or national voting systems.

---

## 📦 Tech Stack

| Component               | Description                                                              |
| ----------------------- | ------------------------------------------------------------------------ |
| Blockchain              | [Stacks](https://www.stacks.co/)                                         |
| Smart Contract Language | [Clarity](https://docs.stacks.co/write-smart-contracts/clarity-language) |
| Frontend (Optional)     | React / Next.js / Vue (optional integration)                             |
| Wallet Integration      | Stacks Wallet / Hiro Wallet                                              |
| Storage (optional)      | IPFS / Gaia (for off-chain metadata)                                     |

---

## 🛠️ How It Works

### 1. Deploying a Proposal

Anyone with the proper permissions (e.g., an admin) can create a proposal that includes:

* Title
* Description
* Voting options
* Start and end block height

### 2. Voting Mechanism

Eligible users vote by calling the `vote` function from their Stacks wallet. Votes are stored immutably on the blockchain.

### 3. Tallying Votes

After the voting period ends, the contract allows for vote counting and result publication.

---

## 📄 Smart Contract Overview (Clarity)

```clarity
(define-map proposals
  ((id uint)) ; Key
  ((title (string-ascii 100))
   (description (string-ascii 300))
   (creator principal)
   (start-block uint)
   (end-block uint)
   (options (list 10 (string-ascii 50)))))

(define-map votes
  ((proposal-id uint) (voter principal)) ; Composite Key
  ((choice (string-ascii 50))))

(define-data-var proposal-count uint u0)
```

### Key Functions

| Function          | Description                                           |
| ----------------- | ----------------------------------------------------- |
| `create-proposal` | Allows a user to deploy a new proposal                |
| `vote`            | Lets an eligible user vote on an active proposal      |
| `get-proposal`    | Retrieves proposal details                            |
| `get-results`     | Outputs the vote tally once the proposal is closed    |
| `has-voted`       | Checks if a principal has already voted in a proposal |

---

## 🧪 Getting Started

### Prerequisites

* Node.js (for frontend)
* Clarity CLI or [Clarinet](https://docs.hiro.so/clarinet/get-started)
* Stacks Wallet

### Clarity Contract Development

```bash
# Install Clarinet
npm install -g @hirosystems/clarinet

# Initialize a new Clarinet project
clarinet new votenest

# Navigate to the project directory
cd votenest

# Add your contract to `contracts/votenest.clar`

# Test and deploy
clarinet test
clarinet check
clarinet deploy
```

---

## ✅ Example Usage

```clarity
;; Create a proposal
(create-proposal u1 "DAO Election" "Choose new DAO lead" ['"Alice" '"Bob"] u100 u200)

;; Vote on a proposal
(vote u1 '"Alice')
```

---

## 📂 Directory Structure

```
votenest/
├── contracts/
│   └── votenest.clar
├── tests/
│   └── votenest_test.clar
├── frontend/ (optional)
│   ├── index.html
│   └── app.js
└── README.md
```

---

## 🔐 Security & Audit Considerations

* ✅ Prevent double voting using composite keys
* ✅ Prevent voting outside allowed block range
* ✅ Role-based access for proposal creation
* ✅ Future support for token-based voter eligibility (e.g., NFT, token weight)

---

## 📘 Documentation

* [Stacks Docs](https://docs.stacks.co/)
* [Clarity Language Reference](https://docs.stacks.co/write-smart-contracts/reference)

---

## 🧠 Future Enhancements

* Token-weighted voting
* Off-chain proposal storage (IPFS)
* zk-SNARKs for anonymous voting
* DAO integration
* Frontend DApp (React or Next.js)

---

## 🤝 Contributing

Contributions are welcome! Please fork the repo and submit a pull request.

---

## 📜 License

MIT License — feel free to use and modify for your organization, DAO, or project.

---

## 👤 Author

**VoteNest** by \[tricodeox]
Built with ❤️ on the Stacks blockchain
