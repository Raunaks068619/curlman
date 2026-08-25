# API Panel Brand Icon Design

## Approved direction

API Panel uses a C-centric application icon because cURL import is the product's primary entry point. The dominant route-shaped C communicates cURL without adding a wordmark. A moving parcel carries a chain-link URL symbol through the opening, while the route endpoints and completion check suggest a successful API request and response.

## Visual treatment

- Native macOS rounded-square application-icon silhouette.
- Cobalt background with cool graphite depth and cyan highlights.
- One dominant C, one URL parcel, a directional arrow, and a completion endpoint.
- Dimensional enough for Finder and the Dock, with no decorative text or developer-tool clichés.
- The menu-bar item remains a monochrome system symbol for legibility at small sizes and under every system appearance.

## Deliverables

- A committed high-resolution PNG source.
- A build-generated multi-resolution `AppIcon.icns` embedded in the app bundle.
- The icon shown in the project README.
- Refreshed application and DMG artifacts.

## Verification

- Confirm the source is square and includes alpha.
- Confirm the generated iconset includes every required 1x and 2x macOS size.
- Verify the signed app bundle contains `Contents/Resources/AppIcon.icns` and declares it through `CFBundleIconFile`.
- Launch the installed app and confirm Finder and macOS resolve its bundle icon.
