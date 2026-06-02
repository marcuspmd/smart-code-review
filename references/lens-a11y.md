# Accessibility (A11y) Lens

Apply when the diff touches: HTML templates, JSX/TSX components, CSS, ARIA attributes, form elements, modals, navigation, dynamic content, or interactive widgets.

**Skip entirely** when the diff has no UI-layer changes (pure backend, CLI, migrations, etc.).

Baseline standard: **WCAG 2.1 AA**.

## Images and Icons

- All `<img>` elements have meaningful `alt` text. Decorative images use `alt=""`.
- Icon-only buttons and links have `aria-label` or visually-hidden text (not just a tooltip).
- Interactive SVGs have `role="img"` and `aria-label`. Decorative SVGs have `aria-hidden="true"`.

## Forms and Inputs

- Every `<input>`, `<select>`, `<textarea>` has an associated `<label>` (via `for`/`id` or `aria-label` or `aria-labelledby`). Placeholder text alone does not count as a label.
- Required fields use the `required` attribute AND communicate it visually (not only via color).
- Error messages are programmatically associated with their field via `aria-describedby`.
- `autocomplete` attribute matches the field's purpose (`"email"`, `"current-password"`, `"name"`, etc.).
- Disabled fields use `disabled` attribute — not just visual styling.

## Keyboard Navigation

- All interactive elements are reachable and operable via keyboard alone (Tab, Enter, Space, Arrow keys).
- No keyboard focus traps outside of modals/dialogs (which must trap focus while open and restore it on close).
- Custom interactive widgets (`div`, `span` with click handlers) have the appropriate `role` attribute and `tabindex="0"`.
- Focus is managed explicitly on: modal open/close, route changes, dynamic section inserts.
- `tabindex` values greater than 0 are avoided (they break natural tab order).

## Focus Visibility

- Focus indicators are visible. `outline: none` / `outline: 0` without a replacement style is a P1.
- Focus ring is visible against both light and dark backgrounds.

## Color and Contrast

- Normal text (< 18pt / < 14pt bold): contrast ratio ≥ 4.5:1.
- Large text (≥ 18pt / ≥ 14pt bold): contrast ratio ≥ 3:1.
- UI components and graphical objects: contrast ratio ≥ 3:1.
- Information is never conveyed by color alone — always paired with text, icon, pattern, or shape.

## ARIA

- `aria-*` attributes match the element's role — verify role/property/state compatibility (e.g., `aria-checked` only on `checkbox`, `menuitemcheckbox`, `option`, `radio`, `switch`, `treeitem`).
- `aria-hidden="true"` is never applied to focusable elements.
- Dynamic content that updates without a page reload announces changes via `aria-live` region (`polite` for non-urgent, `assertive` for critical alerts only).
- Modals and dialogs: `role="dialog"`, `aria-modal="true"`, `aria-labelledby` pointing to the dialog title.
- Avoid redundant ARIA that duplicates native HTML semantics (e.g., `<button role="button">`).
- `aria-label` on interactive elements is not an empty string.

## Semantic HTML

- Heading hierarchy is logical (`h1` → `h2` → `h3`) with no levels skipped.
- Lists use `<ul>` / `<ol>` / `<dl>` — not styled `<div>` or `<span>` sequences.
- `<button>` triggers actions; `<a href>` navigates — these are not interchangeable.
- `<table>` data tables have `<th scope="col">` or `<th scope="row">` headers; layout tables use `role="presentation"`.
- `<main>`, `<nav>`, `<header>`, `<footer>`, `<aside>` landmarks are used appropriately.

## Dynamic Content and State

- Loading states (spinners, skeletons) communicate status to screen readers via `aria-busy` or a live region.
- Toast notifications and alerts use `role="alert"` or `aria-live="polite"`.
- Tooltips and popovers are accessible without hover — also triggered by focus, or via an explicit button.
- Async updates that replace content announce the change (don't silently swap DOM nodes).

## Motion and Animation

- Animations respect `prefers-reduced-motion: reduce` media query.
- No content flashes more than 3 times per second (seizure risk).
- Auto-playing video or audio either has a pause control or does not auto-play.

## Severity Guide

| Severity | Example |
|---|---|
| P1 | Input without label; interactive element unreachable by keyboard; `outline: none` with no replacement; form errors not associated with fields |
| P2 | Missing `aria-live` on dynamic updates; incorrect ARIA roles; focus not restored on modal close; color as only error indicator |
| P3 | Contrast ratio marginally below threshold; redundant ARIA; non-critical heading order issue |
