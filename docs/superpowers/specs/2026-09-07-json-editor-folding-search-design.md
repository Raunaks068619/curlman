# Curlman JSON Editor Folding and Search Design

## Goal

Make request and response JSON easier to scan without turning Curlman into a full IDE. The editor must preserve Curlman's native macOS behavior, compact layout, keyboard workflow, and local-only data model.

## Scope

This change adds:

- Stronger visual separation between the line-number gutter and code surface.
- Collapsible JSON objects and arrays in request and response JSON.
- In-editor search for request payloads and response content.
- Keyboard and accessibility support for both features.

This change does not add JSONPath, structural editing, schema validation, replace, regex search, or persisted fold state.

## Chosen Approach

Extend the existing native `NSTextView` and TextKit-based `CodeTextView`. Do not embed CodeMirror, Monaco, `WKWebView`, or another editor dependency.

The editor receives explicit capabilities from its caller:

- `language`: JSON or plain text.
- `isEditable`: request editors are editable; response viewers are read-only.
- `allowsFolding`: enabled only for valid, formatted JSON.
- `allowsSearch`: enabled for request payloads and all response sections.

This keeps one editor vocabulary across request and response while allowing JSON-only behavior to remain conditional.

## Visual Hierarchy

The gutter is a distinct utility surface rather than part of the code text:

- Width: 48 points.
- Background: semantic `underPageBackgroundColor` or the closest system secondary surface.
- Right edge: 0.5-point semantic separator.
- Line numbers: right-aligned, monospaced digits, tertiary label color.
- Fold controls: small SF Symbol disclosure chevrons placed to the left of foldable opening lines.
- Code text begins after a consistent 12-point inset.

The code surface remains opaque and uses the system text background. No decorative gradients, glass, or custom theme palette are introduced.

## JSON Folding

### Fold discovery

A JSON structure scanner identifies matching `{…}` and `[…]` ranges while respecting quoted strings and escaped characters. A range is foldable only when:

- The opening and closing tokens are on different lines.
- The complete document is valid JSON.
- The range contains visible content between its delimiters.

Each fold is identified by the opening delimiter's source offset. Nested folds are supported.

### Interaction

- An expanded fold shows a downward disclosure chevron.
- A collapsed fold shows a right-facing disclosure chevron.
- Clicking the gutter control toggles that fold.
- Folding replaces the hidden interior visually with an inline ellipsis and a compact item count when available, for example `{ … 4 keys }` or `[ … 8 items ]`.
- The underlying bound JSON string never changes when folding or unfolding.
- Editing the request clears affected fold ranges and recomputes fold discovery.
- Loading another request, restoring History, changing body type, changing response section, or reopening the app resets every fold to expanded.
- Invalid JSON shows no folding controls.

Collapsed content remains searchable. Selecting a result inside a collapsed range automatically expands the containing folds before revealing the match.

## Search

### Entry points

- `Command-F` opens the find bar and focuses its field.
- A magnifying-glass button in the editor chrome provides pointer access.
- `Escape` closes the find bar and removes search highlighting.

### Find bar

The find bar appears at the top-right of the editor content, below the request or response section bar. It contains:

- Native search field.
- Current result position and total match count, such as `2 of 7`.
- Previous and next buttons.
- Close button.

The bar is hidden until invoked. It does not permanently reduce editor space.

### Matching behavior

- Literal, case-insensitive substring matching.
- Results update as the query changes.
- Return selects the next match; Shift-Return selects the previous match.
- Every match receives a subtle semantic find highlight.
- The active match uses the stronger selected-text highlight and scrolls into view.
- An empty query shows no count or highlights.
- A query with no matches shows `No matches` without treating it as an application error.

Request and response queries are independent and ephemeral. They are never saved to History or analytics.

## Request Integration

For JSON request bodies:

- Search and folding are enabled when JSON is valid.
- Search remains available for invalid JSON so users can still locate text while correcting it.
- Folding controls disappear when JSON becomes invalid.

For raw request bodies:

- Search is enabled.
- Folding is disabled.

The existing Format action remains in the request section bar.

## Response Integration

- Pretty JSON responses enable search and folding.
- Raw responses and response headers enable search only.
- The existing persistent `Find in response` field is removed to avoid duplicate search interfaces.
- `Command-F` always targets the currently visible response section.

## Accessibility

- Fold buttons expose labels such as `Collapse object on line 6` and `Expand array on line 12`.
- Search controls have explicit labels and keyboard focus order.
- Match position is exposed as accessibility text.
- Gutter separation uses both surface contrast and a separator, not color alone.
- System colors, system font metrics, Increased Contrast, Reduce Transparency, and Light/Dark Mode remain supported.

## Architecture

Keep responsibilities isolated:

1. `JSONStructureScanner` parses structural ranges and item counts without changing the JSON.
2. `CodeEditorSearchController` calculates matches, current selection, highlighting, and navigation.
3. `SyntaxTextEditor.Coordinator` owns transient fold/search state and synchronizes TextKit presentation.
4. `LineNumberGutterView` draws line numbers, the separator, and fold controls, then forwards fold clicks through a callback.
5. `CodeTextView` composes the editor and transient find bar and exposes capability flags to request/response callers.

No fold state or search query enters `HTTPRequestDraft`, `HTTPResponseSnapshot`, History, UserDefaults, or Keychain.

## Error Handling

- Invalid JSON disables fold discovery without showing a new error.
- A stale fold range caused by editing is discarded before layout.
- Search operates on Unicode-safe `NSString` ranges used by TextKit.
- Empty and zero-match searches remain normal interface states.

## Testing

Unit tests cover:

- Nested object and array range discovery.
- Braces and brackets inside quoted and escaped strings.
- Single-line structures excluded from folding.
- Item/key counts for collapsed summaries.
- Case-insensitive search and Unicode range handling.
- Next/previous wraparound.
- Fold reset after source changes.
- A search match expanding its containing folds.

Integration checks cover:

- Request JSON remains unchanged after fold toggles.
- Request and response `Command-F` routing.
- Pretty response folding versus raw/header search-only behavior.
- Empty, invalid JSON, Light Mode, Dark Mode, and keyboard-only operation.

## Acceptance Criteria

- The gutter and code surface are visibly distinct in both system appearances.
- Multiline valid JSON objects and arrays can be folded and unfolded from the gutter.
- Folding never mutates copied, saved, sent, or historically stored payloads.
- Request payloads and response content can be searched with `Command-F`.
- Search reports match count and supports previous/next navigation.
- Search reveals matches inside collapsed JSON.
- All folds reset to expanded when content context changes.
- Existing cURL parsing, request editing, sending, response rendering, and History tests continue to pass.
