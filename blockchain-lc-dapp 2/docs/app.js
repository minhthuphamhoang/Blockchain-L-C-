import { ethers } from "https://cdn.jsdelivr.net/npm/ethers@6.17.0/+esm";

const CONFIG = window.TRADE_DAPP_CONFIG;
const ABI = [
  "function owner() view returns (address)",
  "function demoMode() view returns (bool)",
  "function claimRole(uint8 role)",
  "function hasRole(address account, uint8 role) view returns (bool)",
  "function requestLC((address exporter,address issuingBank,address advisingBank,address carrier,uint256 amount,string currency,string goodsDescription,uint256 expiryDate) input) returns (uint256)",
  "function issueLC(uint256 lcId)",
  "function acceptLC(uint256 lcId)",
  "function startDocumentReview(uint256 lcId)",
  "function completeDocumentReview(uint256 lcId,bool compliant,string note)",
  "function authorisePayment(uint256 lcId)",
  "function markPaid(uint256 lcId)",
  "function submitDocument(uint256 lcId,uint8 documentType,bytes32 documentHash,string storageReference) returns (uint256)",
  "function reviewDocument(uint256 documentId,bool verified,string note)",
  "function issueEBL(uint256 lcId,(bytes32 documentHash,string storageReference,string cargoDescription,string vessel,string portOfLoading,string portOfDischarge) input) returns (uint256)",
  "function transferEBL(uint256 eblId,address newHolder)",
  "function requestCargoRelease(uint256 eblId)",
  "function releaseCargo(uint256 eblId)",
  "function getLCSummary(uint256 lcId) view returns (uint256 id,uint256 amount,string currency,string goodsDescription,uint256 expiryDate,uint8 status,uint256 createdAt,bool exists)",
  "function getLCParties(uint256 lcId) view returns (address importer,address exporter,address issuingBank,address advisingBank,address carrier)",
  "function getDocumentCore(uint256 documentId) view returns (uint256 id,uint256 lcId,uint8 documentType,bytes32 documentHash,string storageReference,address submittedBy,uint256 submittedAt,bool exists)",
  "function getDocumentReview(uint256 documentId) view returns (bool reviewed,bool verified,string reviewNote)",
  "function getEBLCore(uint256 eblId) view returns (uint256 id,uint256 lcId,bytes32 documentHash,uint256 issuedAt,bool releaseRequested,bool cargoReleased,bool exists)",
  "function getEBLParties(uint256 eblId) view returns (address shipper,address carrier,address consignee,address currentHolder)",
  "function getEBLDetails(uint256 eblId) view returns (string storageReference,string cargoDescription,string vessel,string portOfLoading,string portOfDischarge)"
];

const ROLE_NAMES = ["None", "Importer", "Exporter", "Issuing Bank", "Advising Bank", "Carrier", "Port Operator"];
const LC_STATUS_NAMES = ["None", "Requested", "Issued", "Accepted", "Documents Submitted", "Under Review", "Compliant", "Discrepant", "Payment Authorised", "Paid", "Rejected", "Expired"];
const DOCUMENT_TYPE_NAMES = ["Commercial Invoice", "Packing List", "Certificate of Origin", "Insurance Certificate", "Bill of Lading", "Inspection Certificate", "Other"];

let provider;
let signer;
let contract;
let account = "";

const $ = (id) => document.getElementById(id);

function shortenAddress(address) {
  return address ? `${address.slice(0, 6)}…${address.slice(-4)}` : "Not connected";
}

function timestampToText(value) {
  const number = Number(value);
  return number ? new Date(number * 1000).toLocaleString() : "—";
}

function log(message, type = "info", txHash = "") {
  const item = document.createElement("p");
  item.className = `log-entry ${type === "error" ? "log-error" : type === "success" ? "log-success" : ""}`;
  const time = new Date().toLocaleTimeString();
  item.innerHTML = `<strong>${time}</strong> — ${escapeHtml(message)}`;
  if (txHash) {
    const link = document.createElement("a");
    link.href = `${CONFIG.explorerBaseUrl}/tx/${txHash}`;
    link.target = "_blank";
    link.rel = "noopener noreferrer";
    link.textContent = " View transaction";
    item.appendChild(link);
  }
  $("activityLog").prepend(item);
}

