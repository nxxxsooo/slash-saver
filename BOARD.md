# Slash Saver Board

## Changelog

### 2026-07-22

- **feat**: Released Slash Saver v1.0.1 with a calmer emerald-and-lime identity, a polished native settings panel, and a product story centered on slash-triggered input friction.
  - why: Chinese input users moving among chat, English search, code, and agent prompts can get `、`, pinyin composition after `/`, or unwanted text committed by Return; app-wide input-source switching is too coarse for that workflow.
  - verified: 9 Swift tests, Release analyze, universal `arm64 + x86_64` build, Apple Development signature, hardened runtime, GitHub CI, SHA-256 release download, responsive bilingual landing page, dark mode, reduced motion, production deploy, and online asset checks.
  - refs: source commit `52ff036`; tag and release `v1.0.1`; portfolio commit `65869c2`; Vercel deployment `dpl_DmzEzTHn6Q8wue4gLG95bUW2Fdbc`; `https://mjshao.fun/slash-saver/`

## Shipped

- [x] Physical ANSI slash-key detection through a passive `CGEventTap`
- [x] User-selected ASCII input source persisted by system identifier
- [x] Original event passthrough with no synthetic input
- [x] Input Monitoring permission flow
- [x] Login launch through `SMAppService.mainApp`
- [x] Background-only native macOS app
- [x] Unit tests and CI
- [x] App icon and universal macOS release package
- [x] GitHub source and v1.0.0 release
- [x] Product page on `mjshao.fun`

## Later

- [ ] Apple Developer ID signing and notarization
- [ ] Additional hardware-layout compatibility reports
