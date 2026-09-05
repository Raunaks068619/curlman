# Curlman Public Release Design

**Date:** 2026-09-05

**Status:** Ready for user review

**Product:** Curlman

**Repository:** `Raunaks068619/curlman`

## 1. Purpose

Curlman is a focused, local-first API testing utility for developers who need to paste, edit, execute, and revisit cURL requests without keeping a large API workspace open.

The public product has two implementations with one consistent workflow:

- A native Swift menu-bar app for macOS, distributed as a signed and notarized universal DMG and through Homebrew.
- An Electron app for Windows and Linux, distributed as native installers and runnable from a fresh source checkout with npm.

Curlman is not intended to replace Postman, Bruno, or a complete API collaboration suite. It optimizes for immediate access, low interruption, editable requests, full-width responses, and automatic local history.

## 2. Success Criteria

The release is successful when all of the following are true:

1. A user on a clean supported Mac can install the DMG and open Curlman without bypassing Gatekeeper.
2. The same notarized macOS artifact can be installed through a project-owned Homebrew Cask.
3. Users can install prebuilt Electron packages on supported Windows and Linux systems.
4. A contributor can clone the repository, run `npm install`, and start Electron with `npm run dev`.
5. First-run onboarding teaches the complete activation loop using a real, user-triggered request.
6. A pasted cURL command can be edited, sent, inspected, copied back as cURL, and recovered from local history.
7. Published artifacts, checksums, signatures, supported architectures, and release notes are verified automatically.

The initial supported release targets are macOS 14 or newer on Apple Silicon and Intel, Windows 10 or 11 on x86-64, and Ubuntu 22.04 or 24.04 plus Debian 12 on x86-64. Additional Windows and Linux architectures or distributions require their own build and clean-install evidence before being advertised as supported.

## 3. Current Validated Baseline

The repository is public and contains an MIT license, a native Swift implementation, an Electron implementation, product documentation, design documentation, and GitHub Actions CI.

Validated on 2026-09-05:

- 17 native Swift tests pass.
- 7 Electron tests pass.
- Electron TypeScript type checking passes.
- Electron ESLint checks pass.
- CI is configured for native macOS tests and Electron checks on macOS, Windows, and Linux.
- The current native release script builds only `arm64` and applies an ad-hoc signature.
- Electron Forge makers are configured, but Windows and Linux packages are not published.
- No Homebrew Cask, Apple notarization workflow, first-run onboarding, or public cross-platform installer workflow exists.

## 4. Product Scope

### 4.1 Existing capabilities to preserve

- Import multiline cURL commands without executing them in a shell.
- Edit methods, URL, query parameters, headers, JSON or raw bodies, Bearer auth, and Basic auth.
- Format imported JSON and syntax-highlight request and response bodies.
- Execute requests with a keyboard shortcut.
- Show Response only after an execution result exists.
- Copy the current edited request as cURL.
- Automatically save request and response history.
- Search, restore, rerun, pin, and delete history.
- Configure the global shortcut.
- Minimize to a fixed, draggable, interactive compact command strip.
- Follow system appearance, typography, accent color, and accessibility settings.
- Store native credentials in Keychain and keep application data local.

### 4.2 Required public v1 capabilities

#### Request authoring

- `application/x-www-form-urlencoded` bodies.
- Multipart forms with text fields and file attachments.
- API key authentication in either a header or query parameter.
- Per-request timeout.
- Redirect policy and visible redirect metadata.
- Session cookie support with a clear reset action.
- Drag and drop for cURL text and approved files.
- Safe handling of cURL file references through explicit file selection and confirmation.
- Clear validation for malformed URL, DNS, TLS, timeout, cancellation, offline, and unsupported cURL options.

#### Response inspection

- Pretty and raw views for JSON, XML, HTML, and text.
- Image preview for supported image responses.
- Response search.
- Copy body, headers, and complete response.
- Save response to a chosen file.
- Status, duration, received size, MIME type, and redirect metadata.
- Large-response protection that avoids loading or formatting unbounded data in memory.

#### History and recovery

- Configurable retention period and maximum storage size.
- Export and import using a documented, versioned local format.
- Exact request restoration and rerun.
- Failed and cancelled requests retained with their terminal state.
- Crash-safe restoration of the current unsent draft.
- Secret redaction before persistence, display, logs, and export.

#### Native application completeness

- First-run onboarding.
- Shortcut conflict detection and recovery.
- Keyboard-only operation and predictable focus.
- VoiceOver labels and logical focus order.
- Increased Contrast, Reduce Transparency, and Reduce Motion support.
- About, Help, Privacy, Check for Updates, and Quit menu items.
- Explicit application version and release channel display.

