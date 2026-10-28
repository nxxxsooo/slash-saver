# Changelog

All notable changes to Slash Saver are documented here.

## 1.1.0 - Unreleased

- Added an optional Escape trigger (**Esc 键也切换**), off by default, for terminal and modal-editor shortcuts after leaving text entry.
- Added `SlashSaver input-source current|ascii|select <id>` so terminal tools can switch to the configured ASCII source and restore the previous one.

## 1.0.1 - 2026-07-22

- Replaced the coral icon with a calmer emerald and lime identity.
- Reworked settings into a compact native preference panel with clearer hierarchy and aligned controls.
- Expanded the product story around chat, search, code, and vibe-coding input transitions.

## 1.0.0 - 2026-07-22

- Added passive HID-level monitoring for the physical ANSI slash key.
- Added synchronous selection of a user-configured ASCII input source.
- Added native settings for input-source selection, Input Monitoring status, and launch at login.
- Added a background-only app lifecycle with no Dock or menu bar icon.
- Added a dedicated app icon, unit tests, and GitHub Actions CI.
