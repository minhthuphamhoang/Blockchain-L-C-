// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title TradeFinanceLC
 * @notice Educational testnet prototype for a blockchain-supported Letter of Credit
 *         and electronic Bill of Lading workflow.
 *
 * IMPORTANT:
 * - Commercial files remain off-chain. Only their SHA-256 hashes and storage
 *   references are recorded on-chain.
 * - Banks still perform AML, sanctions screening, document examination and
 *   professional discrepancy assessment off-chain.
 * - demoMode is provided only so a lecturer can test multiple roles using one
 *   Sepolia wallet. Disable it for a realistic multi-wallet demonstration.
 */
contract TradeFinanceLC {
    address public owner;
    bool public demoMode = true;

    enum Role {
        None,
        Importer,
        Exporter,
        IssuingBank,
        AdvisingBank,
        Carrier,
        PortOperator
    }

    enum LCStatus {
        None,
        Requested,
        Issued,
        Accepted,
        DocumentsSubmitted,
        UnderReview,
        Compliant,
        Discrepant,
        PaymentAuthorised,
        Paid,
        Rejected,
        Expired
    }

    enum DocumentType {
        CommercialInvoice,
        PackingList,
        CertificateOfOrigin,
        InsuranceCertificate,
        BillOfLading,
        InspectionCertificate,
        Other
    }

    struct LetterOfCredit {
        uint256 id;
        address importer;
        address exporter;
        address issuingBank;
        address advisingBank;
        address carrier;
        uint256 amount;
        string currency;
        string goodsDescription;
        uint256 expiryDate;
        LCStatus status;
        uint256 createdAt;
        bool exists;
    }

    struct LCRequestInput {
        address exporter;
        address issuingBank;
        address advisingBank;
        address carrier;
        uint256 amount;
        string currency;
        string goodsDescription;
        uint256 expiryDate;
    }

    struct TradeDocument {
        uint256 id;
        uint256 lcId;
        DocumentType documentType;
        bytes32 documentHash;
        string storageReference;
        address submittedBy;
        uint256 submittedAt;
        bool reviewed;
        bool verified;
        string reviewNote;
        bool exists;
    }

    struct ElectronicBillOfLading {
        uint256 id;
        uint256 lcId;
        address shipper;
        address carrier;
        address consignee;
        address currentHolder;
        bytes32 documentHash;
        string storageReference;
        string cargoDescription;
        string vessel;
        string portOfLoading;
        string portOfDischarge;
        uint256 issuedAt;
        bool releaseRequested;
        bool cargoReleased;
        bool exists;
    }

    struct EBLInput {
        bytes32 documentHash;
        string storageReference;
        string cargoDescription;
        string vessel;
        string portOfLoading;
        string portOfDischarge;
    }

    uint256 public nextLCId = 1;
    uint256 public nextDocumentId = 1;
    uint256 public nextEBLId = 1;

    mapping(address => mapping(Role => bool)) private participantRoles;
    mapping(uint256 => LetterOfCredit) private lettersOfCredit;
    mapping(uint256 => TradeDocument) private documents;
    mapping(uint256 => ElectronicBillOfLading) private ebls;
    mapping(uint256 => uint256[]) private lcDocumentIds;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event DemoModeChanged(bool enabled);
    event RoleGranted(address indexed account, Role indexed role, address indexed grantedBy);
    event RoleRevoked(address indexed account, Role indexed role, address indexed revokedBy);

    event LCRequested(uint256 indexed lcId, address indexed importer, address indexed exporter);
    event LCStatusChanged(uint256 indexed lcId, LCStatus previousStatus, LCStatus newStatus, address changedBy);
    event ComplianceDecision(uint256 indexed lcId, bool compliant, string note, address indexed decidedBy);

    event DocumentSubmitted(
        uint256 indexed documentId,
        uint256 indexed lcId,
        DocumentType documentType,
        bytes32 documentHash,
        address indexed submittedBy
    );
    event DocumentReviewed(
        uint256 indexed documentId,
        uint256 indexed lcId,
        bool verified,
        string note,
        address indexed reviewedBy
    );

    event EblIssued(uint256 indexed eblId, uint256 indexed lcId, address indexed carrier, address initialHolder);
    event EblTransferred(uint256 indexed eblId, address indexed previousHolder, address indexed newHolder);
    event CargoReleaseRequested(uint256 indexed eblId, address indexed holder);
    event CargoReleased(uint256 indexed eblId, address indexed releasedBy);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier onlyRole(Role role) {
        require(participantRoles[msg.sender][role], "Connected wallet does not have this role");
        _;
    }

    modifier validLC(uint256 lcId) {
        require(lettersOfCredit[lcId].exists, "Letter of Credit does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ---------------------------------------------------------------------
    // Administration and testnet role management
    // ---------------------------------------------------------------------

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function setDemoMode(bool enabled) external onlyOwner {
        demoMode = enabled;
        emit DemoModeChanged(enabled);
    }

    function claimRole(Role role) external {
        require(demoMode, "Demo role claiming is disabled");
        require(role != Role.None, "Invalid role");
        participantRoles[msg.sender][role] = true;
        emit RoleGranted(msg.sender, role, msg.sender);
    }

    function grantRole(address account, Role role) external onlyOwner {
        require(account != address(0), "Account cannot be zero address");
        require(role != Role.None, "Invalid role");
        participantRoles[account][role] = true;
        emit RoleGranted(account, role, msg.sender);
    }

    function revokeRole(address account, Role role) external onlyOwner {
        participantRoles[account][role] = false;
        emit RoleRevoked(account, role, msg.sender);
    }

    function hasRole(address account, Role role) external view returns (bool) {
        return participantRoles[account][role];
    }

    // ---------------------------------------------------------------------
    // Letter of Credit workflow
    // ---------------------------------------------------------------------

    function requestLC(
        LCRequestInput calldata input
    ) external onlyRole(Role.Importer) returns (uint256 lcId) {
        require(input.exporter != address(0), "Exporter address is required");
        require(input.issuingBank != address(0), "Issuing bank address is required");
        require(input.advisingBank != address(0), "Advising bank address is required");
        require(input.carrier != address(0), "Carrier address is required");
        require(input.amount > 0, "Amount must be greater than zero");
        require(bytes(input.currency).length > 0, "Currency is required");
        require(bytes(input.goodsDescription).length > 0, "Goods description is required");
        require(input.expiryDate > block.timestamp, "Expiry must be in the future");

        lcId = nextLCId++;
        LetterOfCredit storage lc = lettersOfCredit[lcId];
        lc.id = lcId;
        lc.importer = msg.sender;
        lc.exporter = input.exporter;
        lc.issuingBank = input.issuingBank;
        lc.advisingBank = input.advisingBank;
        lc.carrier = input.carrier;
        lc.amount = input.amount;
        lc.currency = input.currency;
        lc.goodsDescription = input.goodsDescription;
        lc.expiryDate = input.expiryDate;
        lc.status = LCStatus.Requested;
        lc.createdAt = block.timestamp;
        lc.exists = true;

        emit LCRequested(lcId, msg.sender, input.exporter);
    }

    function issueLC(uint256 lcId)
        external
        onlyRole(Role.IssuingBank)
        validLC(lcId)
    {
        LetterOfCredit storage lc = lettersOfCredit[lcId];
        require(msg.sender == lc.issuingBank, "Only the assigned issuing bank can issue this LC");
        require(lc.status == LCStatus.Requested, "LC is not awaiting issuance");
        _changeLCStatus(lc, LCStatus.Issued);
    }

    function acceptLC(uint256 lcId)
        external
        onlyRole(Role.Exporter)
        validLC(lcId)
    {
        LetterOfCredit storage lc = lettersOfCredit[lcId];
        require(msg.sender == lc.exporter, "Only the assigned exporter can accept this LC");
        require(lc.status == LCStatus.Issued, "LC has not been issued");
        require(block.timestamp <= lc.expiryDate, "LC has expired");
        _changeLCStatus(lc, LCStatus.Accepted);
    }

    function startDocumentReview(uint256 lcId) external validLC(lcId) {
        LetterOfCredit storage lc = lettersOfCredit[lcId];
        require(_isAssignedBank(lc, msg.sender), "Only an assigned bank can review documents");
        require(
            lc.status == LCStatus.DocumentsSubmitted || lc.status == LCStatus.Discrepant,
            "Documents are not ready for review"
        );
        _changeLCStatus(lc, LCStatus.UnderReview);
    }

    function completeDocumentReview(
        uint256 lcId,
        bool compliant,
        string calldata note
    ) external validLC(lcId) {
        LetterOfCredit storage lc = lettersOfCredit[lcId];
        require(_isAssignedBank(lc, msg.sender), "Only an assigned bank can complete review");
        require(lc.status == LCStatus.UnderReview, "LC is not under review");

        _changeLCStatus(lc, compliant ? LCStatus.Compliant : LCStatus.Discrepant);
        emit ComplianceDecision(lcId, compliant, note, msg.sender);
    }

    function authorisePayment(uint256 lcId)
        external
        onlyRole(Role.IssuingBank)
        validLC(lcId)
    {
        LetterOfCredit storage lc = lettersOfCredit[lcId];
        require(msg.sender == lc.issuingBank, "Only the assigned issuing bank can authorise payment");
        require(lc.status == LCStatus.Compliant, "Documents have not been marked compliant");
        _changeLCStatus(lc, LCStatus.PaymentAuthorised);
    }

    function markPaid(uint256 lcId)
        external
        onlyRole(Role.IssuingBank)
        validLC(lcId)
    {
        LetterOfCredit storage lc = lettersOfCredit[lcId];
        require(msg.sender == lc.issuingBank, "Only the assigned issuing bank can record payment");
        require(lc.status == LCStatus.PaymentAuthorised, "Payment is not authorised");
        _changeLCStatus(lc, LCStatus.Paid);
    }

    function rejectLC(uint256 lcId, string calldata note)
        external
        onlyRole(Role.IssuingBank)
        validLC(lcId)
    {
        LetterOfCredit storage lc = lettersOfCredit[lcId];
        require(msg.sender == lc.issuingBank, "Only the assigned issuing bank can reject this LC");
        require(lc.status != LCStatus.Paid, "A paid LC cannot be rejected");
        _changeLCStatus(lc, LCStatus.Rejected);
        emit ComplianceDecision(lcId, false, note, msg.sender);
    }

    function markExpired(uint256 lcId) external validLC(lcId) {
        LetterOfCredit storage lc = lettersOfCredit[lcId];
        require(block.timestamp > lc.expiryDate, "LC has not expired yet");
        require(
            lc.status != LCStatus.Paid &&
                lc.status != LCStatus.Rejected &&
                lc.status != LCStatus.Expired,
            "LC is already finalised"
        );
        _changeLCStatus(lc, LCStatus.Expired);
    }

    // ---------------------------------------------------------------------
    // Off-chain document hash registry
    // ---------------------------------------------------------------------

    function submitDocument(
        uint256 lcId,
        DocumentType documentType,
        bytes32 documentHash,
        string calldata storageReference
    ) external onlyRole(Role.Exporter) validLC(lcId) returns (uint256 documentId) {
        LetterOfCredit storage lc = lettersOfCredit[lcId];
        require(msg.sender == lc.exporter, "Only the assigned exporter can submit documents");
        require(block.timestamp <= lc.expiryDate, "LC has expired");
        require(
            lc.status == LCStatus.Accepted ||
                lc.status == LCStatus.DocumentsSubmitted ||
                lc.status == LCStatus.Discrepant,
            "LC is not accepting documents"
        );
        require(documentHash != bytes32(0), "Document hash is required");

        documentId = nextDocumentId++;
        documents[documentId] = TradeDocument({
            id: documentId,
            lcId: lcId,
            documentType: documentType,
            documentHash: documentHash,
            storageReference: storageReference,
            submittedBy: msg.sender,
            submittedAt: block.timestamp,
            reviewed: false,
            verified: false,
            reviewNote: "",
            exists: true
        });
        lcDocumentIds[lcId].push(documentId);

        if (lc.status != LCStatus.DocumentsSubmitted) {
            _changeLCStatus(lc, LCStatus.DocumentsSubmitted);
        }

        emit DocumentSubmitted(documentId, lcId, documentType, documentHash, msg.sender);
    }

    function reviewDocument(
        uint256 documentId,
        bool verified,
        string calldata note
    ) external {
        TradeDocument storage document = documents[documentId];
        require(document.exists, "Document does not exist");

        LetterOfCredit storage lc = lettersOfCredit[document.lcId];
        require(_isAssignedBank(lc, msg.sender), "Only an assigned bank can review this document");
        require(lc.status == LCStatus.UnderReview, "LC is not under review");

        document.reviewed = true;
        document.verified = verified;
        document.reviewNote = note;

        emit DocumentReviewed(documentId, document.lcId, verified, note, msg.sender);
    }

    // ---------------------------------------------------------------------
    // Electronic Bill of Lading workflow
    // ---------------------------------------------------------------------

    function issueEBL(
        uint256 lcId,
        EBLInput calldata input
    ) external onlyRole(Role.Carrier) validLC(lcId) returns (uint256 eblId) {
        LetterOfCredit storage lc = lettersOfCredit[lcId];
        require(msg.sender == lc.carrier, "Only the assigned carrier can issue the eBL");
        require(_canIssueEBL(lc.status), "LC is not active for eBL issuance");
        require(input.documentHash != bytes32(0), "eBL hash is required");

        eblId = nextEBLId++;
        ElectronicBillOfLading storage ebl = ebls[eblId];
        ebl.id = eblId;
        ebl.lcId = lcId;
        ebl.shipper = lc.exporter;
        ebl.carrier = msg.sender;
        ebl.consignee = lc.importer;
        ebl.currentHolder = lc.exporter;
        ebl.documentHash = input.documentHash;
        ebl.storageReference = input.storageReference;
        ebl.cargoDescription = input.cargoDescription;
        ebl.vessel = input.vessel;
        ebl.portOfLoading = input.portOfLoading;
        ebl.portOfDischarge = input.portOfDischarge;
        ebl.issuedAt = block.timestamp;
        ebl.exists = true;

        emit EblIssued(eblId, lcId, msg.sender, lc.exporter);
    }

    function transferEBL(uint256 eblId, address newHolder) external {
        ElectronicBillOfLading storage ebl = ebls[eblId];
        require(ebl.exists, "eBL does not exist");
        require(msg.sender == ebl.currentHolder, "Only the current holder can transfer the eBL");
        require(newHolder != address(0), "New holder cannot be zero address");
        require(!ebl.cargoReleased, "Cargo has already been released");

        address previousHolder = ebl.currentHolder;
        ebl.currentHolder = newHolder;
        ebl.releaseRequested = false;
        emit EblTransferred(eblId, previousHolder, newHolder);
    }

    function requestCargoRelease(uint256 eblId) external {
        ElectronicBillOfLading storage ebl = ebls[eblId];
        require(ebl.exists, "eBL does not exist");
        require(msg.sender == ebl.currentHolder, "Only the current holder can request release");
        require(msg.sender == ebl.consignee, "The importer must hold the eBL before release");
        require(!ebl.cargoReleased, "Cargo has already been released");

        ebl.releaseRequested = true;
        emit CargoReleaseRequested(eblId, msg.sender);
    }

    function releaseCargo(uint256 eblId) external {
        ElectronicBillOfLading storage ebl = ebls[eblId];
        require(ebl.exists, "eBL does not exist");
        bool assignedCarrier = participantRoles[msg.sender][Role.Carrier] && msg.sender == ebl.carrier;
        bool portOperator = participantRoles[msg.sender][Role.PortOperator];
        require(assignedCarrier || portOperator, "Only the carrier or a port operator can release cargo");
        require(ebl.releaseRequested, "Cargo release has not been requested");
        require(ebl.currentHolder == ebl.consignee, "Importer is not the current eBL holder");
        require(!ebl.cargoReleased, "Cargo has already been released");

        ebl.cargoReleased = true;
        emit CargoReleased(eblId, msg.sender);
    }

    // ---------------------------------------------------------------------
    // Read functions used by the HTML interface
    // ---------------------------------------------------------------------

    function getLCSummary(uint256 lcId)
        external
        view
        returns (
            uint256 id,
            uint256 amount,
            string memory currency,
            string memory goodsDescription,
            uint256 expiryDate,
            LCStatus status,
            uint256 createdAt,
            bool exists
        )
    {
        LetterOfCredit storage lc = lettersOfCredit[lcId];
        return (
            lc.id,
            lc.amount,
            lc.currency,
            lc.goodsDescription,
            lc.expiryDate,
            lc.status,
            lc.createdAt,
            lc.exists
        );
    }

    function getLCParties(uint256 lcId)
        external
        view
        returns (
            address importer,
            address exporter,
            address issuingBank,
            address advisingBank,
            address carrier
        )
    {
        LetterOfCredit storage lc = lettersOfCredit[lcId];
        return (lc.importer, lc.exporter, lc.issuingBank, lc.advisingBank, lc.carrier);
    }

    function getDocumentCore(uint256 documentId)
        external
        view
        returns (
            uint256 id,
            uint256 lcId,
            DocumentType documentType,
            bytes32 documentHash,
            string memory storageReference,
            address submittedBy,
            uint256 submittedAt,
            bool exists
        )
    {
        TradeDocument storage document = documents[documentId];
        return (
            document.id,
            document.lcId,
            document.documentType,
            document.documentHash,
            document.storageReference,
            document.submittedBy,
            document.submittedAt,
            document.exists
        );
    }

    function getDocumentReview(uint256 documentId)
        external
        view
        returns (
            bool reviewed,
            bool verified,
            string memory reviewNote
        )
    {
        TradeDocument storage document = documents[documentId];
        return (document.reviewed, document.verified, document.reviewNote);
    }

    function getEBLCore(uint256 eblId)
        external
        view
        returns (
            uint256 id,
            uint256 lcId,
            bytes32 documentHash,
            uint256 issuedAt,
            bool releaseRequested,
            bool cargoReleased,
            bool exists
        )
    {
        ElectronicBillOfLading storage ebl = ebls[eblId];
        return (
            ebl.id,
            ebl.lcId,
            ebl.documentHash,
            ebl.issuedAt,
            ebl.releaseRequested,
            ebl.cargoReleased,
            ebl.exists
        );
    }

    function getEBLParties(uint256 eblId)
        external
        view
        returns (
            address shipper,
            address carrier,
            address consignee,
            address currentHolder
        )
    {
        ElectronicBillOfLading storage ebl = ebls[eblId];
        return (ebl.shipper, ebl.carrier, ebl.consignee, ebl.currentHolder);
    }

    function getEBLDetails(uint256 eblId)
        external
        view
        returns (
            string memory storageReference,
            string memory cargoDescription,
            string memory vessel,
            string memory portOfLoading,
            string memory portOfDischarge
        )
    {
        ElectronicBillOfLading storage ebl = ebls[eblId];
        return (
            ebl.storageReference,
            ebl.cargoDescription,
            ebl.vessel,
            ebl.portOfLoading,
            ebl.portOfDischarge
        );
    }

    function getDocumentIds(uint256 lcId) external view returns (uint256[] memory) {
        return lcDocumentIds[lcId];
    }

    function _canIssueEBL(LCStatus status) internal pure returns (bool) {
        return
            status == LCStatus.Accepted ||
            status == LCStatus.DocumentsSubmitted ||
            status == LCStatus.UnderReview ||
            status == LCStatus.Compliant ||
            status == LCStatus.PaymentAuthorised ||
            status == LCStatus.Paid;
    }

    function _isAssignedBank(LetterOfCredit storage lc, address account) internal view returns (bool) {
        bool isIssuingBank = participantRoles[account][Role.IssuingBank] && account == lc.issuingBank;
        bool isAdvisingBank = participantRoles[account][Role.AdvisingBank] && account == lc.advisingBank;
        return isIssuingBank || isAdvisingBank;
    }

    function _changeLCStatus(LetterOfCredit storage lc, LCStatus newStatus) internal {
        LCStatus previousStatus = lc.status;
        lc.status = newStatus;
        emit LCStatusChanged(lc.id, previousStatus, newStatus, msg.sender);
    }
}