### 4.3 Deferred capabilities

The following are intentionally deferred until after the stable public release:

- OAuth 2 flows.
- Environments and reusable variables.
- Proxy configuration.
- Custom certificate authorities and client certificates.
- Sparkle automatic installation of updates.
- Team workspaces, cloud sync, collaboration, mock servers, scripting, runners, documentation hosting, GraphQL subscriptions, WebSockets, gRPC, and SSE.

## 5. Interaction Design

### 5.1 Daily workflow

1. The user presses the configured global shortcut or clicks the menu-bar or tray icon.
2. Curlman appears from the top-right work area and focuses the command field.
3. The user pastes a URL or cURL command without first clicking the field.
4. Curlman parses the request and reveals editable fields.
5. The user presses Command-Enter on macOS or Control-Enter on Windows and Linux.
6. Send changes to Cancel while the request is active.
7. A Response tab appears and becomes active when a result is available.
8. The execution is saved automatically to History.

Request, Response, and History are top-level tabs. History is not a persistent sidebar. Response does not exist before a request produces a result. Escape hides the panel without losing the draft.

### 5.2 First-run onboarding

Onboarding is a minimal two-page flow. It is skippable, repeatable from Help, keyboard accessible, and never sends a request without user action.

- Page 1 introduces Curlman, its lightweight purpose, the open, edit, send, and local-history workflow, the local-only privacy promise, and the GitHub repository card.
- Page 2 contains the editable global shortcut and an optional safe example request.
- A fixed footer provides two progress dots, Back on page 2, and one primary Continue or Start Using Curlman action.

Both pages use a centered 600-point content column inside the 780-point window, with generous vertical grouping and readable 30-point page headlines. They fit the minimum expanded window without scrolling or clipping. Page changes use a restrained directional transition that is removed when Reduce Motion is enabled.

The shortcut control presents the platform default and allows recording a replacement in place. A registration conflict keeps the previous working shortcut and explains how to choose another.

The optional example is loaded, but never sent automatically:

```sh
curl https://api.github.com/zen
```

The user may press the send shortcut or choose Send. A success, HTTP error, or transport failure demonstrates the result and local History behavior, but onboarding completion never depends on network availability.

The GitHub repository card contains the Curlman icon, `Raunaks068619/curlman`, a release-time snapshot of the public star count, and a Star on GitHub button. If the count is zero, supporting copy says “Be the first star.” Curlman does not contact GitHub merely to render onboarding. Release automation inserts the count into build metadata, and the explicit button opens the public repository in the user’s browser where GitHub handles authentication and starring.

### 5.3 Visual system

- Use native controls and platform system fonts.
- Use semantic system colors and the user’s accent color.
- Use material only for the floating shell and transient chrome.
- Keep editors, authentication surfaces, responses, and history opaque.
- Use compact system spacing with clear shared alignment guides.
- Avoid decorative cards, fake notch geometry, custom scrollbars, permanent split panes, and empty response panels.
- Use 150 to 250 millisecond state transitions with reduced-motion behavior.
- Communicate status through text and symbols, not color alone.

## 6. Architecture

Each implementation will use bounded components with equivalent behavior and shared fixtures.

### 6.1 Core components

- `RequestDraft`: method, URL, params, headers, auth, body, timeout, redirects, and cookie policy.
- `CurlParser`: converts supported cURL syntax into a request draft and warnings.
- `CurlExporter`: creates a shell-safe cURL representation of the current edited request.
- `HTTPClient`: executes the request and reports response data and transport metadata.
- `HistoryRepository`: stores versioned request and response records, performs migrations, retention, search, and import or export.
- `CredentialVault`: stores secret values using the operating system credential facility.
- `DraftStore`: saves and restores the current unsent request.
- `OnboardingState`: stores onboarding completion without coupling it to request data.
- `UpdateChecker`: reads signed release metadata and opens the verified download page.

### 6.2 Request data flow

```text
Paste or edit
  -> CurlParser or RequestDraft mutation
  -> validation
  -> HTTPClient using native networking APIs
  -> response metadata and bounded body
  -> HistoryRepository with redacted request snapshot
  -> Response tab
```

The native app uses `URLSession`. Electron uses its main-process networking layer. Neither implementation passes pasted cURL input to a shell.

### 6.3 Cross-platform compatibility

