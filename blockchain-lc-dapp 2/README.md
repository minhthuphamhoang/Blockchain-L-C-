# TradeTrust LC — Sepolia Testnet DApp

A deployable educational prototype showing how a blockchain can coordinate a Letter of Credit (L/C), document-hash registry, electronic Bill of Lading (eBL), payment authorisation and cargo release.

## What the lecturer can do

1. Open the hosted webpage.
2. Connect MetaMask on Sepolia.
3. Choose Importer, Exporter, Issuing Bank, Advising Bank, Carrier or Port Operator.
4. Claim that role in **demo mode**.
5. Submit transactions through role-specific forms.
6. Inspect the L/C, documents and eBL directly from the blockchain.
7. Open each transaction on Sepolia Etherscan.

Choosing a role in the webpage does **not** grant permission. The smart contract checks the connected MetaMask wallet.

## Project structure

```text
blockchain-lc-dapp/
├── contracts/
│   └── TradeFinanceLC.sol
├── docs/
│   ├── index.html
│   ├── styles.css
│   ├── app.js
│   └── contract-config.js
├── sample-files/
│   ├── commercial-invoice.txt
│   └── electronic-bill-of-lading.txt
├── DEMO-WALKTHROUGH.md
└── README.md
```

## 1. Deploy the contract using Remix

This is the simplest deployment method for a student submission.

1. Open Remix IDE.
2. Create `TradeFinanceLC.sol` and paste the file from `contracts/`.
3. Open **Solidity Compiler**.
4. Select compiler `0.8.24` or a compatible newer `0.8.x` compiler.
5. Enable the **optimizer** with `200` runs. The revised contract groups the large L/C and eBL inputs into calldata structs to avoid the original `Stack too deep` error. If Remix is still compiling an older cached version, replace the entire file; as a fallback, enable **viaIR** in the compiler advanced settings.
6. Compile `TradeFinanceLC.sol`.
7. In MetaMask, select the **Sepolia** test network and ensure the deployment wallet has a small amount of Sepolia ETH.
8. In Remix, open **Deploy & Run Transactions**.
9. Select **Injected Provider - MetaMask** as the environment.
10. Confirm the displayed network is Sepolia.
11. Deploy `TradeFinanceLC` and approve the MetaMask transaction.
12. Copy the deployed contract address from Remix or Sepolia Etherscan.

Never upload a MetaMask seed phrase or private key to GitHub.

## 2. Connect the webpage to the deployed contract

Open `docs/contract-config.js` and paste the contract address:

```js
window.TRADE_DAPP_CONFIG = {
  contractAddress: "0xYOUR_DEPLOYED_CONTRACT_ADDRESS",
  chainIdHex: "0xaa36a7",
  chainIdDecimal: 11155111,
  chainName: "Sepolia",
  explorerBaseUrl: "https://sepolia.etherscan.io"
};
```

## 3. Test the interface locally

Because the app uses JavaScript modules, do not double-click `index.html` using a `file://` URL. Start a small local web server.

From the project folder:

```bash
cd docs
python3 -m http.server 8000
```

Then open:

```text
http://localhost:8000
```

## 4. Publish with GitHub Pages

1. Create a GitHub repository.
2. Upload the complete project.
3. Open **Settings → Pages**.
4. Under **Build and deployment**, choose **Deploy from a branch**.
5. Select the `main` branch and `/docs` folder.
6. Save and wait for GitHub to display the public website address.

The public page contains no private key. MetaMask signs each transaction in the lecturer’s browser.

## Demo mode versus realistic mode

The contract starts with `demoMode = true`. This allows one Sepolia wallet to call `claimRole()` for multiple roles, making classroom testing practical.

For a realistic demonstration:

1. Use separate MetaMask test accounts for the importer, exporter, banks, carrier and port operator.
2. The deployment owner calls `grantRole(address, role)` for each participant.
3. The owner calls `setDemoMode(false)`.
4. Each participant connects using its assigned wallet.

Role numbers:

| Number | Role |
|---:|---|
| 1 | Importer |
| 2 | Exporter |
| 3 | Issuing Bank |
| 4 | Advising Bank |
| 5 | Carrier |
| 6 | Port Operator |

## On-chain and off-chain design

**On-chain:** party addresses, roles, L/C state, amount and currency reference, document hashes, review decisions, timestamps, eBL holder and cargo-release status.

**Off-chain:** full invoice, packing list, certificate, insurance document and eBL content. The interface calculates SHA-256 locally and submits only the hash plus a storage reference.

The prototype does not claim that a smart contract independently performs AML checks, sanctions screening, document interpretation, physical inspection, foreign-exchange settlement or legal dispute resolution. An authorised organisation performs those functions and records the result on-chain.

## Security and submission notes

- Use only fictional test data.
- Use only Sepolia test ETH.
- Never commit private keys or wallet seed phrases.
- Demo mode is intentionally less restrictive and must be labelled as an educational convenience.
- The eBL implementation represents transferable control but is not presented as a legally recognised production eBL system.
