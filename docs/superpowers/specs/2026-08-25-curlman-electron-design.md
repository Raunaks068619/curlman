# Curlman Native Rename and Cross-Platform Electron Design

## Status

Approved in conversation on 2026-08-25. This document defines the product and architecture boundary for implementation planning.

## Goal

Rename API Panel to Curlman and add a complete Electron implementation in the same repository. Contributors must be able to clone the repository and launch the Electron app with:

```sh
npm install
npm run dev
```

The existing native macOS app remains the preferred daily-use version for the owner. The Electron app exists for cross-platform use and testing on macOS, Windows, and Linux.

## Product Decisions

- Curlman replaces API Panel in the native app name, GitHub repository, README, release branding, bundle identity, storage naming, and Electron identity.
- The native and Electron apps provide complete behavioral parity.
- Both apps can be installed and run on the same Mac.
- Both apps allow users to record and change the global show-or-hide shortcut.
- Existing native API Panel history and credentials migrate automatically to Curlman without deleting the original data.
- The Electron app uses one consistent Curlman interface on all operating systems. Only system window controls, modifier labels, and platform conventions adapt.
- The first Electron delivery is a development build. Installers, signing, auto-update, and public Electron releases are deferred until cross-platform behavior is validated.

## Repository Architecture

The repository contains two independent desktop implementations and one compatibility contract:

```text
/
├── package.json                 # npm install, npm run dev, test, lint, typecheck
├── apps/
│   └── electron/
│       ├── src/main/            # privileged desktop services
│       ├── src/preload/         # narrow typed bridge
│       └── src/renderer/        # React UI
├── contracts/
│   ├── schemas/                 # stable JSON data shapes
│   └── fixtures/                # shared curl and response parity cases
├── Sources/CurlmanNative/       # renamed Swift implementation
├── Tests/CurlmanNativeTests/    # native tests
└── Packaging/                   # native app metadata and release scripts
```

The Electron stack is Electron Forge, Vite, React, and TypeScript. The root package owns contributor commands and delegates to the Electron workspace. Swift remains independently buildable with Swift Package Manager.

Swift and TypeScript do not share runtime code. They share schemas and fixtures so each implementation can prove equivalent input and output behavior without cross-language coupling.

## Electron Process Boundaries

### Renderer

The React renderer owns visual state and interactions only. It renders Request, Response, History, and Settings. It has no direct Node.js, filesystem, credential, shell, or unrestricted Electron access.

### Preload bridge

The preload script exposes a small typed `curlman` API through `contextBridge`. Every operation has a specific method rather than exposing `ipcRenderer` or generic message sending. Inputs and outputs are validated at the boundary.

### Main process

The main process owns:

- HTTP execution and cancellation
- History persistence
- Credential encryption and retrieval
- cURL import and export services
- Clipboard writes
- Tray/menu behavior
- Window positioning, resizing, minimizing, hiding, and restoring
- Global shortcut registration and conflict reporting
- Local settings persistence

The renderer is sandboxed, context isolation is enabled, Node integration is disabled, navigation is restricted to the bundled application, and a restrictive content security policy is applied.

## Request Model and Behavior

Both implementations support:

- HTTP methods GET, POST, PUT, PATCH, DELETE, HEAD, and OPTIONS
- Complete HTTP or HTTPS URLs
- Enabled or disabled query parameters and headers
- JSON, raw, or empty request bodies
- No auth, bearer auth, and basic auth
- Multiline cURL import with warnings for unsupported flags
- cURL export from the current edited request
- JSON validation, formatting, and syntax highlighting
- Request cancellation by activating Send while a request is in progress

The Request tab is the default. Response is absent until an execution produces a response or transport failure. History remains a top-level tab rather than a sidebar.

## Complete Feature Parity

The Electron app includes:

- Editable method, URL, params, headers, body, and authentication
- Send button and keyboard execution
- Pretty, raw, and headers response views
- Response status, duration, byte count, copy, save, and search
- Automatic history for every execution
- History restore, rerun, pin, search, rename, and delete
- Copy current request as cURL
- Tray or menu-bar presence without a persistent taskbar or Dock entry where the platform permits
- Draggable, resizable full panel
- Fixed-size compact mode
- Hide, close, and restore behavior
- System light and dark appearance with one consistent Curlman visual system
- Keyboard-only operation, semantic labels, visible focus, and reduced-motion support

## Shortcut Settings

Both apps gain a shortcut recorder in Settings.

- Native default: Command-Shift-C.
- Electron default: Command-Shift-C on macOS and Control-Shift-C on Windows and Linux.
- Users can record and save another supported key combination.
- A new shortcut is registered before the previous shortcut is released. If registration fails, the previous working shortcut stays active.
- Conflicts produce a clear message and keep Settings open.
- Changes apply immediately and persist per application.
- Native and Electron preferences are separate, allowing different shortcuts when both apps run together.

## Native Rename and Migration

The native executable, Swift target, test target, display strings, icon metadata, bundle identifier, and Keychain service move from API Panel naming to Curlman naming. The intended new identifiers are:

- Bundle identifier: `com.raunak.Curlman`
- Keychain service: `com.raunak.Curlman.credentials`
- Swift package and executable: `CurlmanNative`

On first native Curlman launch:

