# VoteNest - Decentralized Voting on Stacks  

VoteNest is a secure, transparent, and decentralized voting platform built on the **Stacks blockchain** using **Clarity smart contracts**. It enables trustless voting mechanisms for DAOs, governance, and community decision-making while ensuring immutability and verifiability.  

---

## 📌 Table of Contents  
1. [Project Overview](#-project-overview)  
2. [Key Features](#-key-features)  
3. [Smart Contracts](#-smart-contracts)  
4. [Folder Structure](#-folder-structure)  
5. [Prerequisites](#-prerequisites)  
6. [Installation](#-installation)  
7. [Usage](#-usage)  
8. [Testing](#-testing)  
9. [Deployment](#-deployment)  
10. [Configuration](#-configuration)  
11. [Contributing](#-contributing)  
12. [License](#-license)  

---

## 🌟 Project Overview  
VoteNest leverages the **Clarity** language and **Hiro’s Clarinet SDK** to provide:  
✅ **On-chain voting** – Immutable and auditable ballots.  
✅ **Permissionless participation** – No centralized authority.  
✅ **Gas-efficient execution** – Optimized for Stacks L2.  
✅ **Modular design** – Supports different voting mechanisms (e.g., token-weighted, quadratic).  

---

## 🔥 Key Features  
- **Proposal Creation**: Submit proposals with deadlines.  
- **Secure Voting**: Cast votes with cryptographic integrity.  
- **Results Aggregation**: On-chain tallying with transparency.  
- **Role-Based Access**: Admins, voters, and proposal creators.  
- **Multi-Network Support**: Devnet, Testnet, and Mainnet compatibility.  

---

## 📜 Smart Contracts  
| Contract | Description |  
|----------|-------------|  
| `voting-engine.clar` | Core logic for proposal/vote lifecycle. |  
| `token-weighted.clar` | Implements token-based voting power. |  
| `governance.clar` | DAO-style governance extensions. |  
| `utils.clar` | Helper functions (math, time locks, etc.). |  

---

## 📂 Folder Structure  
```bash
VoteNest/  
├── contracts/           # Clarity smart contracts  
├── tests/               # Vitest + Clarinet tests  
├── settings/            # Devnet/Testnet/Mainnet configs  
├── migrations/          # Deployment scripts  
├── clarinet.toml        # Clarinet project config  
├── package.json         # JS/TS dependencies  
└── README.md  
```

---

## ⚙️ Prerequisites  
- [Clarinet](https://github.com/hirosystems/clarinet) (v1.0.0+)  
- [Node.js](https://nodejs.org/) (v18+)  
- [Stacks CLI](https://docs.hiro.so/get-started/install) (for deployments)  

---

## 🛠 Installation  
1. Clone the repo:  
   ```bash
   git clone https://github.com/Triocodeox/VoteNest.git  
   cd VoteNest  
   ```
2. Install dependencies:  
   ```bash
   npm install  
   clarinet install  
   ```

---

## 🚀 Usage  
### Start Local Devnet  
```bash
clarinet console  
```

### Interact with Contracts  
Example: Create a proposal  
```clarity
(contract-call? .voting-engine create-proposal "Improve docs" 1000)  
```

---

## 🧪 Testing  
Tests use **Vitest + Clarinet environment**:  
```bash
npm test  
```  
Or run specific test suites:  
```bash
vitest tests/token-weighted.test.ts  
```

---

## 🌍 Deployment  
### To Stacks Testnet  
1. Configure `settings/Testnet.toml`.  
2. Deploy:  
   ```bash
   clarinet deployments apply -p testnet  
   ```

### To Mainnet  
```bash
clarinet deployments apply -p mainnet  
```

---

## ⚡️ Configuration  
### `clarinet.toml`  
```toml
[project]  
name = "votenest"  
requirements = []  

[contracts.voting-engine]  
path = "contracts/voting-engine.clar"  
```

### Network Settings  
Edit `settings/Devnet.toml` for local tuning.  

---

## 🤝 Contributing  
1. Fork the repo.  
2. Create a feature branch (`git checkout -b feature/xyz`).  
3. Submit a **Pull Request**.  

---

## 📜 License  
MIT License. See [LICENSE](LICENSE).  

---

**Built with ❤️ by [Triocodeox](https://github.com/Triocodeox) on Stacks.**  
