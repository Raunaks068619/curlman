# Curlman Public Release Implementation Plan

**Date:** 2026-09-05

**Design:** `docs/superpowers/specs/2026-09-05-curlman-public-release-design.md`

## Delivery Rules

- Preserve the currently working native and Electron applications at every checkpoint.
- Implement in vertical slices with tests added before or alongside behavior.
- Never execute imported cURL text through a shell.
- Keep secrets out of history, logs, fixtures, exports, and release artifacts.
- Publish artifacts only after clean-install and platform verification succeeds.
- Keep the native Swift app independent from Electron and Node.js.

## Milestone 1: Native Release Foundation

### 1.1 Production metadata and privacy

Files:

- `Packaging/Info.plist`
- `Packaging/Curlman.entitlements`
- `Packaging/PrivacyInfo.xcprivacy`
- `Sources/CurlmanNative/App/AppDelegate.swift`

Tasks:

1. Add About, Help, Privacy, Check for Updates, and Quit commands to the menu-bar menu.
2. Add release-channel and version presentation.
3. Add a privacy manifest declaring the shipped local-only behavior.
4. Add the minimal production entitlements required by the app.
5. Ensure production signing rejects development-only entitlements.

Verification:

- Property lists validate with `plutil`.
- Menu command tests cover every required command.
- The built bundle contains the privacy manifest and entitlements match the approved allowlist.

### 1.2 Universal, signed, notarized build

Files:

- `scripts/build-release.sh`
- `scripts/verify-native-release.sh`
- `scripts/notarize-release.sh`
- `.github/workflows/release.yml`

Tasks:

1. Build release executables for `arm64` and `x86_64`.
2. Combine binaries with `lipo` and verify both architectures.
3. Assemble the application bundle deterministically.
4. Sign with a configurable Developer ID identity, Hardened Runtime, secure timestamp, and explicit entitlements.
5. Retain a local ad-hoc mode only for developer builds and label its artifacts as non-distributable.
6. Create and sign the DMG.
7. Submit, wait, staple, and validate through `notarytool` when credentials are supplied.
8. Generate SHA-256 checksums and a JSON build manifest.
9. Add release verification for architectures, signature identity, Hardened Runtime, entitlements, notarization, stapling, and Gatekeeper.

Verification:

- Unsigned local mode builds on a developer machine.
- Production mode fails closed when signing or notarization inputs are absent.
- `lipo -info`, `codesign`, `stapler`, and `spctl` pass for the production artifact.

## Milestone 2: Native Onboarding and Recovery

Files:

- `Sources/CurlmanNative/Onboarding/OnboardingState.swift`
- `Sources/CurlmanNative/Onboarding/OnboardingView.swift`
- `Sources/CurlmanNative/Persistence/DraftStore.swift`
- `Sources/CurlmanNative/App/AppDelegate.swift`
- `Sources/CurlmanNative/App/AppModel.swift`
- `Tests/CurlmanNativeTests/OnboardingStateTests.swift`
- `Tests/CurlmanNativeTests/DraftStoreTests.swift`

Tasks:

1. Implement the approved minimal two-page onboarding layout with a fixed footer.
2. Keep the description, benefits, privacy promise, and GitHub repository card on page 1.
3. Keep shortcut configuration and the optional safe request on page 2.
4. Allow editing and registering the global shortcut in place without requesting Accessibility permission.
5. Load the safe example request without sending it automatically.
6. Allow skipping and reopening onboarding from Help.
7. Persist onboarding completion and restore unsent drafts after restart.
8. Add keyboard focus, VoiceOver labels, semantic status announcements, and reduced-motion behavior.

Verification:

- Onboarding tests cover first run, skip, replay, shortcut conflict, optional request success, and network failure.
- The GitHub card renders without a background network request and opens only the expected public repository.
- Draft tests cover save, restore, redaction, corruption, and clearing after reset.
- A keyboard-only smoke test completes onboarding.

## Milestone 3: Complete Request Modeling

Files:

- `Sources/CurlmanNative/Domain/HTTPRequestDraft.swift`
- `Sources/CurlmanNative/CurlImport/CurlParser.swift`
- `Sources/CurlmanNative/CurlImport/CurlExporter.swift`
- `Sources/CurlmanNative/Networking/HTTPClient.swift`
- matching native tests
- `apps/electron/src/shared/models.ts`
- `apps/electron/src/shared/curl.ts`
- matching Electron tests

Tasks:

1. Add form URL encoded and multipart body models.
2. Add text and explicitly approved file parts.
3. Add API key auth in header or query form.
4. Add request timeout, redirect policy, and cookie-session policy.
5. Extend cURL import and export without enabling shell substitutions.
6. Normalize actionable validation and transport error categories.
7. Create shared versioned JSON fixtures and run them against both implementations.

Verification:

- Parser and exporter round-trip tests cover all supported body and auth variants.
- Native and Electron produce equivalent normalized drafts for shared fixtures.
- File references and unsupported options cannot read local data silently.

## Milestone 4: Complete Request Interface

