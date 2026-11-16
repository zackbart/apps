# Local validation

Validated on November 15–16, 2026, on the Mac mini with Xcode 27.2 (27B52). Source was the uncommitted `deadbolt-ios` working tree above workspace baseline `278c9ef756aae9bb6b5acee0bfd98fb5e53002a8`, using the pinned upstream Deadbolt revision `11a56948b453823c9c9c3de1161254df2c00b105`, recorded in `RustBridge/PROVENANCE.md`.

The app and credential provider require iOS 18 or newer. Version **1.0 (1)** was uploaded to private Cursor Kittens TestFlight on November 16, 2026; Apple reports `VALID` and `IN_BETA_TESTING`.

## Results

| Check | Result |
| --- | --- |
| Simulator build, app and credential extension with real Rust static library | Passed |
| Device arm64 compilation with signing disabled | Passed |
| Swift XCTest | Latest suite: 28 passed, 0 failed, 0 skipped |
| Native Rust tests | Latest suite: 11 passed; includes actual SPAKE2/QUIC pairing, offline recovery, revocation, atomic import, and passkey signature verification |
| Create vault through visible onboarding | Passed |
| Reject wrong master password, unlock, lock, reopen persisted records | Passed |
| Create, edit, and delete password records | Passed |
| Secure password generator screen | Passed |
| Device unlock enrollment and token unlock in simulator | Passed; hardware biometry remains unverified |
| System AutoFill settings lists and enables Deadbolt | Passed |
| Safari password AutoFill through the installed extension | Passed; local form verified the exact filled username and password |
| Safari native passkey registration | Passed |
| Safari native passkey assertion | Passed; browser harness verified the P-256 signature, RP hash, user verification, and client data |
| Safari native duplicate passkey exclusion | Passed; matched excluded credential returned the proper system error |
| iOS simulator ↔ native macOS Rust bridge peer | Passed; real production Iroh configuration, five-word pairing, initial vault transfer, later Mac-to-iOS update, and iOS edit observed back on Mac |
| Fresh-device interrupted join: cancel, unlock, and generate a new pairing code | Passed |
| TOTP record from live sync | Passed; code and countdown visible |
| CSV download → Files picker → preview → confirmed encrypted import | Passed; imported login, quoted comma note, and TOTP displayed |
| Signed device archive / installable IPA | Passed; distribution export for Cursor Kittens team F2J8ZU2NQJ |
| Private TestFlight delivery | Passed; 1.0 (1), VALID, IN_BETA_TESTING; Zack invited to Internal Testing |

The local browser fixture was served from `http://localhost:8765/deadbolt-system-test.html`, backed by `/Users/zackbart/Documents/scratch/Dev/apps/apps/deadbolt-system-test.html`. It made no external account. The temporary local server and host peer were stopped after use.

## Additional polish and reliability pass, November 16

The follow-up review fixed explicit vault targeting, stale-editor overwrites and deleted-item resurrection, atomic import and duplicate retries, cancellation during unlock and queued mutations, and sync scheduling races. Sync now runs independently of local editing, has bounded network waits, supports cancellation, and reports partial failure honestly. CSV parsing preserves quoted CRLF and Unicode secrets; TOTP tests cover SHA-1, SHA-256, SHA-512, malformed Base32 and invalid timestamps.

The app now has recoverable zero-vault setup, vault filters and disambiguated same-name vaults, draft-discard and password-replacement confirmation, generated-password undo, and clearer validation. AutoFill has searchable password/passkey selection and explicit passkey destinations. Screenshot review also corrected primary-button contrast and touch targets. A real pairing transfer exposed a sheet that kept showing “Waiting”; moving polling into the tracked pairing task and distinguishing the finishing state resolved the observed flow. The precise cause of the original SwiftUI task failure was not proven.

Latest Swift XCTest result:

`/Users/zackbart/.runbp/projects/4dc42eb8a4a65669806a/development/runs/20261116T132745Z-check-50875-2ee49d/result.json`

All 28 tests passed. This run includes the Shared and AutoFill logic changes. Subsequent app-only pairing/status/contrast changes and the final provider button-font adjustment were compiled and exercised in the simulator; they did not change the tested engine/session logic. Native Rust results are recorded in `docs/evidence/rust-tests.txt`; the last additional custom-field snapshot regression also passed.

Broad simulator session:

