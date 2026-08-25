# API Panel

API Panel is a local-first native macOS menu-bar utility for importing curl commands, editing HTTP requests, inspecting full-width responses, and automatically retaining request history.

## Requirements

- Apple Silicon Mac
- macOS 14 or newer
- Xcode 15 or newer for source builds

## Build and Test

```sh
swift test
./scripts/build-release.sh
```

The release script creates `API Panel.app` and `API-Panel.dmg` in `outputs/`.

## Use

1. Launch API Panel.
2. Press Command-Shift-C from any application to show or hide it.
3. Enter an HTTP URL or paste a curl command into the URL field.
4. Edit Body, Params, Headers, or Auth.
5. Press Command-Return to send.
6. Inspect the full-width Response tab.
7. Open History to restore any previous attempt.

The close control hides the panel to the menu bar. The minimize control collapses it into a compact command strip. Quit from the menu-bar menu to stop the app.

## Privacy

Requests execute directly from the Mac through `URLSession`. Pasted curl commands are parsed and never passed to a shell. Request history stays local. Bearer tokens and Basic-auth passwords are saved in macOS Keychain and removed from persisted history snapshots.