function escapeHtml(value) {
  return String(value).replace(/[&<>'"]/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;"
  }[character]));
}

function requireConnected() {
  if (!contract || !account) throw new Error("Connect MetaMask first.");
}

function validateConfig() {
  if (!CONFIG?.contractAddress || !ethers.isAddress(CONFIG.contractAddress)) {
    $("contractStatus").textContent = "Paste address in contract-config.js";
    return false;
  }
  $("contractStatus").textContent = shortenAddress(CONFIG.contractAddress);
  return true;
}

async function switchToSepolia() {
  const currentChainId = await window.ethereum.request({ method: "eth_chainId" });
  if (currentChainId.toLowerCase() === CONFIG.chainIdHex.toLowerCase()) return;
  await window.ethereum.request({
    method: "wallet_switchEthereumChain",
    params: [{ chainId: CONFIG.chainIdHex }]
  });
}

async function connectWallet() {
  try {
    if (!window.ethereum) throw new Error("MetaMask is not installed in this browser.");
    if (!validateConfig()) throw new Error("Deploy the contract and paste its address into contract-config.js first.");

    await switchToSepolia();
    provider = new ethers.BrowserProvider(window.ethereum);
    await provider.send("eth_requestAccounts", []);
    signer = await provider.getSigner();
    account = await signer.getAddress();
    contract = new ethers.Contract(CONFIG.contractAddress, ABI, signer);

    $("walletStatus").textContent = shortenAddress(account);
    $("walletStatus").title = account;
    $("networkStatus").textContent = CONFIG.chainName;
    $("connectButton").textContent = "Wallet connected";

    const demoMode = await contract.demoMode();
    $("demoModeStatus").textContent = demoMode ? "Enabled" : "Disabled";
    $("demoModeStatus").style.color = demoMode ? "#087f5b" : "#a35b00";

    await updateRoleDashboard();
    log(`Connected ${account} on ${CONFIG.chainName}.`, "success");
  } catch (error) {
    handleError(error);
  }
}

async function updateRoleDashboard() {
  const role = Number($("roleSelect").value);
  document.querySelectorAll(".role-section").forEach((section) => {
    const permittedRoles = section.dataset.role.split(",").map(Number);
    section.classList.toggle("visible", permittedRoles.includes(role));
  });

  if (!contract || !account) {
    $("rolePermission").textContent = "Connect wallet to check";
    $("rolePermission").className = "pill warning";
    return;
  }

  const permitted = await contract.hasRole(account, role);
  $("rolePermission").textContent = permitted ? `${ROLE_NAMES[role]} role active` : `${ROLE_NAMES[role]} role not assigned`;
  $("rolePermission").className = permitted ? "pill success" : "pill warning";
}

async function claimSelectedRole() {
  try {
    requireConnected();
    const role = Number($("roleSelect").value);
    await sendTransaction(() => contract.claimRole(role), `Claim ${ROLE_NAMES[role]} role`);
    await updateRoleDashboard();
  } catch (error) {
    handleError(error);
  }
}

async function sendTransaction(createTransaction, description) {
  requireConnected();
  log(`${description}: waiting for MetaMask approval…`);
  const transaction = await createTransaction();
  log(`${description}: submitted.`, "info", transaction.hash);
  const receipt = await transaction.wait();
  log(`${description}: confirmed in block ${receipt.blockNumber}.`, "success", transaction.hash);
  return receipt;
}

async function sha256File(file) {
  if (!file) throw new Error("Choose a file first.");
  const bytes = await file.arrayBuffer();
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return `0x${Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, "0")).join("")}`;
}

function requireAddress(value, label) {
  if (!ethers.isAddress(value)) throw new Error(`${label} is not a valid Ethereum address.`);
  return value;
}