`/Users/zackbart/.runbp/projects/4dc42eb8a4a65669806a/sessions/runbp-deadbolt-ios-b7cd390c-07e6-44a4-926c-3caa7ca367d2`

Its seven required outcomes and all 23 latest recorded outcomes passed. It used the same single medium simulator as the earlier runs. Verified behaviors included:

- Cancel first-time pairing, unlock the resulting device, and create a vault through “Finish setting up.”
- Pair two real host vaults both named `shared`; distinguish their short IDs and finish pairing automatically.
- Change a shared record on the Mac while its iPhone editor holds a draft. Save rejects the stale version; Keep editing preserves the draft, and Load latest displays the remote change.
- Save a legitimate iPhone edit and observe it on the Mac with the remote note intact. A separate `Personal only` record remains absent from the Mac.
- Lock the host peer, cancel a sync, save locally while offline, and see the partial-failure message. Unlock the host and receive the offline change through real Iroh sync.
- Confirm generated-password replacement and Undo, reject an invalid website, and save to an explicit private vault.
- Download a CSV, import through Files into `personal`, repeat the import, and see one exact duplicate skipped. The imported TOTP code and countdown are visible.
- Enable the real system provider, search for a shared login, and have the browser verify the exact filled credentials.
- Register a native passkey into the explicitly selected private vault, choose it from the mixed password/passkey picker, verify its signature in the browser, and reject duplicate registration.
- Inspect the largest accessibility text in unlock, vault, generator, editor and provider screens. Restore normal text size. Cancel a later pairing attempt and retain the existing private record.

The broad session is **not an all-green automation ledger**. Its summary retains failed/intermediate commands, and `runbp evidence check` reports two screenshot metadata errors at sequences 161 and 165: the native system sheet caused an `invalid-viewport` accessibility capture error. Actual PNGs were saved and inspected, and later independent pixel assertions verified password fill, passkey registration/signature, and exclusion. An extra passkey assertion attempt at maximum text size timed out during system-sheet/driver navigation in this session; it is not counted as a passed ceremony. No evidence files were edited to remove failures.

Useful captures within the broad session:

| File | Evidence |
| --- | --- |
| `runbp-1794836282152.png` | Vault list with same-name vault disambiguation |
| `runbp-1794836367415.png` | Stale-edit rejection with draft preserved |
| `runbp-1794836984787.png` | Honest offline/partial-sync failure |
| `runbp-1794837528272.png` | Explicit native passkey vault destination |
| `runbp-1794837616893.png` | Mixed password/passkey provider with vault labels |
| `runbp-1794837810361.png` | Largest accessibility text in the vault |
| `runbp-1794837848184.png` | Large-text generator and corrected button contrast |

The final unsigned device compile also passed through `scripts/run.sh build --check --device --json`, with `CODE_SIGNING_ALLOWED=NO`. Signing was blocked at that point; the later private TestFlight release below resolved it. No worktrees were created. The temporary 5.4 GB Rust target cache was removed after native integration passed; current simulator/device archives and the small host helper were retained for reproducible incremental builds.

### Final accessibility follow-up

Independent screenshot review found that the provider explanation scaled with Dynamic Type but its four button labels did not. All four now use the preferred body font, respond to content-size changes, wrap and center their titles, and retain at least 44-point touch targets.

Focused final session:

`/Users/zackbart/.runbp/projects/4dc42eb8a4a65669806a/sessions/runbp-deadbolt-ios-44623d75-1833-4469-92ab-f5623ca00ec3`

All 40 commands, verifications and the required `provider.scaled-reachable` outcome passed. `runbp evidence check` passed with no errors. A real passkey assertion completed at the largest accessibility text size; the browser verified its signature, independently observed in `artifacts/0036/screenshot.png` and `ui.json`. This later successful ceremony resolves the earlier maximum-text attempt's incomplete validation, while preserving that historical timeout in the broad session ledger.

- `runbp-1794840107249.png`: normal provider typography.
- `runbp-1794840227841.png`: largest-text Cancel and Unlock buttons, fully readable.
- `runbp-1794840252735.png`: unlocked provider header at largest text.
- `runbp-1794840267573.png`: scrolled credential selection at largest text.

Normal text settings were restored and the same simulator shut down. The device build passed again after this final font-only change (4.8 seconds, signing disabled). The host peer was locked and stopped, the loopback fixture server stopped, and the temporary host vault removed. Final `runbp status` reports no active session. Approximately 104 GB remains free; shared runner-managed caches belonging to other work were left alone. No worktrees remain from this task.

