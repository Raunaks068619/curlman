# API Panel macOS App Design

Date: 2026-08-25

## Product Definition

API Panel is a local-first, native macOS menu-bar utility for quickly importing, editing, executing, and revisiting HTTP API requests. The first release targets Apple Silicon Macs running macOS 14 or newer. `API Panel` is the working product and bundle name for this implementation.

The app must feel like a system utility: it appears immediately when invoked, stays out of the Dock, preserves the user's work, and gets out of the way without quitting.

## First-Release Scope

The first release supports:

- HTTP methods GET, POST, PUT, PATCH, DELETE, HEAD, and OPTIONS.
- Importing common curl commands into an editable request model.
- URL and query-parameter editing.
- Header editing.
- JSON and raw-text request bodies.
- Bearer-token and Basic authentication.
- Request execution with Command-Return.
- Pretty, raw, and header response views.
- Automatic durable history for successful requests, HTTP errors, transport failures, and cancelled requests.
- Pinning and naming important history records.
- Native Light Mode, Dark Mode, Increased Contrast, Reduce Motion, and user accent-colour support.

Collections, environments, variables, scripts, GraphQL-specific tooling, multipart upload, OAuth flows, client certificates, proxies, cookie management, and cloud synchronization are outside the first release.

## Application Lifecycle

The app is an `LSUIElement` menu-bar application and never shows a Dock icon. Its menu-bar menu exposes Open Panel, New Request, History, Settings, and Quit.

Command-Shift-C is registered as a system-wide hotkey using the native Carbon hotkey API. It toggles the panel from any application without requiring Accessibility permission. If registration fails because another application owns the shortcut, the menu-bar menu reports the conflict and keeps mouse-based opening available.

The red close control hides the panel while leaving the menu-bar process running. Escape performs the same hide action. The yellow minimize control collapses the panel into a compact command strip. Command-Shift-C restores or hides the panel from either expanded or compact state. Only Quit from the menu-bar menu terminates the application.

## Window and Motion

The main surface is a borderless AppKit `NSPanel` hosting SwiftUI content. It initially appears immediately below the top-right menu-bar area with a small screen-edge margin. It does not imitate or attach to the MacBook notch.

The panel:

- Opens with a restrained fade, scale, and downward translation from the top-right origin.
- Floats above normal application windows without stealing focus unnecessarily.
- Becomes key when the user invokes it so the URL field is ready for typing or paste.
- Is draggable from unoccupied top-toolbar regions.
- Is resizable from every edge with a default size of 780 by 520 points and a minimum size of 600 by 400 points.
- Persists expanded size, expanded position, and compact state.
- Repositions into the visible screen frame if the stored display is disconnected.
- Collapses to an approximately 360 by 46 point compact command strip when minimized.

Motion uses transform and opacity changes lasting 150 to 250 milliseconds with an ease-out curve. Reduce Motion replaces translation and scale with a short crossfade.

## Visual System

All interface typography uses SwiftUI system fonts. Technical text uses the system monospaced design, which resolves to SF Mono on macOS. No bundled font is required.

The app uses semantic SwiftUI and AppKit colours, including primary and secondary labels, window and text backgrounds, separators, controls, selection, and the user's system accent. Response statuses use semantic system green, orange, and red roles. There is no custom theme selector.

Native vibrancy is intentionally limited to the floating panel shell, URL toolbar, top-level tab strip, compact command strip, progress overlays, and toasts. These surfaces use `NSVisualEffectView` system materials with behind-window blending. JSON editors, response bodies, authentication fields, and long history lists use opaque semantic surfaces for legibility. The panel uses a subtle half-point edge and layered native shadow rather than decorative borders or cards.

The app follows Light Mode, Dark Mode, Increased Contrast, Reduce Transparency, and Reduce Motion automatically.

## Information Architecture

The expanded panel has a sparse global toolbar followed by top-level content tabs.

### Global Toolbar

The toolbar contains:

- Close and minimize controls.
- HTTP method picker.
- URL or curl input field.
- Send or Cancel button with the Command-Return shortcut hint.

Pasting a curl command into the URL field triggers safe parsing and populates the request editor. Pasting a normal URL changes only the URL.

