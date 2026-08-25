---
name: API Panel
description: A focused native macOS API utility that appears when needed and remembers every request.
---

<!-- SEED: re-run /impeccable document once code exists to capture the actual tokens and components. -->

# Design System: API Panel

## Overview

**Creative North Star: "The Native Instrument"**

API Panel should feel installed with the operating system, not rendered inside it. The interface is compact, information-dense, and predictable. System controls, platform typography, native materials, and progressive disclosure make the tool disappear behind the request being tested.

The visual system rejects Postman-scale chrome, web-dashboard styling, decorative glass cards, fake notch geometry, persistent navigation, and empty output surfaces. Glass exists only where macOS uses material to establish a floating window; technical content remains stable and opaque.

**Key Characteristics:**

- Native system vocabulary
- Restrained information density
- Full-width technical content
- Progressive response and history disclosure
- Fast keyboard-first feedback

## Colors

The application uses semantic macOS colours rather than a stored brand palette. Interface colours resolve from AppKit and SwiftUI system roles at runtime, including the user's chosen accent colour.

**The System Owns Colour Rule.** Never replace system label, background, separator, control, selection, status, or accent roles with a decorative custom palette.

**The Sparse Accent Rule.** Accent appears only on the primary action, current selection, focus, and concise status feedback.

## Typography

**Display Font:** macOS system font
**Body Font:** macOS system font
**Label/Mono Font:** system monospaced design

**Character:** Familiar and precise. SF Pro carries interface hierarchy automatically; SF Mono distinguishes executable and structured content without turning the entire product into a terminal.

### Hierarchy

- **Title** (semibold, system title size): Rare section or settings titles.
- **Body** (regular, system body size): Controls, history rows, explanations, and metadata.
- **Label** (medium or semibold, system caption size): Tabs, field roles, methods, and concise status.
- **Technical** (regular, system monospaced body size): URLs, curl input, JSON, raw response bodies, and headers.

**The One Interface Family Rule.** Never introduce a display face, branded typeface, or custom UI font.

## Elevation

The system uses a hybrid of native vibrancy and tonal layering. The floating panel receives the system window shadow and a subtle half-point edge. Content surfaces are flat and separated with semantic backgrounds or separators. Cards are not an elevation primitive.

**The Glass Boundary Rule.** Vibrancy belongs to the panel shell, global toolbar, top-level tabs, compact command strip, progress overlays, and toasts. JSON, response, auth, and long history surfaces remain opaque.

## Components

### Buttons

- **Shape:** Native macOS control geometry.
- **Primary:** System-accent Send action with semantic disabled and loading states.
- **Hover / Focus:** Native focus ring, pointer feedback, and immediate state transition.
- **Secondary:** System material or borderless toolbar action, chosen by hierarchy rather than decoration.

### Cards / Containers

- **Corner Style:** No generic card system. The floating panel uses native window curvature.
- **Background:** System material for chrome and opaque semantic surfaces for technical content.
- **Shadow Strategy:** Only the floating panel and true transient overlays cast shadows.
- **Border:** Half-point semantic edge only when required for definition.
- **Internal Padding:** Compact system spacing aligned to an 8-point rhythm.

### Inputs / Fields

- **Style:** Native macOS controls for methods, URLs, parameters, headers, and authentication.
- **Focus:** System accent focus ring and clear keyboard focus.
- **Error / Disabled:** Semantic text and accessibility values accompany colour.

### Navigation

Request, Response, and History are top-level tabs. Response exists only after an execution result. History is never a persistent sidebar. Secondary Request sections use native segmented or tab controls.

### Floating Panel

The panel originates from the top-right work area, remains draggable and resizable, and can close to the menu bar or minimize into a compact command strip. Its top chrome provides a clear drag region without imitating a notch.

## Do's and Don'ts

### Do:

- **Do** use macOS system fonts, semantic colours, system accent, and native materials.
- **Do** keep the Request editor full width until a response exists.
- **Do** create a full-width Response tab after execution.
- **Do** keep History in an on-demand top-level tab.
- **Do** use 150 to 250 millisecond state transitions with Reduce Motion support.
- **Do** keep every primary action reachable by keyboard.

### Don't:

- **Don't** reproduce Postman-scale chrome, persistent sidebars, collection trees, or workspace complexity.
- **Don't** reproduce Bruno's manual-save behavior or allow executed requests to disappear.
- **Don't** render empty response panes, decorative placeholders, dashboards, or permanent split views before content exists.
- **Don't** use web-dashboard styling, custom theme palettes, neon developer-tool aesthetics, or decorative glass cards.
- **Don't** draw a fake notch silhouette or anchor content to physical notch geometry.
- **Don't** place glass behind JSON, response bodies, authentication fields, or long history lists.