## Evidence

All UI interaction used runbp. Only one stocked simulator was used at a time, always the same medium simulator, UDID `B5C6C7B0-E386-48DB-8829-84E554F493E2`, iOS 27.2. The first session was shut down before the resumed second session; XCTest then took and closed its own session on that same simulator. A final focused interrupted-join regression then used fresh state on that same simulator and was also shut down. No worktrees were created.

First UI session:

`/Users/zackbart/.runbp/projects/4dc42eb8a4a65669806a/sessions/runbp-deadbolt-ios-d32f7dcc-59fb-4abe-b785-9a20ee4898da`

Its six required outcomes passed, with eleven additional observed outcomes. Initial testing exposed and corrected empty-field save validation and keyboard focus issues. Some early UI commands failed because native sheets were absent from accessibility capture or reported incorrect coordinates; screenshots guided recovery. `runbp evidence check` passed with no ledger problems. Failed commands remain in the ledger; the outcome verdict is passed.

Useful captures in that directory:

- `runbp-1794799225637.png`: onboarding.
- `runbp-1794799715806.png`: populated vault.
- `runbp-1794799727125.png`: credential detail.
- `runbp-1794799774928.png`: settings.
- `runbp-1794799949725.png`: devices.
- `runbp-1794800343068.png`: browser verified passkey signature.
- `runbp-1794800523603.png`: live Mac peer records in the iOS vault.
- `runbp-1794800597864.png`: TOTP code and countdown.

Final UI session, including the updated dark credential provider, exclusion handling, and Files import:

`/Users/zackbart/.runbp/projects/4dc42eb8a4a65669806a/sessions/runbp-deadbolt-ios-af2c8548-f7db-4bd4-b79a-6e1be0064176`

All five required outcomes and all commands/verifications passed. `runbp evidence check` passed with no problems. `runbp-1794800897931.png` shows the final provider; `runbp-1794801055844.png` shows the imported record, TOTP, and comma-containing note.

Swift XCTest result and `.xcresult`:

`/Users/zackbart/.runbp/projects/4dc42eb8a4a65669806a/development/runs/20261116T035129Z-check-68610-1708a4/`

The result reports six tests passed and session cleanup exit 0. Unit tests cover exact-host matching and hostile host inputs, RFC 6238 vectors, malformed TOTP inputs, quoted CSV fields, malformed CSV, and import variants.

Unsigned device compilation log:

`/Users/zackbart/.runbp/projects/4dc42eb8a4a65669806a/xcodebuild-check.log`

Signed archive log (overwritten by the later successful release build):

`/Users/zackbart/.runbp/projects/4dc42eb8a4a65669806a/xcodebuild-archive.log`

Focused interrupted-join regression:

`/Users/zackbart/.runbp/projects/4dc42eb8a4a65669806a/sessions/runbp-deadbolt-ios-dc7c7208-81a5-4742-91b5-baddc7e80885`

Started from fresh state through “Join an existing vault,” chose a local master password, generated a code, and dismissed before approval. The root correctly offered “Unlock vault.” That password reopened the existing device; Devices → Join another vault generated a different code without an initialization error. Dismissed the second attempt and explicitly locked. All five required outcomes passed, and `runbp evidence check` passed with no ledger problems. One dismissal snapshot reported a busy UI runner; a fresh read confirmed successful dismissal before continuing. The initial attempt to reuse the previous build was refused because its source fingerprint changed; runbp cleaned that attempt, and the required incremental build passed. No full test suite was repeated.

## Private TestFlight release, November 16

The earlier Xcode authentication and Developer Program agreement blockers were resolved after the user authenticated and accepted the agreement. The user created the App Store Connect record and authorized TestFlight distribution.

| Release field | Verified value |
| --- | --- |
| Team | Cursor Kittens LLC, `F2J8ZU2NQJ` |
| App | Deadbolt iOS, `6835505284` |
| App / provider bundle IDs | `com.cursorkittens.deadbolt` / `com.cursorkittens.deadbolt.autofill` |
| Version / build | `1.0` / `1` |
| ASC build ID | `e87d141d-7aa9-4d61-848c-088e5896888f` |
| Processing / internal state | `VALID` / `IN_BETA_TESTING` |
| Internal group | `Internal Testing`, `b2142106-60cf-4908-9f41-1d33ba4a9737` |
| Tester | the configured internal tester, `INVITED` |
| IPA | `build/testflight-cursorkittens/Deadbolt.ipa` |
| Archive | `build/testflight-cursorkittens/Deadbolt.xcarchive` |