### Request Tab

The Request tab is the default and uses the complete content width. It contains secondary controls for Body, Params, Headers, and Auth.

Before a request has completed, the top-level tabs are Request and History. There is no empty response pane, response placeholder, or response illustration.

### Response Tab

After execution finishes, a Response tab is inserted between Request and History and selected automatically. It uses the complete panel width and shows:

- HTTP or transport status.
- Duration and response size.
- Pretty body, raw body, and response headers.
- Copy and save actions.
- Search within the response.

The latest response remains available while the same request is edited. Creating a new request removes the Response tab. Restoring a history record recreates the Response tab when that record has a stored response.

### History Tab

History is a top-level tab, never a permanent sidebar. It provides:

- Search by name, URL, method, and status.
- Filters for all, successful, failed, and pinned records.
- Method, URL or name, status, duration, timestamp, and pin state in each row.
- One-click restore into the Request tab.
- Access to a stored response through the Response tab.
- Rename, pin, delete, and clear-all actions.

## Request Model and Curl Import

The editable request model has stable identifiers and separate fields for method, base URL, query items, headers, body kind, body text, and authentication configuration.

The curl importer tokenizes input without invoking a shell. It handles quoted values, escaped characters, line continuations, and these common curl options:

- `-X` and `--request`
- `-H` and `--header`
- `-d`, `--data`, `--data-raw`, and `--data-binary`
- `-u` and `--user`
- `--url`
- `-G` and `--get`
- URLs and query strings

Unsupported flags never execute. The importer lists them in a non-blocking warning so the user can verify the resulting request. Bruno's curl-import behavior and public tests may be used as behavioral references. Substantially adapted MIT-licensed code requires its copyright and license notice; otherwise the parser will be implemented independently in Swift from the documented behavior.

## JSON and Text Editing

The body and response editors are native `NSTextView`-based components wrapped for SwiftUI. They provide:

- System monospaced typography.
- Line numbers.
- JSON syntax colouring using semantic system colours.
- Live JSON validation with a precise line and column error.
- Format JSON through a toolbar action and Command-Shift-F.
- Standard selection, copy, undo, redo, find, and keyboard navigation.
- Horizontal and vertical scrolling for large payloads.

Formatting uses `JSONSerialization` with stable pretty-print indentation. Invalid JSON is never silently changed.

## Networking

`URLSession` executes requests asynchronously. The app does not send pasted text through a shell and does not execute arbitrary commands. This protects against shell injection while preserving native connection pooling and cancellation.

The execution pipeline is:

1. Validate the URL and current request configuration.
2. Create a pending history record with a sanitized request snapshot.
3. Resolve required credentials from Keychain.
4. Build and execute a `URLRequest` with `URLSession`.
5. Collect status, headers, body bytes, duration, and transfer size.
6. Finalize the history record as success, HTTP error, transport failure, or cancellation.
7. Insert and select the Response tab.

The Send button becomes Cancel while a request is in flight. A compact native progress indicator appears in the toolbar. Starting another execution cancels the current task only after explicit user action.

## History and Persistence

SwiftData stores drafts, window preferences, and immutable history records in the app's Application Support container. Every execution attempt is saved automatically, including failures and cancellations. History records do not expire automatically.

Each history record stores:

- A sanitized request snapshot.
- Creation and completion timestamps.
- Result category and HTTP status when available.
- Duration and byte counts.
- Response headers.
- Up to 2 MB of response body data by default.
- A truncation marker when the response exceeds the stored-body limit.
- Optional user name and pinned state.

The settings view reports history disk usage and offers response-body limits of 512 KB, 2 MB, 10 MB, or metadata only. Changing the limit affects future records. Users can delete individual records or clear all history after confirmation.

Bearer tokens, Basic passwords, and imported Authorization values are never stored directly in SwiftData. They are saved in macOS Keychain under request-specific identifiers. Sanitized history snapshots retain credential references and non-secret auth metadata so reruns can resolve the credential locally. Clearing all app data offers a separate option to remove related Keychain entries.

## Errors and Edge Cases

