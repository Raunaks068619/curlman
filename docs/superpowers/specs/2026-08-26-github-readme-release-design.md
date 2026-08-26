# Curlman GitHub README and Release Design

## Goal

Make the repository immediately understandable and runnable for developers who discover Curlman on GitHub. Present the native macOS and cross-platform Electron editions as equal choices, while keeping the fastest installation path prominent for each audience.

## Audience

- macOS users who want a downloadable menu-bar API client.
- macOS, Windows, and Linux users who want to run the Electron edition from source.
- Contributors evaluating the project structure, test commands, and packaging workflow.

## README structure

1. Centered Curlman icon, name, concise product statement, and project badges.
2. Demo GIF with a direct link to the full-quality POST request video.
3. A “Choose your edition” comparison showing native macOS and Electron as equal options.
4. Native macOS download and first-launch instructions.
5. Cross-platform Electron quick start using `npm install` and `npm run dev`.
6. A short workflow explaining paste, edit, send, response, and automatic history.
7. Supported request editing and cURL import behavior.
8. Keyboard shortcuts and compact-panel behavior.
9. Local-first privacy and credential-storage explanation.
10. Development, testing, and packaging commands.
11. Current limitations, signing status, contribution guidance, and license.

## Edition positioning

| Native macOS | Electron |
| --- | --- |
| Swift and SwiftUI | Electron, React, and TypeScript |
| macOS 14+, Apple Silicon | macOS, Windows, and Linux |
| Distributed as a DMG | Run from source with Node.js |
| Native menu-bar panel and Keychain | Consistent tray UI and encrypted safeStorage |

Neither edition is described as secondary. The native edition is the direct-download path on macOS; Electron is the cross-platform path for users and contributors.

## Release contents

- Tag and GitHub release: `v0.2.5`.
- Updated native `Curlman.dmg`, aligned to product version 0.2.5.
- SHA-256 checksum for the DMG.
- Full-quality POST demo video attached to the release.
- Source archives generated automatically by GitHub.
- Release notes summarizing cURL parsing, automatic history, editable requests, formatted responses, compact mode, custom shortcuts, copy-as-cURL, Electron support, and recent focus/tray fixes.

## Links

README download links use GitHub’s `releases/latest/download` URL so future releases do not require README edits. Repository-relative links are used for source-controlled images, license, and project documentation.

## Tone and presentation

The README is concise, technical, and trustworthy. It avoids marketing superlatives and explains security or platform limitations plainly. The demo and quick-start commands appear before architecture details. Emoji usage is limited to section cues where it improves scanning.

## Verification

- Render-check the README structure and relative assets.
- Run Swift tests and produce the native release bundle.
- Run Electron typecheck, lint, tests, and package verification.
- Confirm the DMG and demo video exist and calculate the DMG checksum.
- Push the README, version alignment, release artifacts metadata, and tag.
- Publish the GitHub release and confirm the latest-download DMG URL resolves.

## Out of scope

- Notarization or Apple Developer ID signing.
- Prebuilt Electron installers for Windows or Linux.
- Package-manager distribution through Homebrew, Winget, Snap, or Flatpak.
