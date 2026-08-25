<p align="center">
  <img src="Brand/Curlman-Icon.png" alt="Curlman icon" width="160">
</p>

<h1 align="center">Curlman</h1>

<p align="center">
  A fast, local-first macOS API client built around cURL.
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

Curlman lives in the macOS menu bar. Press Command-Shift-C from anywhere, paste a cURL command, edit the request, send it, inspect the formatted response, and recover every previous attempt from automatic local history.

## See it in action

<p align="center">
  <a href="https://github.com/Raunaks068619/curlman/releases/download/v0.1.0/Curlman-POST-Demo.mp4">
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
- Follow macOS Light Mode, Dark Mode, accent color, and accessibility preferences.
- Keep API traffic direct and local through `URLSession`.

## Requirements

- Apple Silicon Mac
- macOS 14 or newer
- Xcode 15 or newer for source builds

## Build and Test

```sh
swift test
./scripts/build-release.sh
```

The release script creates `Curlman.app` and `Curlman.dmg` in `outputs/`.

## Use

1. Launch Curlman.
2. Press Command-Shift-C from any application to show or hide it.
3. Enter an HTTP URL or paste a curl command into the URL field.
4. Edit Body, Params, Headers, or Auth.
5. Press Command-Return to send.
6. Inspect the full-width Response tab.
7. Open History to restore any previous attempt.

The close control hides the panel to the menu bar. The minimize control collapses it into a compact command strip. Quit from the menu-bar menu to stop the app.

## Privacy

Requests execute directly from the Mac through `URLSession`. Pasted curl commands are parsed and never passed to a shell. Request history stays local. Bearer tokens and Basic-auth passwords are saved in macOS Keychain and removed from persisted history snapshots.

Copying a request as cURL intentionally places its current authentication values on the macOS clipboard so the command remains runnable.

## License

Curlman is available under the [MIT License](LICENSE).
