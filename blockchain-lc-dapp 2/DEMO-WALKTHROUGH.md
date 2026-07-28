# Five-Minute Lecturer Demonstration

This walkthrough uses one Sepolia wallet for every role. It is a classroom convenience, not a production security model.

## Preparation

1. Open the hosted website.
2. Connect MetaMask on Sepolia.
3. For each role in the dropdown, click **Claim selected role**:
   - Importer
   - Exporter
   - Issuing Bank
   - Advising Bank
   - Carrier
   - Port Operator

## Transaction sequence

### 1. Importer requests the L/C

- Choose **Importer**.
- Click **Use connected wallet for all demo parties**.
- Keep amount `100000`, currency `USD`, and a future expiry.
- Click **Request L/C**.
- The first L/C ID is normally `1`.

### 2. Issuing bank issues it

- Choose **Issuing Bank**.
- Enter L/C ID `1`.
- Click **Issue L/C**.

### 3. Exporter accepts it

- Choose **Exporter**.
- Enter L/C ID `1`.
- Click **Accept L/C**.

### 4. Carrier issues the eBL

- Choose **Carrier**.
- Enter L/C ID `1`.
- Select `sample-files/electronic-bill-of-lading.txt`.
- Click **Hash file and issue eBL**.
- The first eBL ID is normally `1`.

### 5. Exporter submits documentary evidence

- Choose **Exporter**.
- Enter L/C ID `1`.
- Select Commercial Invoice.
- Select `sample-files/commercial-invoice.txt`.
- Click **Hash file and submit evidence**.
- The first document ID is normally `1`.

### 6. Bank reviews the documents

- Choose **Advising Bank**.
- Start review for L/C ID `1`.
- Review document ID `1` as Verified.
- Complete L/C review as Compliant.

### 7. Issuing bank authorises and records payment

- Choose **Issuing Bank**.
- Authorise payment for L/C ID `1`.
- Record payment completed for L/C ID `1`.

### 8. eBL transfer and cargo release

The eBL was issued to the exporter. In this one-wallet demo, importer and exporter use the same address, so transfer it to the connected wallet address.

- Under **eBL Holder Actions**, enter eBL ID `1` and the connected wallet address.
- Click **Transfer control of eBL**.
- Click **Request cargo release**.
- Choose **Carrier** or **Port Operator**.
- Enter eBL ID `1` and click **Confirm cargo released**.

## Evidence to capture

- Hosted webpage URL.
- Deployed contract address.
- Sepolia Etherscan contract page.
- L/C inspection showing `Paid`.
- Document inspection showing SHA-256 hash and verification result.
- eBL inspection showing the importer/current holder and `cargoReleased: true`.
- At least one MetaMask confirmation and transaction receipt.
