# Keyboard design

This document describes the implemented keyboard. The [prototype](spec/hex7x4.html) is authoritative only for shared values enforced by `scripts/check-spec-parity.py`: letter orders, symbol slots, punctuation choices, default swipe distance and hold duration, and the delete-repeat formula. Its other geometry, popup, and interaction behaviour is not the current specification.

## Layout composition

The reference design is 1320×883. Geometry is constructed at that aspect ratio and transformed with one uniform scale `s` in points per design unit; keys never stretch independently with the container aspect ratio. Spatial gesture thresholds use the same scale.

Available width is container width minus leading and trailing safe insets. Auto mode selects split at available width ≥600 points, including iPad; orientation alone does not select the mode. Unified and split can also be forced through tuning.

Unified uses `s = availableWidth / 1320`, clamped so `883 * s ≤ heightBudget`; a height-clamped grid is centred horizontally. Split uses `s = min(shorterScreenSide, 430) / 1320 * splitKeyScale`, with default splitKeyScale 0.75 on phone and 1.0 on tablet. The height budget defaults to 320 points. Scale also shrinks when necessary to prevent the halves overlapping.

Split composes columns 0–3 at the leading inset and columns 3–6 at the trailing inset, translating only horizontally. The half footprints mirror each other; their y coordinates and key sizes are identical. Column 3 is drawn twice, with both copies mapping to the same four slots and sharing labels, actions, and pressed state. Only the primary copies enter VoiceOver's key order. The centre gap is transparent and inert. The 123 key remains at the outer bottom left and period at the outer bottom right. The key view spans the available width with height `883 * s`; DEVTOOLS adds a strip outside that height. There is no separate compact-height rule or tablet-width cap.

## Popup plate

Popups use a single opaque, adaptive plate with equal rounded-rectangle cells and a stem to the starting key. Cell width is one column pitch; cell height is one row pitch. The generic model supports multiple rows; the shipped popups use one. Period extends leftward and 123 extends rightward, including into the split gap if needed. Covered base glyphs are hidden.

Selection is measured from the touch's starting point, not by requiring the finger to enter a drawn cell. If both `abs(dx)` and `abs(dy)` are within scaled cancel slop, selection is nil. Otherwise the inward horizontal displacement selects the nearest column, clamped to the grid; upward travel selects the nearest row, also clamped. A small movement outside slop selects cell zero; larger inward movement reaches later cells. Releasing at the origin cancels without insertion. Selection uses system `tintColor` plus an outline and scale change, not colour alone.

Hold period for the configured duration while within slop, then move and release for comma, question mark, exclamation mark, or apostrophe. A final globe cell appears only when keyboard switching is required. Period itself is a tap, not a popup choice. Neutral popup diagnostics never contain characters.

## 123, caps lock, and cursor movement

- Tap 123 to toggle numbers/symbols; tap abc to return to letters.
- Swipe up from 123 to open `[caps lock, presets]`. A quick upward flick selects caps lock on release. Move inward to the second cell for the letter-order picker. Preset selection applies immediately; Done dismisses without changing text or order.
- Hold 123 to enter trackpad mode, not the picker. Letter labels blank while active. Horizontal displacement from the trackpad origin, divided by scaled cursor distance, produces incremental integer grapheme steps; vertical travel is ignored. A stationary hold inserts nothing.

The touch machine owns caps lock. When enabled, all letter labels are capitals and both taps and upward letter swipes insert capitals. Symbols are unaffected; no automatic capitalization is applied. Caps lock resets on keyboard disappearance. VoiceOver exposes caps lock and Choose letter order actions, along with editing, punctuation, and conditional switching actions.

Cursor movement converts grapheme steps against the document contexts before/after the cursor to UTF-16 offsets for the text document proxy. Emoji, ZWJ sequences, and flags remain whole. Missing or exhausted context uses the requested residual step count as a fallback; unavailable host context cannot establish unseen grapheme boundaries.

The picker keeps controls inside the key view rather than increasing keyboard height. At less than 128 points tall, presets and Done share a horizontal row without a title. Other compact frames stack the title, a horizontal presets row, and Done; tall frames stack the preset choices. Resizing an open picker recomposes it to fit.

Letter taps insert the displayed letter, upward letter swipes capitalize, right swipes insert space, down swipes insert newline, and left swipes delete. Continued leftward deletion repeats at `max(40, 0.9 * swipeThreshold)` design units from the first firing position. Independent contacts preserve their starting layer and order.

## Orders and evidence limits

Familiar, Thumb-split, and Keep e·a are model-derived letter orderings with assumed constants and no user testing. They are not validated ergonomic rankings. Keep e·a is `wqzueaxyoijgtcvfrhmdnsbkpl`. Selection is stored in the extension's own defaults, without an App Group, Full Access, network access, or typed-character logging.

## Runtime tuning

`KeyboardTuning` supplies validated values and `TuningStore` persists them in injected UserDefaults (the extension uses its own standard defaults). Missing, malformed, nonfinite, or out-of-range values fall back to defaults. The DEVTOOLS strip cycles parameters with its label, adjusts with −/+, and resets tuning. Changes persist and apply immediately, cancelling contacts before relayout. Layout mode cycles auto/unified/split. The strip also shows memory and the last neutral action. Its controls have stable accessible identifiers but do not join the main key order.

| Parameter | Default | Range | Step |
| --- | --- | --- | --- |
| Split key scale | 0.75 phone / 1.0 tablet | 0.25–1.5 | 0.05 |
| Split width | 600 pt | 320–1400 pt | 10 pt |
| Swipe distance | 70 design units | 20–200 | 5 |
| Hold duration | 420 ms | 150–1500 ms | 20 ms |
| Cancel slop | 10 design units | 1–40 | 1 |
| Cursor distance | 30 design units/grapheme | 5–100 | 5 |
| Highlight exposure | 1.0 stop | 0–3 stops | 0.25 stop |
| Layout mode | auto | auto / unified / split | one mode |
| Height budget | 320 pt | 120–600 pt | 10 pt |

DebugLog and the strip compile only with `DEVTOOLS`. Debug and the sideload Release configuration enable it; there is no separate App Store configuration. Removing that compilation condition removes the diagnostics UI, rather than toggling `DebugLog.enabled`.

## Colour and material

Keys retain native iOS 26 Liquid Glass with rounded hex silhouettes; the system owns Clear/Tinted treatment. Popups are opaque, not glass. Presets and Done use native glass button configurations. UIKit owns touch handling and accessible labels; decorative hosting surfaces cannot intercept input.

No key is highlighted before contact. Active accents use `tintColor`. Dark pressed faces have a visible SDR brightness lift, with an additional extended-range white lift using `UIColor` linear exposure when current and potential EDR headroom permit and Low Power Mode is off. Hosting layers request high dynamic range, constrained in Low Power Mode. The SDR lift remains visible without HDR. Light appearance darkens the pressed face. A 2.5% compression supplies a non-colour cue; custom animation respects Reduce Motion. HDR headroom and perceived intensity require physical hardware and cannot be verified from CI screenshots.
