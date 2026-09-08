# Curlman Electron for Windows and Linux

## Status

Approved in conversation on 2026-09-08. This design keeps the cross-platform edition deliberately lean for an open-source, non-profit project.

## Goal

Make the existing Electron edition a dependable way to run Curlman on Windows and Linux without creating separate platform products. A contributor must be able to clone the repository and start Curlman with:

```sh
npm install
npm run dev
```

Release automation must also create installable Windows and Linux artifacts so non-contributors do not need to run the source.

## Product Boundary

- Curlman remains a focused local API tester, not a Postman replacement.
- The Electron edition uses one interface and one codebase on Windows, Linux, and macOS.
- Windows and Linux receive only necessary platform adaptations: system font, window controls, tray behavior, modifier labels, filesystem locations, and shortcut defaults.
- The native Swift edition remains the preferred macOS download.
- The project has no accounts, subscriptions, cloud sync, telemetry, advertising, or paid services.
- Platform-specific redesigns, extension marketplaces, collaboration, and enterprise administration are outside scope.

## Functional Scope

The Electron edition provides the same focused workflow already established by native Curlman:

1. Open Curlman from the tray or global shortcut.
2. Paste a URL or multiline cURL command into the focused command field.
3. Edit method, params, headers, body, and authentication.
4. Send with the button or platform shortcut.
5. Reveal a full-width Response tab only after a result exists.
6. Save every execution automatically in local History.

The request and response editors include JSON formatting, syntax highlighting, line numbers, folding, and find. The current edited request can be copied as cURL. History supports search, restore, rerun, pin, and deletion. Settings supports a custom global shortcut with conflict handling.

## Interface Design

The Electron interface follows Curlman's existing product design rather than imitating each operating system separately.

- Use the system UI font for each platform and a platform-appropriate monospace stack for technical content.
- Preserve the compact command row, top-level Request/Response/History/Settings navigation, and full-width editor.
- Use restrained semantic surfaces, one system accent, visible focus, and compact density.
- Keep the compact command strip at a fixed size independent of expanded window resizing.
- Use familiar Windows/Linux window and tray behavior without adding platform-specific feature branches.
- Support light mode, dark mode, increased contrast where exposed by Chromium, reduced motion, keyboard navigation, and accessible names.

## Desktop Architecture

### Renderer

React renders the interface and owns transient UI state. It cannot access Node.js, the filesystem, credentials, or generic IPC.

### Preload bridge

A narrow typed bridge exposes only approved Curlman operations. It validates data flowing between the renderer and main process.

### Main process

Electron's main process owns HTTP execution, cancellation, cURL import/export, clipboard and save dialogs, local history, encrypted credentials, preferences, tray lifecycle, window state, and global shortcuts.

The renderer remains sandboxed with context isolation enabled and Node integration disabled. Pasted cURL is parsed as text and is never sent to a shell.

## Platform Behavior

### Windows

- Default global shortcut: `Ctrl+Shift+C`.
- Curlman lives in the notification area and stays out of the taskbar while hidden.
- The release provides a Squirrel installer (`.exe`) and its supporting update package.
- The first unsigned community build may show an Unknown Publisher or SmartScreen warning. This must be disclosed rather than bypassed.

### Linux

- Default global shortcut: `Ctrl+Shift+C`.
- Curlman uses a tray icon where the desktop environment supports AppIndicator/status icons.
- The release provides `.deb`, `.rpm`, and portable packaged output where practical.
- Wayland/global-shortcut and tray behavior varies by desktop environment. Curlman must show a usable window and settings path even when global registration or a tray icon is unavailable.

## Local Data and Security

- History and preferences use Electron's per-user application-data directory.
- History remains independent from the native macOS store.
- Authentication secrets are removed from history snapshots.
- Secrets are encrypted through Electron `safeStorage`; if secure encryption is unavailable, Curlman keeps secrets only for the current session.
- Requests go directly from the user's machine to the destination API.
- No analytics or request data leaves the application.

## Distribution

The repository keeps two installation paths:

### Contributors

```sh
npm install
npm run dev
```

### Users

GitHub Actions builds Windows and Linux on their native runners. A release publishes clearly named artifacts and checksums. The README places Windows and Linux download instructions beside the native macOS DMG and states that initial Electron builds are unsigned community releases.

The first public cross-platform release targets x64. ARM64 installers and paid code-signing services are deferred until there is demonstrated demand.

## Failure Handling

- Invalid cURL, URL, and JSON errors appear near the request workflow without clearing user input.
- Transport failures still create a Response state and History entry.
- Shortcut conflicts retain the last working shortcut and explain the conflict.
- Missing tray support or global shortcut registration cannot make Curlman impossible to reopen or quit.
- Persistence failures are visible and do not silently discard an execution.
- Packaging failures on one operating system do not hide the status of the other build.

## Verification

Local checks:

```sh
npm run typecheck
npm run lint
npm test
npm run package:electron
```

CI must run type checking, linting, tests, and packaging on Windows and Linux. Smoke checks must verify that the packaged application contains its renderer, preload script, SQL.js runtime, icons, and metadata. No automated test calls a production API.

Manual platform checks cover launch, tray menu, quit, shortcut registration, cURL paste, request editing, send/cancel, formatted response, local history, restart persistence, compact mode, and light/dark appearance.

## Acceptance Criteria

- A clean clone starts with `npm install` and `npm run dev` on supported Windows and Linux systems.
- Windows and Linux packages are produced automatically on native CI runners.
- Curlman can always be reopened and quit even when tray or shortcut support is limited.
- The core cURL-to-response workflow and local History work without an account or cloud service.
- The renderer remains sandboxed and no request is executed through a shell.
- README installation instructions and artifact names match the actual release output.
- All Electron checks pass on macOS, Windows, and Linux CI.

## Deferred Work

- Windows Authenticode signing and reputation building.
- Linux repository hosting and package signing.
- ARM64 Windows or Linux artifacts.
- Auto-update infrastructure.
- Platform-specific interface redesigns.
- Cloud synchronization, accounts, collaboration, or telemetry.
