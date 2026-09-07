# Curlman JSON Editor Folding and Search Implementation Plan

## Objective

Implement the approved native JSON editor improvements without adding a web editor or third-party dependency.

## Implementation Steps

1. Add a pure `JSONStructureScanner` that discovers nested multiline object and array ranges, line numbers, and item counts while respecting JSON strings and escapes.
2. Add scanner unit tests for nesting, quoted delimiters, single-line exclusion, invalid JSON, and counts.
3. Extend `CodeTextView` with an explicit content language and folding/search capabilities.
4. Upgrade the gutter to a 48-point semantic utility surface with a half-point separator, line numbers, fold chevrons, hover feedback, hit testing, and accessibility descriptions.
5. Add a TextKit layout manager that hides folded glyph ranges without mutating the underlying text and substitutes a visible ellipsis at each collapsed range.
6. Reset transient fold state when source context changes, and automatically expand a containing fold when selection or search targets hidden content.
7. Enable native `NSTextFinder` search, expose it through a compact magnifying-glass control, preserve `Command-F`, and remove the non-functional response search field.
8. Configure request JSON for search and folding, raw requests for search only, pretty JSON responses for search and folding, and raw/header responses for search only.
9. Run focused scanner/editor tests, the full Swift suite, and live Light/Dark Mode interaction checks.
10. Version, sign, notarize, publish, update the Homebrew cask, and install the verified native build.

## Verification Gates

- Folding never changes the bound request or response string.
- Invalid JSON never exposes fold controls.
- Search works in request and response editors and uses native match navigation.
- Fold controls and gutter remain legible in both system appearances.
- All existing request, response, History, parsing, and packaging tests remain green.