Swift and Electron share a documented request and history interchange schema plus identical parsing fixtures. They do not share a runtime or live database. Platform-specific persistence adapters and credential stores remain independent.

## 7. Security and Privacy

- Never execute pasted cURL through a command shell.
- Never interpolate untrusted values into executable commands.
- Use strict system TLS validation by default.
- Store passwords, Bearer tokens, API keys, cookies marked as secrets, and authentication headers outside SQLite.
- Store native credentials in macOS Keychain and Electron credentials through operating-system-backed encrypted storage.
- Redact common and user-configured secret headers from history, logs, exports, and error reports.
- Require the user to select or confirm every local file used by a request.
- Ignore shell substitutions and unsafe file references during cURL import.
- Use session-only cookies by default and provide a visible clear-session action.
- Collect no analytics or telemetry and upload no crash reports automatically.
- Do not fetch GitHub stars or other promotional metadata during onboarding. Use release metadata and navigate to GitHub only after an explicit user action.
- Include a macOS privacy manifest in `Contents/Resources` that reflects the shipped behavior.

## 8. Error Handling

Errors are normalized into user-understandable categories:

- Invalid cURL or malformed URL.
- Unsupported cURL option with a non-blocking warning when safe.
- DNS resolution failure.
- TLS validation failure.
- Connection refusal or reset.
- Offline network state.
- Request timeout.
- User cancellation.
- Redirect rejection or loop.
- Local file access failure.
- Large response truncation or save-only mode.
- History migration, storage, or credential access failure.

An HTTP 4xx or 5xx result is a completed HTTP response, not a transport error. It remains visible and is written to History with its actual status.

## 9. macOS Build and Distribution

### 9.1 Canonical artifact

The canonical macOS release is one universal application containing `arm64` and `x86_64`, packaged in a signed and notarized DMG.

### 9.2 Release flow

1. Run native tests.
2. Build release binaries for `arm64` and `x86_64`.
3. Combine or package them as one universal app.
4. Sign nested code and the application with the Developer ID Application certificate.
5. Enable Hardened Runtime and a secure timestamp.
6. Sign the DMG.
7. Submit the DMG with `notarytool` using an App Store Connect API key stored in CI secrets.
8. Wait for acceptance and retain the notarization log.
9. Staple and validate the ticket.
10. Verify app and DMG signatures, architectures, entitlements, and Gatekeeper acceptance.
11. Install from a quarantined DMG in a clean test account and run the release smoke test.
12. Publish the DMG, SHA-256 checksum, release notes, and build manifest to GitHub Releases.

The stable native bundle identifier remains `com.raunak.Curlman`. Production artifacts must not contain `get-task-allow` or development-only entitlements.

### 9.3 Homebrew

The first Homebrew channel is a project-owned tap. Its Cask references the exact GitHub release DMG and checksum and installs `Curlman.app`.

Expected command:

```sh
brew install --cask raunaks068619/curlman/curlman
```

Release automation updates the tap only after the canonical DMG passes every verification gate. Submission to the official Homebrew Cask repository is deferred until the project meets its acceptance expectations.

### 9.4 Updates

Version 1.0 includes Check for Updates, which reads GitHub release metadata and opens the verified release page. Sparkle with a signed EdDSA appcast is deferred to version 1.1 so it does not delay the first trusted release.

## 10. Windows and Linux Distribution

Electron provides the consistent non-Mac product.

### 10.1 Windows

- Signed installer executable.
- Portable executable or ZIP.
- Winget submission after the installer and update process stabilize.

### 10.2 Linux

- AppImage for portable use.
- Debian package for Debian and Ubuntu.
- RPM after demand justifies another maintained format.

### 10.3 npm development workflow

A fresh clone must support:

```sh
npm install
npm run dev
```

`npx curlman` is deferred until a reliable launcher exists. It is a development convenience, not the primary desktop installer, because it still downloads Electron and application dependencies.

## 11. Continuous Integration and Releases

### 11.1 Pull-request checks

- Native Swift tests on macOS.
- Electron type checking, linting, and tests on macOS, Windows, and Linux.
- cURL parser fixtures and import or export round trips in both implementations.
- Electron packaging smoke tests on every supported packaging platform.
- Secret scanning and checks that fixtures contain no real credentials.

### 11.2 Protected tag release

- Create an ephemeral macOS keychain.
- Import the encrypted Developer ID certificate from repository secrets.
- Build, sign, notarize, staple, and verify the universal DMG.
- Build Windows and Linux packages on their native GitHub Actions runners.
- Generate checksums and a machine-readable build manifest.
- Publish artifacts only if every required job passes.
- Update the Homebrew tap using the published checksum.
- Ensure credentials and notarization secrets never appear in logs or artifacts.