async function requestLC(event) {
  event.preventDefault();
  try {
    requireConnected();
    const expiry = Math.floor(new Date($("expiryDate").value).getTime() / 1000);
    if (!expiry || expiry <= Math.floor(Date.now() / 1000)) throw new Error("Choose a future expiry date.");

    await sendTransaction(
      () => contract.requestLC([
        requireAddress($("exporterAddress").value.trim(), "Exporter wallet"),
        requireAddress($("issuingBankAddress").value.trim(), "Issuing bank wallet"),
        requireAddress($("advisingBankAddress").value.trim(), "Advising bank wallet"),
        requireAddress($("carrierAddress").value.trim(), "Carrier wallet"),
        BigInt($("lcAmount").value),
        $("lcCurrency").value.trim(),
        $("goodsDescription").value.trim(),
        expiry
      ]),
      "Request Letter of Credit"
    );
  } catch (error) { handleError(error); }
}

async function submitDocument(event) {
  event.preventDefault();
  try {
    requireConnected();
    const file = $("documentFile").files[0];
    log(`Calculating SHA-256 for ${file?.name || "document"}…`);
    const hash = await sha256File(file);
    const storageReference = $("documentStorageReference").value.trim() || `offchain-file://${file.name}`;
    await sendTransaction(
      () => contract.submitDocument(
        BigInt($("documentLcId").value),
        Number($("documentType").value),
        hash,
        storageReference
      ),
      `Submit ${DOCUMENT_TYPE_NAMES[Number($("documentType").value)]} hash ${hash.slice(0, 12)}…`
    );
  } catch (error) { handleError(error); }
}

async function reviewDocument(event) {
  event.preventDefault();
  try {
    await sendTransaction(
      () => contract.reviewDocument(
        BigInt($("reviewDocumentId").value),
        $("documentVerified").value === "true",
        $("documentReviewNote").value.trim()
      ),
      "Record individual document review"
    );
  } catch (error) { handleError(error); }
}

async function completeReview(event) {
  event.preventDefault();
  try {
    await sendTransaction(
      () => contract.completeDocumentReview(
        BigInt($("completeReviewLcId").value),
        $("lcCompliant").value === "true",
        $("complianceNote").value.trim()
      ),
      "Complete documentary compliance review"
    );
  } catch (error) { handleError(error); }
}

async function issueEbl(event) {
  event.preventDefault();
  try {
    requireConnected();
    const file = $("eblFile").files[0];
    log(`Calculating SHA-256 for ${file?.name || "eBL"}…`);
    const hash = await sha256File(file);
    const storageReference = $("eblStorageReference").value.trim() || `offchain-file://${file.name}`;
    await sendTransaction(
      () => contract.issueEBL(
        BigInt($("eblLcId").value),
        [
          hash,
          storageReference,
          $("eblCargoDescription").value.trim(),
          $("vessel").value.trim(),
          $("portLoading").value.trim(),
          $("portDischarge").value.trim()
        ]
      ),
      `Issue eBL with hash ${hash.slice(0, 12)}…`
    );
  } catch (error) { handleError(error); }
}

async function transferEbl(event) {
  event.preventDefault();
  try {
    await sendTransaction(
      () => contract.transferEBL(
        BigInt($("transferEblId").value),
        requireAddress($("newHolderAddress").value.trim(), "New holder wallet")
      ),
      "Transfer eBL control"
    );
  } catch (error) { handleError(error); }
}

async function genericContractAction(event) {
  event.preventDefault();
  try {
    requireConnected();
    const form = event.currentTarget;
    const action = form.dataset.contractAction;
    const formData = new FormData(form);
    const rawId = formData.get("lcId") || formData.get("eblId");
    if (!rawId) throw new Error("Enter an ID.");
    const labels = {
      issueLC: "Issue Letter of Credit",
      acceptLC: "Accept Letter of Credit",
      startDocumentReview: "Start document review",
      authorisePayment: "Authorise payment",
      markPaid: "Record payment",
      requestCargoRelease: "Request cargo release",
      releaseCargo: "Release cargo"
    };
    await sendTransaction(() => contract[action](BigInt(rawId)), labels[action] || action);
  } catch (error) { handleError(error); }
}

