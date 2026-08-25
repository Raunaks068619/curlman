# Curlman Native Rename and Electron Implementation Plan

Date: 2026-08-25  
Design: `docs/superpowers/specs/2026-08-25-curlman-electron-design.md`

## Delivery Strategy

Preserve the working Swift product while introducing changes in independently verifiable slices. Rename and migrate the native app first, then establish a secure Electron shell, port dependency-free domain behavior, add persistence and desktop services, reproduce the approved UI, and finish with cross-platform CI. Each slice must leave the repository buildable and tested.

## Phase 1: Rename the Native Product Safely

1. Add migration-focused tests before changing identifiers.
2. Rename the Swift package, executable target, source directory, test target, display strings, app metadata, build output, and scripts from API Panel to Curlman.
3. Change the bundle identifier to `com.raunak.Curlman` and Keychain service to `com.raunak.Curlman.credentials`.
4. Add a one-time migration coordinator that imports the legacy SwiftData store and copies referenced Keychain entries.
5. Make migration idempotent and preserve legacy data unchanged.
6. Update native branding assets, README commands, screenshots, release names, and documentation.

Verification:

- `swift test` passes under renamed targets.
- A legacy fixture store migrates once without duplicate records.
- Keychain migration copies a credential while retaining the source entry.
- The native Curlman build launches with the new identity.

## Phase 2: Customizable Native Shortcut

1. Introduce a platform-neutral shortcut model and persisted native preference.
2. Refactor `GlobalHotKey` to register arbitrary supported modifier and key combinations.
3. Preserve the last working registration when a replacement conflicts.
4. Add a native Settings view with a shortcut recorder, reset action, validation, and conflict message.
5. Add Settings to the menu-bar menu and ensure changes apply immediately.

Verification:

- Shortcut encoding and persistence tests pass.
- Conflict tests prove the previous shortcut remains registered.
- The panel toggles with the newly recorded shortcut.

## Phase 3: Root npm Workspace and Secure Electron Shell

1. Add root `package.json`, lockfile, supported Node version, workspace scripts, ESLint, TypeScript, Vitest, and formatting configuration.
2. Scaffold `apps/electron` with Electron Forge, Vite, React, and strict TypeScript.
3. Create main, preload, renderer, and shared type boundaries.
4. Enable context isolation and sandboxing; disable Node integration, navigation, untrusted windows, and unnecessary permissions.
5. Add a restrictive content security policy and sender validation for every privileged IPC handler.
6. Add a tray lifecycle, hidden-on-close window behavior, and development startup.

Verification:

- A clean install supports `npm run dev` without Xcode or native compilation.
- `npm run lint`, `npm run typecheck`, and `npm test` pass.
- The renderer cannot access Node.js or generic IPC.

## Phase 4: Shared Contracts and TypeScript Request Core

1. Add versioned JSON schemas and fixtures for request drafts, cURL imports, cURL exports, responses, and history snapshots.
2. Port the shell-safe cURL tokenizer and parser to TypeScript without invoking a shell.
3. Port cURL export, request validation, URL/query merging, auth handling, JSON formatting, and redaction.
4. Run Swift and TypeScript parity tests against the same fixtures.
5. Add unsupported-option warnings that preserve supported content.

Verification:

- All existing native parser and exporter scenarios have matching TypeScript results.
- Multiline POST cURL commands populate method, URL, headers, body, and authentication correctly.
- Secrets never appear in sanitized fixtures or snapshots.

## Phase 5: Electron HTTP and Credential Services

1. Define narrow IPC contracts for execute, cancel, credentials, clipboard, and save response.
2. Implement main-process HTTP execution with status, reason, headers, duration, byte count, MIME type, cancellation, and transport failures.
3. Implement credential encryption with Electron `safeStorage` and atomic encrypted-file persistence.
4. Refuse plaintext persistence when secure encryption is unavailable.
5. Add clipboard and save-response services with validated inputs and safe file dialogs.

Verification:

- Local HTTP fixture tests cover GET, POST, auth, errors, timeout, and cancellation.
- IPC rejects malformed messages and untrusted senders.
- Stored credential files contain no plaintext secret.

## Phase 6: Electron History and Preferences

1. Add a WASM-backed SQLite store that requires no local compiler.
2. Implement begin, finalize, reconcile pending, search, pin, rename, delete, and clear operations.
3. Cap stored response bodies at 2 MiB and retain original size and truncation state.
4. Add versioned preferences for window geometry, compact state, theme behavior, and shortcut.
5. Serialize database and settings writes atomically.

Verification:

- History persists across application restarts.
- Success, HTTP errors, transport failures, and cancellation all create recoverable records.
- Pending records reconcile after interrupted execution.
- Authorization and credentials never enter history storage.

## Phase 7: Request and Response Interface

1. Establish shared tokens for system fonts, semantic surfaces, spacing, focus, status, and syntax colors.
2. Build the command row with method, URL/cURL input, Send/Cancel, and Copy as cURL.
3. Build Request sections for Body, Params, Headers, and Auth.
4. Add a rich JSON/raw editor with formatting, validation, line numbers, syntax highlighting, undo, find, and keyboard navigation.
5. Insert Response only after execution and select it on completion.
6. Build Pretty, Raw, and Headers response sections with copy, save, and search.
7. Preserve full-width content and the approved alignment hierarchy at all supported sizes.

Verification:

- Pasting the approved multiline POST example fills every request field.
- Sending visibly transitions to a formatted response.
- Light and dark themes, keyboard focus, and reduced motion remain usable.

## Phase 8: History, Settings, Compact Mode, and Tray

1. Build the History tab with search, restore, open response, rerun, pin, rename, delete, and clear.
2. Show fixed timestamps rather than active elapsed timers.
3. Build Settings with the global shortcut recorder and secure-storage status.
4. Register platform defaults and persist custom accelerators.
5. Report conflicts while preserving the last working shortcut.
6. Implement tray/menu actions, draggable full panel, stored expanded geometry, fixed compact size, hide, close, and restore.
7. Expand compact mode when cURL is pasted and reveal Response after compact execution.

Verification:

- Native and Electron apps can run together using distinct shortcuts.
- Resizing the expanded window never changes compact dimensions.
- Compact paste and send reveal the complete editable request and response.

## Phase 9: Cross-Platform CI and Documentation

1. Extend GitHub Actions with Electron lint, typecheck, and tests.
2. Add macOS, Windows, and Linux smoke jobs for startup and core request execution.
3. Keep network tests local and deterministic.
4. Document prerequisites, root npm commands, native commands, architecture, security, and current packaging boundary.
5. Rename the GitHub repository to `curlman` after local links and branding are ready.
6. Mark API Panel v0.1.0 as the legacy rollback release and use Curlman for future releases.

Verification:

- All three platform jobs pass.
- A fresh clone launches Electron using only Node.js/npm, `npm install`, and `npm run dev`.
- README links resolve after the repository rename.

## Phase 10: Final Parity Audit

1. Run the same manual cURL workflows in native and Electron Curlman.
2. Compare request parsing, formatted bodies, status metadata, response content, history, restore, rerun, and cURL export.
3. Confirm no shell execution, plaintext secrets, accidental Dock/taskbar lifetime, or silent history loss.
4. Record deferred packaging work separately without expanding this phase.

Completion criteria:

- Every success criterion in the approved design is verified.
- Native and Electron tests pass locally and in CI.
- macOS, Windows, and Linux Electron smoke checks pass.
- The owner can keep using native Curlman while testing Electron from the same checkout.