Files:

- `Sources/CurlmanNative/UI/RequestView.swift`
- `Sources/CurlmanNative/UI/RootView.swift`
- `Sources/CurlmanNative/UI/CodeTextView.swift`
- corresponding Electron renderer components and styles

Tasks:

1. Add form, multipart, file, API key, timeout, redirect, and cookie controls.
2. Add native file selection and drag-and-drop confirmation.
3. Preserve the shared alignment guide and compact native control scale.
4. Keep Body, Params, Headers, and Auth as request sections.
5. Ensure paste works without a preliminary click in expanded and compact modes.
6. Keep Copy cURL synchronized with every current edit.

Verification:

- UI tests cover every body and auth state.
- Light, dark, increased-contrast, reduced-transparency, and reduced-motion states remain usable.
- Expanded resizing never changes compact geometry.

## Milestone 5: Response Pipeline and Interface

Files:

- `Sources/CurlmanNative/Networking/HTTPClient.swift`
- `Sources/CurlmanNative/UI/ResponseView.swift`
- `Sources/CurlmanNative/App/AppModel.swift`
- corresponding Electron main and renderer components

Tasks:

1. Add bounded response buffering and a save-only path for large bodies.
2. Record redirect metadata, MIME type, duration, byte count, status, and transport state.
3. Add JSON, XML, HTML, text, image, and binary presentation decisions.
4. Add response search, copy body, copy headers, copy complete response, and save.
5. Preserve the rule that Response appears only after execution.
6. Distinguish HTTP error responses from transport failures.

Verification:

- Deterministic local-server tests cover all response classes and error categories.
- Cancellation is immediate and leaves a visible, recoverable history entry.
- Large responses never trigger unbounded formatting or memory use.

## Milestone 6: History, Redaction, and Portability

Files:

- `Sources/CurlmanNative/Persistence/HistoryStore.swift`
- `Sources/CurlmanNative/UI/HistoryView.swift`
- Electron history store and renderer
- versioned interchange schema and fixtures

Tasks:

1. Add retention by age and maximum storage size.
2. Add history export and import using a versioned schema.
3. Add user-configurable secret-header redaction.
4. Preserve failed and cancelled requests and exact restoration.
5. Add visible rename support where the data layer already supports it.
6. Make migrations recoverable and test corrupt or incompatible imports.

Verification:

- Retention, redaction, migration, import, export, and round-trip tests pass.
- No authentication secret appears in persisted or exported fixtures.

## Milestone 7: Electron Distribution

Files:

- `forge.config.ts`
- `package.json`
- `.github/workflows/release.yml`
- `scripts/verify-electron-package.mjs`

Tasks:

1. Produce a Windows installer and portable archive.
2. Produce Linux AppImage and Debian packages.
3. Add platform icons, metadata, artifact names, and checksums.
4. Verify tray menu, Quit, shortcut, hidden-window lifecycle, and packaged dependencies.
5. Keep `npm install` and `npm run dev` as the documented source workflow.
6. Defer `npx curlman` until a reliable launcher is separately accepted.

Verification:

- Packages build on native GitHub-hosted runners.
- Clean Windows, Ubuntu, and Debian environments install, launch, execute a local test request, and quit.
- Packaged applications contain no missing runtime modules.

## Milestone 8: Homebrew and Public Release Automation

Files:

- `.github/workflows/release.yml`
- release verification scripts
- project-owned Homebrew tap repository

Tasks:

1. Create `Raunaks068619/homebrew-curlman` if it does not exist.
2. Add a Cask that references the exact notarized GitHub DMG and checksum.
3. Update the tap only after all release assets pass verification.
4. Protect release tags and keep Developer ID and App Store Connect credentials in GitHub secrets.
5. Publish release notes, checksums, and a build manifest.

Verification:

- `brew install --cask raunaks068619/curlman/curlman` downloads, installs, launches, and uninstalls Curlman.
- The installed app matches the published checksum and passes Gatekeeper.

## Milestone 9: Documentation and Public Onboarding

Files:

- `README.md`
- `CONTRIBUTING.md`
- `SECURITY.md`
- platform troubleshooting and release documentation
- demo media

Tasks:

1. Add a platform installation matrix and one-minute quick start.
2. Add the onboarding demo and concise product positioning.
3. Insert the current GitHub star count into release metadata without adding a first-run network request.
4. Document supported cURL flags, privacy, local data, retention, export, uninstall, and troubleshooting.
5. Document contributor setup, architecture, tests, packaging, signing, notarization, and security reporting.
6. Validate every public link and command against published artifacts.

Verification:

- A new user can install and complete a request using only the README and onboarding.
- A new contributor can run both test suites from a fresh clone.

## Milestone 10: Completion Audit

1. Map every design acceptance item to direct evidence.
2. Run all local and CI checks.
3. Verify current GitHub release and Homebrew state, not only repository configuration.
4. Verify clean installations on every advertised platform.
5. Confirm secret absence and artifact integrity.
6. Mark the release complete only when every requirement has passing evidence.