The exported IPA's app and provider both contain team `F2J8ZU2NQJ`, their matching application identifiers, AutoFill entitlement, shared `group.dev.zackbart.deadbolt` App Group and `F2J8ZU2NQJ.dev.zackbart.deadbolt.shared` Keychain group, with `get-task-allow=false`. Storage identifiers were retained from the tested implementation. No physical installation or hardware authentication is implied by Apple's processing result. The earlier UI and XCTest runs used the former `dev.zackbart.deadbolt` bundle ID; the release identifier change was validated by a fresh signed archive/export and inspection of both exported targets.

ASC authentication follows Eater's existing configuration, independently of Xcode signing. `sh scripts/asc.sh` forces profile `cursor-kittens`, bypasses Keychain, and uses the existing local config at `~/Dev/apps/read-the-bible/.asc/config.json` unless `ASC_CONFIG_PATH` is explicitly supplied. It contains no embedded credentials. Verify the target app and team before every upload; other Apple teams are present.

```sh
sh scripts/asc.sh apps view --id 6835505284
sh scripts/asc.sh bundle-ids list --identifier com.cursorkittens.deadbolt --output table
xcodegen generate
scripts/run.sh build --archive --build-number 2 --export-options Configuration/TestFlightExportOptions.plist --out build/testflight-next --json
sh scripts/asc.sh publish testflight --app 6835505284 --ipa build/testflight-next/Deadbolt.ipa --upload-only --wait
```

Build number 2 is illustrative; check existing builds before selecting the next number. After processing, set the build's applicable encryption status, add test notes, and assign it to the internal group. This release has no external beta review or public invitation link.

For this private beta, standard third-party cryptography is used and no French App Store distribution is planned. Apple's declaration API rejected a declaration with `containsProprietaryCryptography=false`, `containsThirdPartyCryptography=true`, and `availableOnFrenchStore=false` because those answers do not require documentation. The uploaded build was set to `usesNonExemptEncryption=false`; this does not mean the app uses no encryption. See Apple's [documentation requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption). Reassess this scope before public distribution; no blanket encryption exemption was added to the source plist.

The obsolete archives for the former bundle ID were removed after the final build entered internal testing. The final IPA/archive and reusable Rust libraries remain local. No worktrees were created, and no simulator was started during release preparation.

For normal verification:

```sh
scripts/run.sh prepare
scripts/run.sh check xctest --json
scripts/run.sh build --check --device --json
scripts/run.sh up --sim medium --state fresh
scripts/run.sh down
```

`scripts/run.sh` keeps runbp source mirroring off so ignored native archives remain available. Xcode's Rust prerequisite invokes `scripts/build-rust.sh` for the correct platform; fresh retained archives are reused.

## Limits

- No physical iPhone has been installed or tested by the agent. Signing and TestFlight delivery now pass. Simulator token authentication is not proof of real Face ID, Touch ID, passcode changes, device lock protection, or hardware extension memory behavior.
- Peer testing used a real native macOS bridge peer and the real iOS app on one Mac. It did not exercise the upstream desktop application's UI, distinct physical networks, forced relay routing, or a VPN-free wide-area connection. No test configuration required Tailscale or a VPN; production Iroh configuration was used.
- Native passkeys were tested against the local disposable relying party. Additional third-party sites, production account recovery, and cross-device passkey use remain unverified.
- The existing-device join path and fresh-device interrupted-join recovery were exercised. Retry after pairing expiration and device revocation UI were compiled and reviewed but not independently exercised in the simulator.
- Password CSV import was exercised with an Apple-style export and quoted notes. The parser tests cover additional formats; exhaustive exports from every manager were not tested.

## Native Credential Exchange import, build 2

Added Apple's iOS 26 Credential Exchange receiver to the existing iOS 18 app. Passwords and supported TOTP configurations convert into encrypted login records; ES256 PKCS8 passkeys preserve credential IDs, user handles and private keys. The review requires a destination vault, supports individual selection, and reports unsupported credentials/extensions and metadata. Backgrounding clears received previews. All selected records commit atomically; exact matches are skipped. Passkey duplicate detection compares the underlying public key so equivalent PKCS8 encodings do not produce false conflicts.

