<p align="center">
  <img src="Brand/Curlman-Icon.png" alt="Curlman icon" width="160">
</p>

<h1 align="center">Curlman</h1>

<p align="center">
  A fast, local-first desktop API client built around cURL.
</p>

<p align="center">
  <a href="https://github.com/Raunaks068619/curlman/releases/latest/download/Curlman.dmg"><strong>⬇ Download Curlman for macOS (.dmg)</strong></a>
</p>

<p align="center">
  <a href="https://github.com/Raunaks068619/curlman/actions/workflows/ci.yml"><img src="https://github.com/Raunaks068619/curlman/actions/workflows/ci.yml/badge.svg" alt="Build status"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-1d1d1f" alt="macOS 14 or newer">
  <img src="https://img.shields.io/badge/Apple%20Silicon-native-007aff" alt="Native Apple Silicon app">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-34c759" alt="MIT License"></a>
</p>

Curlman turns pasted cURL commands into editable requests, formatted responses, and automatic local history. Use the native macOS menu-bar app or run the consistent Electron app on macOS, Windows, and Linux.

## Run the cross-platform app

Install [Node.js 22.12 or newer](https://nodejs.org/), then run:

```sh
npm install
npm run dev
```

That is all contributors need for local development. The first install downloads Electron and the project dependencies. Curlman opens as a tray/menu-bar app and does not occupy the Dock or taskbar.

## See it in action

<p align="center">
  <a href="https://github.com/Raunaks068619/curlman/releases/download/v0.2.0/Curlman-POST-Demo.mp4">
    <img src="Media/Curlman-POST-Demo.gif" alt="Testing a POST API with Curlman" width="720">
  </a>
</p>

Paste a POST request as cURL, adjust it if needed, and get a formatted response in seconds. Click the preview for the full-quality video.

## Download

### [Download the latest Curlman DMG](https://github.com/Raunaks068619/curlman/releases/latest/download/Curlman.dmg)

1. Open `Curlman.dmg`.
2. Drag **Curlman** into Applications.
3. On first launch, Control-click the app and choose **Open**, then confirm **Open**.

The current public build is ad-hoc signed but not Apple-notarized. The Control-click step is required only for the first launch.

## Features

- Import multiline cURL commands into editable requests.
- Edit method, URL, query params, headers, JSON or raw body, and authentication.
- Copy the current edited request back to a runnable cURL command.
- Send with Command-Return and inspect a full-width formatted response.
- Automatically retain request and response history without manual saving.
- Restore, rerun, pin, search, and remove history entries.
- Minimize into a fixed compact command strip.
- Choose a custom global shortcut from Settings without losing the previous shortcut on conflicts.
- Follow the operating system’s Light Mode, Dark Mode, font, and accessibility preferences.
- Keep API traffic direct and local through the native network stack.

## Native macOS build

- Apple Silicon Mac
- macOS 14 or newer
- Xcode 15 or newer for source builds

Build and test the native Swift app:

```sh
swift test
./scripts/build-release.sh
```

The release script creates `Curlman.app` and `Curlman.dmg` in `outputs/`.

## Electron checks and packages

```sh
npm run typecheck
npm run lint
npm test
npm run package:electron
```

Electron source lives in `apps/electron`. GitHub Actions runs its checks on macOS, Windows, and Linux.

## Use

1. Launch Curlman.
2. Press Command-Shift-C from any application to show or hide it, or choose a different shortcut in Settings.
3. Enter an HTTP URL or paste a curl command into the URL field.
4. Edit Body, Params, Headers, or Auth.
5. Press Command-Return to send.
6. Inspect the full-width Response tab.
7. Open History to restore any previous attempt.

The close control hides the panel to the menu bar. The minimize control collapses it into a compact command strip. Quit from the menu-bar menu to stop the app.

## Privacy

Requests execute directly through `URLSession` in the native app or the Electron main process in the cross-platform app. Pasted cURL commands are parsed and never passed to a shell. Request history stays local. Bearer tokens and Basic-auth passwords are removed from persisted history snapshots and stored with macOS Keychain or Electron's encrypted `safeStorage` vault.

Copying a request as cURL intentionally places its current authentication values on the system clipboard so the command remains runnable.

## License

Curlman is available under the [MIT License](LICENSE).