1. Check for a completed migration marker.
2. If Curlman history is empty, locate the existing `APIPanel` SwiftData store.
3. Copy records into the Curlman store, preserving identifiers, timestamps, request snapshots, responses, outcomes, status, duration, response size, names, and pins.
4. For each referenced credential identifier, copy the secret from `com.raunak.APIPanel.credentials` to `com.raunak.Curlman.credentials`.
5. Write the migration marker only after history and credential migration complete successfully.
6. Leave the original API Panel store and Keychain entries untouched for rollback.

The migration is idempotent. Relaunching cannot duplicate history or credentials. A partial failure reports a recoverable error and retries later.

The GitHub repository slug becomes `curlman`; existing GitHub redirects preserve old links. The API Panel v0.1.0 release remains available as a clearly identified legacy release for rollback. New branding and future releases use Curlman.

## Electron Persistence

Electron owns an independent data directory under the operating system's standard application-data location.

- History is stored in a SQLite database using a WASM-backed implementation so `npm install` does not require a local C/C++ compiler.
- Database writes are serialized and persisted atomically.
- Response bodies are limited to 2 MiB per history entry; metadata retains the original response size and truncation state.
- Authorization headers and authentication secrets are redacted before history serialization.
- Credentials are encrypted through Electron `safeStorage` and stored separately from history.
- When secure encryption is unavailable, Curlman refuses to persist new secrets and keeps them in memory for the current session rather than writing plaintext.
- Preferences, including window state and shortcut, use a versioned local settings file.
- Native and Electron stores do not continuously synchronize.

## User Interface

Curlman retains the established compact hierarchy:

1. Window chrome and request command row
2. Request, Response, and History top-level tabs
3. Contextual Request or Response sections
4. Full-width technical editor or history content

The same layout, spacing, typography hierarchy, JSON colors, and progressive disclosure apply on all platforms. Platform adaptation is limited to system font selection, native modifier labels, window-control placement, tray conventions, and accessibility APIs.

The compact view has a fixed size independent of the last expanded size. Pasting a cURL command in compact mode expands the full panel and populates the request. Sending from compact mode expands the panel and selects Response when execution completes.

## Error Handling

- Invalid URLs and JSON appear beside the relevant request editor.
- Transport failures create and select a Response tab with a readable failure state.
- HTTP error status codes remain valid responses and are saved to history.
- Unsupported cURL flags produce non-blocking warnings while supported fields remain editable.
- A second Send action cancels an active request and records cancellation in history.
- Shortcut conflicts preserve the last working shortcut and direct the user to Settings.
- Database and credential failures are surfaced and never silently discard an execution.
- Interrupted pending history records are reconciled as failed or cancelled on the next launch.
- Renderer crashes cannot expose credentials or corrupt the history store.

## Contributor Commands

The root package provides:

```sh
npm install
npm run dev
npm test
npm run lint
npm run typecheck
```

`npm run dev` starts the Electron main process, preload bundle, and React renderer with hot reload. It does not build a DMG or require Xcode. Contributors still need a supported Node.js and npm installation; `npm install` downloads the Electron runtime.

Native commands remain:

```sh
swift test
./scripts/build-release.sh
```

## Testing and CI

- Shared fixture tests verify equivalent Swift and TypeScript cURL import and export results.
- TypeScript unit tests cover validation, formatting, redaction, history transformations, and shortcut conversion.
- React component tests cover Request, Response, History, Settings, compact mode, and empty/progressive states.
- Electron integration tests cover typed IPC, HTTP execution and cancellation, database persistence, tray lifecycle, window transitions, and shortcut registration failure.
- Existing Swift tests are renamed and extended for native shortcut preferences and migration idempotency.
- GitHub Actions runs Swift tests plus Electron lint, typecheck, and unit tests on every change.
- macOS, Windows, and Linux jobs perform Electron startup and core workflow smoke tests.

No test sends traffic to production services. Network tests use local fixtures or a local test server.

## Delivery Sequence

1. Rename the product and add backward-compatible native data migration.
2. Add customizable native global shortcuts.
3. Establish the root npm workspace and Electron security boundary.
4. Implement shared contracts, fixtures, and the TypeScript request core.
5. Build the Electron Request, Response, History, Settings, and compact interfaces.
6. Add tray, window, shortcut, persistence, and credential services.
7. Add cross-platform tests, CI, and contributor documentation.
8. Validate complete parity on macOS, Windows, and Linux.

Packaging, code signing, auto-update, and public Electron installers are explicitly outside this implementation phase.

## Success Criteria

- A clean clone launches Electron with only `npm install` and `npm run dev` after Node.js/npm are installed.
- Native Curlman preserves existing API Panel history and credentials.
- Native and Electron Curlman can run together with different configured shortcuts.
- The Electron app completes the full cURL-to-formatted-response workflow on macOS, Windows, and Linux.
- All approved parity features work and persist locally.
- No request is executed through a shell and no secret is written to history or logs.
- Swift tests and all Electron lint, typecheck, unit, integration, and platform smoke tests pass in CI.

## Primary References

- [Electron prerequisites and Forge recommendation](https://www.electronjs.org/docs/latest/tutorial/tutorial-prerequisites)
- [Electron Forge Vite and TypeScript template](https://www.electronforge.io/templates/vite-%2B-typescript)
- [Electron security recommendations](https://www.electronjs.org/docs/latest/tutorial/security)
- [Electron context isolation](https://www.electronjs.org/docs/latest/tutorial/context-isolation)
- [Electron IPC patterns](https://www.electronjs.org/docs/latest/tutorial/ipc)