## 12. Validation Strategy

### 12.1 Unit and integration tests

- Representative cURL fixtures, quoting, malformed input, warnings, and round trips.
- GET query encoding, JSON, raw, form URL encoded, multipart, file, and authentication request construction.
- Redirect, timeout, cookie, cancellation, HTTP error, and transport error behavior.
- JSON, XML, HTML, text, binary, image, and large response handling.
- History migrations, retention, redaction, import, export, recovery, and exact restoration.
- Credential adapter behavior using test doubles rather than real secrets.
- Two-page onboarding navigation and completion, shortcut editing, example-request, and GitHub-card states.

### 12.2 UI and accessibility tests

- Paste works immediately in expanded and compact modes.
- Compact mode stays fixed-size, draggable, interactive, and correctly clipped after resizing the expanded panel.
- Response becomes visibly active only after execution.
- Request, Response, and History preserve focus and keyboard navigation.
- Light Mode, Dark Mode, Increased Contrast, Reduce Transparency, and Reduce Motion.
- VoiceOver labels, reading order, status announcements, and non-color status communication.

### 12.3 Release verification

- Inspect universal architectures.
- Verify signing identity, Hardened Runtime, timestamp, and entitlements.
- Validate notarization and stapling.
- Run Gatekeeper assessment on the app and DMG.
- Download the public artifact and compare its checksum with the release checksum.
- Install and launch from a clean, quarantined environment.
- Complete onboarding, optionally send the example cURL, inspect the response, find it in History, open the GitHub card, and quit from the menu.

## 13. Documentation

The README and release pages must make the first successful request possible in under one minute.

Required documentation:

- Clear positioning as a quick cURL testing companion rather than a Postman replacement.
- Platform installation table.
- Prominent native DMG and Homebrew instructions.
- Windows and Linux package links.
- Fresh-clone Electron development commands.
- A short onboarding GIF or video showing paste, edit, send, response, and history.
- Supported and intentionally unsupported cURL options.
- Local data locations, privacy, credential handling, retention, export, and uninstall instructions.
- Troubleshooting for shortcuts, Gatekeeper, TLS, files, proxies, and package launch failures.
- Contributor setup, tests, architecture overview, release process, and security reporting instructions.

## 14. Delivery Phases

### Phase 1: Release foundation

- Universal native build.
- Developer ID signing, Hardened Runtime, notarization, stapling, and verification.
- Privacy manifest and complete application menus.
- First-run onboarding and shortcut validation.
- Reproducible CI release foundation.

### Phase 2: API testing completeness

- Request body, file, auth, timeout, redirect, cookie, response, history, redaction, and recovery requirements defined in section 4.2.

### Phase 3: Public macOS release

- Clean-install acceptance test.
- GitHub version 1.0 release with notarized DMG, checksum, notes, and manifest.
- Project-owned Homebrew Cask.
- Public installation and troubleshooting documentation.

### Phase 4: Windows and Linux release

- Electron behavior parity.
- Windows installer and portable package.
- Linux AppImage and Debian package.
- Public checksums, documentation, and clean-environment smoke tests.

### Phase 5: Post-v1 improvements

- Sparkle, OAuth 2, environments, proxies, custom certificate authorities, client certificates, official Homebrew Cask submission, and Winget submission.

## 15. Final Acceptance Checklist

- [ ] Public repository, MIT license, contributing guidance, and security policy are present.
- [ ] All native and Electron tests pass in CI.
- [ ] The native application contains Apple Silicon and Intel architectures.
- [ ] The app and DMG are signed with the expected Developer ID identity.
- [ ] Hardened Runtime and production entitlements are verified.
- [ ] Apple notarization is accepted and stapled.
- [ ] Gatekeeper accepts the downloaded app and DMG.
- [ ] The GitHub release contains every documented artifact and checksum.
- [ ] Homebrew installs and launches the same native build.
- [ ] Windows and Linux installers launch in clean environments.
- [ ] `npm install` and `npm run dev` work from a fresh clone.
- [ ] The two-page onboarding can be completed with only the keyboard.
- [ ] The onboarding request produces a visible result or a clear network error and is saved to History.
- [ ] The onboarding GitHub card displays the release star-count snapshot and opens the expected public repository only after activation.
- [ ] Secrets are absent from history, logs, exports, fixtures, and release artifacts.
- [ ] README links and installation commands are tested against the published release.