- Invalid URLs keep focus in the URL field and show an inline explanation.
- Invalid JSON blocks sending only when the body kind is JSON; raw bodies remain unrestricted.
- Unsupported curl flags produce a warning but preserve all successfully parsed fields.
- HTTP 4xx and 5xx responses are valid responses, create the Response tab, and are stored in history.
- DNS, TLS, timeout, cancellation, and offline failures create a full-width Response tab with a concise diagnostic and retry action.
- Binary responses show metadata and a safe preview when possible, plus Save to File.
- Very large live responses remain viewable without requiring the entire formatted representation to be stored in history.
- The app never logs authorization values in console output or persisted diagnostics.

## Accessibility and Keyboard Behavior

Primary shortcuts are:

- Command-Shift-C: toggle the global panel.
- Command-Return: send request.
- Escape: hide panel or dismiss the active transient UI.
- Command-N: new request.
- Command-1: Request tab.
- Command-2: Response tab when available.
- Command-3: History tab.
- Command-F: search the active editor or history list.
- Command-Shift-F: format JSON in the active editable body.
- Command-comma: settings.

All controls expose accessibility labels, help text, focus order, keyboard activation, and sufficient hit targets. Status is communicated through text and accessibility values, not colour alone.

## Internal Structure

The project is divided into focused units:

- `App`: lifecycle, menu-bar item, commands, dependency wiring.
- `Panel`: `NSPanel` construction, positioning, dragging, resizing, minimize, restore, and animation.
- `HotKey`: Carbon registration and shortcut conflict reporting.
- `RequestModel`: editable request domain types and validation.
- `CurlImport`: tokenizer, parser, warnings, and tests.
- `Networking`: request construction, execution, cancellation, and response decoding.
- `Persistence`: SwiftData models, repositories, migrations, response-body storage policy.
- `Security`: Keychain credential storage and sanitized snapshots.
- `Features/Request`: toolbar and request editors.
- `Features/Response`: response summary and viewers.
- `Features/History`: search, filters, restore, pin, and deletion.
- `SharedUI`: vibrancy bridge, system text editor, syntax highlighting, and reusable native controls.

Views depend on observable feature models. Feature models depend on protocols for networking, persistence, and credentials. Concrete services are injected at the application boundary so parser, networking, and history behavior can be tested independently.

## Verification

Automated tests cover:

- Curl tokenization, quoting, multiline input, supported flags, and unsupported-flag warnings.
- URL, query, header, body, and authentication request construction.
- Credential sanitization and Keychain reference behavior.
- History creation and finalization for success, HTTP error, timeout, offline, cancellation, and truncated response bodies.
- Response-tab lifecycle and history restoration.
- Window position recovery when screen geometry changes.

Integration tests use a local HTTP fixture server for deterministic request and response cases. UI tests cover global launch through an injectable hotkey action, send through Command-Return, tab navigation, history restore, close, minimize, and restore.

Manual verification covers Light and Dark Mode, Increased Contrast, Reduce Transparency, Reduce Motion, multiple displays, compact resizing, menu-bar-only lifecycle, and installation from the packaged application.

## Packaging

The deliverable is a locally installable Apple Silicon `.app` bundle and a DMG containing the app plus an Applications-folder shortcut. The first local build may use ad-hoc signing. Distribution outside the user's Mac would require a Developer ID signature and Apple notarization, which are not part of this local first release.

## Acceptance Criteria

The design is complete when all of the following are true:

1. Command-Shift-C opens a focused panel from the top-right area while the app remains absent from the Dock.
2. The panel can be dragged, resized, closed to the menu bar, minimized to a compact strip, and restored.
3. A pasted supported curl command becomes an editable native request without shell execution.
4. Params, headers, body, and auth can be edited, and JSON offers native formatting and validation.
5. Command-Return executes the request and creates a full-width Response tab only after completion.
6. Responses expose status, duration, size, pretty body, raw body, and headers.
7. Every attempt is stored automatically in a searchable History tab and can be restored.
8. Credentials are stored in Keychain and are absent from history data and logs.
9. The interface uses system fonts, semantic colours, native vibrancy, and accessibility settings.
10. The app builds, launches, passes automated tests, and is provided as a locally installable `.app` and DMG.
