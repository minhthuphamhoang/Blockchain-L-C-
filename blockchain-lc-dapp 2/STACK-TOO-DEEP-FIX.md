# Stack-too-deep fix

The original `issueEBL` function had seven separate parameters, including five dynamic strings, and created a large storage struct in one expression. This could exceed the EVM compiler stack allocation during code generation.

The corrected version:

- adds `EBLInput` and `LCRequestInput` calldata structs;
- changes `issueEBL(uint256, EBLInput)` and `requestLC(LCRequestInput)`;
- writes storage fields individually rather than using large struct literals;
- moves the eBL status test into `_canIssueEBL`; and
- updates `docs/app.js` so ethers.js sends tuple arrays matching the new ABI.

After replacing the old files, compile with Solidity 0.8.24 and optimizer enabled. If Remix is still compiling cached old source, delete the old compiler artifact or replace the complete source file. `viaIR` may be enabled as a fallback.