Validation on November 16, 2026:

- Native Rust suite: 13 passed, including new imported-passkey signing after peer sync and store reopening, RP binding, duplicate handling, and atomic rejection of malformed/conflicting keys. After review, the two exchange tests passed again with an alternate valid PKCS8 encoding of the same key. Logs: `docs/evidence/rust-exchange-tests.txt` and `docs/evidence/rust-exchange-key-encoding.txt`.
- Swift suite: 52 passed, 0 failed, 0 skipped. Includes Apple type conversion, RFC 6238 vectors, unsupported data reporting, atomic bridge counts, cancellation, stale async results, lock clearing, and queued transfers. Result: `/Users/zackbart/.runbp/projects/4dc42eb8a4a65669806a/development/runs/20261116T164911Z-check-81323-f049ec/result.json`.
- Real Apple Passwords export: created a disposable login using Apple's generated password and the public RFC 6238 TOTP test seed through the visible UI. Export Data to Another App listed Deadbolt without first enabling AutoFill. The system activity reached Deadbolt; after unlock, review showed the password and verification code. Confirmed import into `personal`, displayed the stored login and a verification code matching an independent HMAC calculation, and re-exported the same item to verify that it was skipped rather than duplicated. Visible assertions passed for received source, successful import, verification code, duplicate skip, and locked vault.
- Independent Sol review covered Rust atomicity/key validation, Swift lifecycle/conversion, and a screenshot of the review UI. Fixed equivalent-key duplicate comparison, preservation of notes on every separately selectable derived login, and primary Import button prominence.

System-transfer session: `/Users/zackbart/.runbp/projects/4dc42eb8a4a65669806a/sessions/runbp-deadbolt-ios-dba56106-5927-404a-8e76-8ca98dfed1db`. `runbp evidence check` passed with no problems (85 ledger entries); the ledger retains intermediate failed commands and native-sheet accessibility failures. These are not a claim that every command succeeded. Review screenshot: `runbp-1794847703762.png` (before the final button style improvement).

The first transfer reached new-vault setup but Apple's fetch returned AuthorizationError 1004 after delayed setup and the automation returned to the source app. The cause is not proven. Retrying with an existing vault and using a non-settling native press for the final cross-app handoff succeeded twice. The guide now recommends setting up the vault first and promptly unlocking without leaving Deadbolt. Failure remains recoverable and leaves source credentials intact.

Only the same medium iOS 27.2 simulator was used, with stock services enabled for system transfer. Actual Apple Passwords passkey export, iOS 26 runtime behavior, and physical-device authentication remain unverified. Passkey key preservation/signing is covered by the Rust integration test and Apple's Swift adapter test, not a claimed real-device migration. No real user credentials were used. A temporary standalone exporter was removed after switching to Apple Passwords as the real test source.

The final lifecycle-only rerun passed all 10 tests after refining interruption messaging: `/Users/zackbart/.runbp/projects/4dc42eb8a4a65669806a/development/runs/20261116T170141Z-check-98975-e52f80/result.json`; its evidence check also passed. An earlier mistyped test-class selector executed zero tests and was correctly reported unverified; the first corrected attempt was blocked by runbp's process inventory. The successful retry used stock simulator services and cleaned up normally.

The final signed IPA passed inspection: both app and provider declare `1.0 (2)`, both provisioning profiles belong to Cursor Kittens LLC (`F2J8ZU2NQJ`), and both retain AutoFill/App Group entitlements. The app advertises the correct user activity and the provider advertises credential exchange format 1.0. Artifact: `build/testflight-exchange/Deadbolt.ipa`. No simulator session remains active; no worktrees were created.

Build **1.0 (2)** is now available in Cursor Kittens Internal Testing. ASC build ID `072a4413-cc56-457f-af33-1641447f9e72` reports `VALID` and `IN_BETA_TESTING`; group lookup confirms explicit membership in `Internal Testing` (`b2142106-60cf-4908-9f41-1d33ba4a9737`). English test notes include the import steps and remaining physical-device/passkey-migration validation. The same private-beta encryption scope as build 1 applies. The marketing version remains 1.0, with the build-only policy recorded in `AGENTS.md`.

Removed the temporary Rust target cache after validation and retained the reusable Rust archives and signed release artifacts. Approximately 97 GB is free. All runbp sessions created for this work are closed; no worktrees remain.
