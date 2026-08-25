# API Panel Native macOS Implementation Plan

Date: 2026-08-25
Design: `docs/superpowers/specs/2026-08-25-api-panel-design.md`

## Delivery Strategy

Build a dependency-light Swift 6 application as a Swift Package, then assemble the release binary and resources into a standard `API Panel.app` bundle. Keep domain logic independent from AppKit and SwiftUI so curl parsing, request construction, persistence sanitization, and history behavior are testable with `swift test`.

## Phase 1: Project and Application Shell

1. Create `Package.swift` targeting macOS 14 and Apple Silicon.
2. Add the `APIPanel` executable target, test target, resources, and strict concurrency-safe boundaries where practical.
3. Create the SwiftUI application entry point and `NSApplicationDelegate` lifecycle.
4. Configure activation policy and `LSUIElement` behavior so the app stays out of the Dock.
5. Create an `NSStatusItem` menu with Open Panel, New Request, History, Settings, and Quit.
6. Implement the Carbon global shortcut registrar for Command-Shift-C with conflict reporting.
7. Add packaging scripts that build release code, construct `API Panel.app`, ad-hoc sign it, and produce a DMG.

Verification:

- The package compiles.
- The app launches as a menu-bar process.
- No Dock icon appears.
- Command-Shift-C toggles a placeholder panel.

## Phase 2: Domain Model and Curl Import

1. Define request method, query item, header, body kind, authentication, editable request, response, transport failure, and history snapshot types.
2. Implement request validation without UI dependencies.
3. Implement a shell-safe curl tokenizer for quotes, escapes, and line continuations.
4. Implement supported curl option parsing and unsupported-option warnings.
5. Ensure imported Authorization values are represented as credentials rather than persisted headers.
6. Add parser fixtures covering GET, POST JSON, headers, Basic auth, Bearer auth, multiline commands, query strings, and unsupported flags.

Verification:

- Parser tests pass.
- No parser path invokes a shell or `Process`.
- Imported curl data round-trips into the request model predictably.

## Phase 3: Networking and Security

1. Build `URLRequest` values from the editable domain model.
2. Resolve Bearer and Basic credentials through a credential-store protocol.
3. Implement a Keychain-backed credential store using the Security framework.
4. Implement async `URLSession` execution with cancellation, duration, headers, status, body bytes, and MIME metadata.
5. Add safe text, JSON, and binary response classification.
6. Ensure secrets are absent from descriptions, persisted snapshots, and diagnostics.

Verification:

- Unit tests cover request construction and redaction.
- Integration tests use a local HTTP fixture server.
- Cancellation and transport errors return structured results.

## Phase 4: History and Settings

1. Define SwiftData models for history records and application preferences.
2. Create a history repository with start, finalize, search, filter, pin, rename, delete, and clear operations.
3. Store pending records before network execution and finalize every outcome.
4. Enforce the configured response-body storage limit and truncation marker.
5. Persist window geometry and compact state through typed preferences.
6. Add settings for response-body limit, history usage, global shortcut status, and clearing data.

Verification:

- Repository tests use an in-memory SwiftData container.
- Failed and cancelled requests remain visible in history.
- Secret fields never appear in the persistent model.

## Phase 5: Panel and Window Behavior

1. Create a borderless, resizable, floating `NSPanel` with a SwiftUI host view.
2. Position it under the top-right visible screen frame on first launch.
3. Implement show, hide, compact minimize, restore, drag regions, edge resizing, and stored geometry recovery.
4. Implement the restrained top-right appearance transition and Reduce Motion fallback.
5. Bridge `NSVisualEffectView` for system vibrancy on panel chrome only.
6. Add native-style close and minimize controls with the approved behaviors.

Verification:

- The panel behaves correctly across launch, close, minimize, restore, and screen changes.
- Minimum and default sizes match the design.
- Reduce Transparency and Reduce Motion remain usable.

## Phase 6: Request, Response, and History Interface

1. Build the glass global toolbar with method picker, URL/curl field, and Send or Cancel action.
2. Build top-level Request and History tabs.
3. Build Body, Params, Headers, and Auth request sections.
4. Create the native `NSTextView` editor bridge with line numbers, JSON colouring, formatting, validation, find, undo, and scrolling.
5. Insert and select the full-width Response tab only after an execution result exists.
6. Build Pretty, Raw, and Headers response sections with copy, save, and search.
7. Build searchable, filterable history with restore, pin, rename, delete, and clear controls.
8. Add keyboard commands and accessibility labels.

Verification:

- Input uses full width before execution.
- Response uses full width after execution.
- Restoring history reconstructs request and response state.
- Light, Dark, Increased Contrast, and system accent settings work.

## Phase 7: End-to-End Hardening and Packaging

1. Exercise sample public and local APIs with GET, POST, HTTP error, timeout, and malformed JSON cases.
2. Verify the global shortcut from other applications.
3. Verify no Dock presence and correct menu-bar lifetime.
4. Run all unit and integration tests.
5. Build the release application bundle.
6. Ad-hoc sign the local build.
7. Create and mount-test the DMG.
8. Save user-facing artifacts in `outputs/` and write concise install and usage instructions.

Final artifacts:

- `API Panel.app`
- `API-Panel.dmg`
- Test report and known limitations

## Deferred Cross-Platform Port

After the native release is validated, preserve the domain behavior and visual contract while creating an Electron implementation for macOS, Windows, and Linux. The Electron port is a separate project phase and does not change this native delivery.