async function loadLC(event) {
  event.preventDefault();
  try {
    requireConnected();
    const id = BigInt($("loadLcId").value);
    const [summary, parties] = await Promise.all([contract.getLCSummary(id), contract.getLCParties(id)]);
    if (!summary.exists) throw new Error("L/C does not exist.");
    $("lcOutput").textContent = JSON.stringify({
      id: summary.id.toString(), amount: summary.amount.toString(), currency: summary.currency,
      goodsDescription: summary.goodsDescription, expiryDate: timestampToText(summary.expiryDate),
      status: LC_STATUS_NAMES[Number(summary.status)], createdAt: timestampToText(summary.createdAt),
      importer: parties.importer, exporter: parties.exporter, issuingBank: parties.issuingBank,
      advisingBank: parties.advisingBank, carrier: parties.carrier
    }, null, 2);
  } catch (error) { handleError(error); }
}

async function loadDocument(event) {
  event.preventDefault();
  try {
    requireConnected();
    const id = BigInt($("loadDocumentId").value);
    const [core, review] = await Promise.all([contract.getDocumentCore(id), contract.getDocumentReview(id)]);
    if (!core.exists) throw new Error("Document does not exist.");
    $("documentOutput").textContent = JSON.stringify({
      id: core.id.toString(), lcId: core.lcId.toString(), documentType: DOCUMENT_TYPE_NAMES[Number(core.documentType)],
      documentHash: core.documentHash, storageReference: core.storageReference, submittedBy: core.submittedBy,
      submittedAt: timestampToText(core.submittedAt), reviewed: review.reviewed, verified: review.verified,
      reviewNote: review.reviewNote
    }, null, 2);
  } catch (error) { handleError(error); }
}

async function loadEbl(event) {
  event.preventDefault();
  try {
    requireConnected();
    const id = BigInt($("loadEblId").value);
    const [core, parties, details] = await Promise.all([
      contract.getEBLCore(id), contract.getEBLParties(id), contract.getEBLDetails(id)
    ]);
    if (!core.exists) throw new Error("eBL does not exist.");
    $("eblOutput").textContent = JSON.stringify({
      id: core.id.toString(), lcId: core.lcId.toString(), shipper: parties.shipper, carrier: parties.carrier,
      consignee: parties.consignee, currentHolder: parties.currentHolder, documentHash: core.documentHash,
      storageReference: details.storageReference, cargoDescription: details.cargoDescription, vessel: details.vessel,
      portOfLoading: details.portOfLoading, portOfDischarge: details.portOfDischarge,
      issuedAt: timestampToText(core.issuedAt), releaseRequested: core.releaseRequested, cargoReleased: core.cargoReleased
    }, null, 2);
  } catch (error) { handleError(error); }
}

function handleError(error) {
  console.error(error);
  const message = error?.shortMessage || error?.reason || error?.info?.error?.message || error?.message || "Unknown error";
  log(message.replace("execution reverted: ", ""), "error");
}

function fillMyAddress() {
  if (!account) return handleError(new Error("Connect MetaMask first."));
  ["exporterAddress", "issuingBankAddress", "advisingBankAddress", "carrierAddress", "newHolderAddress"].forEach((id) => {
    $(id).value = account;
  });
}

function setDefaultExpiry() {
  const date = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  $("expiryDate").value = local;
}

$("connectButton").addEventListener("click", connectWallet);
$("roleSelect").addEventListener("change", updateRoleDashboard);
$("claimRoleButton").addEventListener("click", claimSelectedRole);
$("fillMyAddressButton").addEventListener("click", fillMyAddress);
$("requestLCForm").addEventListener("submit", requestLC);
$("submitDocumentForm").addEventListener("submit", submitDocument);
$("reviewDocumentForm").addEventListener("submit", reviewDocument);
$("completeReviewForm").addEventListener("submit", completeReview);
$("issueEblForm").addEventListener("submit", issueEbl);
$("transferEblForm").addEventListener("submit", transferEbl);
$("loadLcForm").addEventListener("submit", loadLC);
$("loadDocumentForm").addEventListener("submit", loadDocument);
$("loadEblForm").addEventListener("submit", loadEbl);
document.querySelectorAll(".action-form").forEach((form) => form.addEventListener("submit", genericContractAction));
$("clearLogButton").addEventListener("click", () => { $("activityLog").innerHTML = ""; });

if (window.ethereum) {
  window.ethereum.on("accountsChanged", () => window.location.reload());
  window.ethereum.on("chainChanged", () => window.location.reload());
}

setDefaultExpiry();
validateConfig();
updateRoleDashboard();
