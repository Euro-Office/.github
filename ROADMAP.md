<!--
SPDX-FileCopyrightText: 2026 Euro-Office contributors
SPDX-License-Identifier: CC0-1.0
-->

# Euro-Office Roadmap

This document outlines the high-level goals and planned milestones for the Euro-Office project. It is a living document — priorities may shift as the project evolves.

---

## Vision

Euro-Office aims to provide a truly open, transparent, and sovereign online office suite for collaborative document editing, free from the governance and transparency concerns that led to the fork from ONLYOFFICE.

## Guiding Principles

- **Transparency** — No binary blobs, no obfuscated code, English-language comments and commit messages.
- **Buildability** — Reliable, documented build instructions that work on first try.
- **Open Contribution** — PRs reviewed and merged in a timely manner; low barriers to entry.
- **Sovereignty** — European-governed, with a globally open contributor base.

---

## Phase 1 — Foundation (In Progress)

> Goal: Make the codebase clean, buildable, and contributor-friendly.

### Codebase Cleanup

- [ ] **Remove or replace binary blobs** — ~400–500 MB of non-source content identified:
  - `core/Common/3dParty/libvlc/build/` — ~1,500 precompiled VLC binaries (302 MB across 5 platforms). Move to a separate package or Git LFS.
  - 6 emscripten WASM + JS fallback pairs in `sdkjs/` and `core/` (~45 MB). These are build outputs of C/C++ source in the repo.
  - `core/Test/Applications/` — compiled .exe/.dll test build artifacts.
  - No Git LFS tracking configured in any repo.
- [ ] **Translate Russian code comments** — ~22,500 lines identified across repos:
  - `sdkjs/` — ~15,300 lines (JavaScript, highest priority — easiest to batch process)
  - `core/` — ~7,000 lines (C++, concentrated in XLS/XLSB/PPT binary format handling)
  - `web-apps/` — ~200 lines (quick wins)
  - `server/` — 9 lines (negligible)
  - Exclude from scope: native language names in i18n data, regex Cyrillic patterns, 3rd-party vendored code.
- [ ] **Audit third-party dependencies** with unclear licensing (in progress)
- [x] Establish a code style guide and contribution guidelines ([`CONTRIBUTING.md`](CONTRIBUTING.md))

### Build System
- [ ] Fix unreliable and outdated build instructions
- [ ] Set up reproducible builds with containerized toolchains
- [x] Add CI/CD pipelines for all major repositories — **66 workflows across 12 of 19 repos** already exist. Missing: core-fonts, desktop-sdk, dictionaries, document-formats, document-server-package, document-templates, sdkjs-forms.
- [ ] Document per-repository build and test procedures

### Community Infrastructure
- [x] Create onboarding documentation ([`CONTRIBUTING.md`](CONTRIBUTING.md) with 19-repo overview)
- [x] Add GitHub issue templates (bug report, feature request, question)
- [x] Add PR template and security policy
- [ ] Establish issue triage and PR review workflows (labels, milestones)
- [ ] Set up communication channels (Matrix, Discourse, or similar)

---

## Phase 2 — Feature Parity & Restoration

> Goal: Restore features that were removed or closed off in the ONLYOFFICE upstream.

### Administrator Panel
- [x] ~~Audit the removed admin panel functionality~~ **Already built by Euro-Office.** The `server/AdminPanel/` is a complete, custom-built React 18 SPA + Express.js backend (707 files, 14 admin pages) that does NOT exist in the ONLYOFFICE upstream. Features: Statistics, AI Integration, File Limits, IP Filtering, WOPI Settings, Notifications, Logger Config, Health Check.
- [ ] Enable the admin panel by default in packaged deployments (currently `autostart=false` in supervisor config)
- [ ] Build the admin panel client (`npm run build` in `server/AdminPanel/client/`)
- [ ] Add tests for the admin panel

### Mobile Applications
- [x] ~~Identify and document the proprietary sections in existing mobile apps~~ **Audited.** Full mobile web editors exist for all 4 document types (Word, Excel, PPT, Visio) using Framework7 + React (~306 JS files). The native app shells (Android/iOS) are proprietary and NOT in this repo. A well-defined native bridge interface (`window.Android`/`window.native`) exists but the native-side implementation is missing.
- [ ] Build native mobile app shells (recommended: **Capacitor** wrapper for cross-platform support)
- [ ] Implement `window.Android`/`window.native` bridge in the Capacitor layer
- [ ] Add cloud storage connectors (WebDAV, S3, Nextcloud) for mobile
- [ ] Add PDF editing to mobile (currently PDF viewing only via document editor)
- [ ] Release to app stores (Google Play, Apple App Store)

### Document Compatibility
- [ ] Improve Microsoft Office file format compatibility (DOCX, XLSX, PPTX)
- [ ] Strengthen ODF support (ODT, ODS, ODP)
- [ ] Improve PDF viewing and editing capabilities

---

## Phase 3 — Desktop Applications

> Goal: Deliver production-quality desktop editors.

### Desktop Editors
- [ ] Stabilize the Chromium-based desktop editor framework (`DesktopEditors`, `desktop-apps`) — [active development by rikled](https://github.com/Euro-Office/core/pull/13)
- [x] ~~Improve Linux packaging (AppImage, Flatpak, Snap)~~ **RPM and Debian packaging exist.** Missing: AppImage, Flatpak, Snap.
- [ ] Add Flatpak packaging
- [ ] Add Snap packaging
- [ ] Add AppImage packaging
- [ ] Improve macOS and Windows packaging and installer experience
- [ ] Add offline-first capabilities with seamless cloud sync

### Desktop SDK
- [ ] Document the desktop SDK (`desktop-sdk`) for third-party integrations
- [ ] Publish SDK packages and examples

---

## Phase 4 — Integration Ecosystem

> Goal: Make Euro-Office the default document editing component for European digital workplace solutions.

### Platform Integrations
- [x] ~~Mature the Nextcloud integration (`eurooffice-nextcloud`)~~ **Mature.** 46 PHP files covering file editing, sharing, templates, collaboration, federation, and admin settings.
- [ ] Provide first-class integration guides for XWiki, OpenProject, Proton
- [ ] Build and maintain integration SDKs for common platforms (Web, REST API, WOPI) — WOPI settings infrastructure already exists in `server/AdminPanel/`
- [ ] Expand language support for integration examples (Go, Python, PHP, Java, C#, Node.js, Ruby)
- [ ] **Integrate into OpenCloud** — groupware platform integration
- [ ] **Integrate into SOGo** — open-source groupware (email, calendar, contacts) integration
- [ ] **Integrate into Open-Xchange** — email and collaboration platform integration
- [ ] **Integrate into Zimbra** — email and collaboration suite integration

### Collaboration with LibreOffice/Collabora
- [ ] Explore collaboration opportunities (e.g., shared document converter)
- [ ] Investigate interoperability testing between Euro-Office and LibreOffice

---

## Phase 5 — Innovation

> Goal: Differentiate Euro-Office with modern features.

### AI-Powered Features
- [x] ~~Expand the AI auto-fill plugin (`plugin-aiautofill`)~~ **Production (v1.0.0).** AI-powered form field mapping for Word/PDF forms with third-party backend integration (e.g., Pipedrive).
- [x] ~~Develop the AI agent plugin for desktop (`desktop-sdk/.../ai-agent`)~~ **Production (v1.1.0).** Full AI chatbot with 11 provider support (OpenAI, Anthropic, Gemini, DeepSeek, xAI, Mistral, Together, OpenRouter, Ollama, LM Studio, OpenAI-Compatible), MCP protocol support, web search, and desktop editor tool integration.
- [x] ~~Add on-device AI capabilities (local LLM support)~~ **Already supported.** Ollama and LM Studio are first-class providers. Any OpenAI-compatible endpoint (vLLM, text-generation-webui) also works.
- [ ] Add RAG (Retrieval-Augmented Generation) for in-editor AI to use document context
- [ ] Bundle a lightweight local model (e.g., Phi-3-mini, Gemma-2b) for offline desktop AI
- [ ] Add spreadsheet AI functions (`=AI("explain this formula")`)
- [ ] Add presentation AI features (slide generation from outlines, speaker notes)

### In-Editor AI Assistant
- [x] ~~In-editor AI plugin~~ **Production (v2.5.0, 25+ releases).** AI chatbot, text analysis (rewrite, summarize, translate), image generation/OCR, function-calling agent. Available for Word, Cell, Slide, and PDF editors. Server-side proxy with multi-provider routing.

### User Experience
- [ ] Modernize the web-based editor UI (`web-apps`)
- [ ] Improve accessibility (WCAG 2.1 AA compliance)
- [ ] Add real-time collaboration enhancements (presence indicators, comments, version history)

### Performance
- [ ] Optimize document rendering engine (`core`, `sdkjs`)
- [ ] Reduce memory footprint for large documents
- [ ] Improve WebSocket-based real-time editing performance

---

## How to Get Involved

- **File issues** — [github.com/Euro-Office/DocumentServer/issues](https://github.com/Euro-Office/DocumentServer/issues)
- **Submit PRs** — See the [contributing guide](CONTRIBUTING.md) for branch, commit, and PR conventions
- **Join the discussion** — Check the organization page for community channels
- **Spread the word** — Star the repos, share with your network

See the [organization profile](https://github.com/Euro-Office) for the full list of repositories.

---

## Partners & Supporters

Euro-Office is driven by a growing consortium of European organizations committed to digital sovereignty.

### Corporate & Non-Profit Partners
- IONOS
- Nextcloud
- EuroStack
- XWiki
- OpenProject
- Proton
- Soverin
- Abilian
- BTactic

### Education & Research
- [ZKI](https://www.zki.de) — Zentrum für Kommunikation und Informationsverarbeitung, the IT consortium of German universities and research institutions
- German Universities — coordinated adoption and contribution through ZKI member institutions

### Community & Public Sector
- graphwiz.ai Consulting
- Heinlein B1 — managed hosting and IT services provider
- Knoppix — the iconic Linux live system, supporting open-source office technology
- Additional partners welcome — see [how to get involved](#how-to-get-involved)

---

## Audit Log

Findings from the initial codebase audit (March 2026):

| Area | Finding | Impact |
|------|---------|--------|
| Binary blobs | ~400–500 MB, dominated by VLC precompiled binaries (302 MB) | High — repo bloat, transparency concern |
| Russian comments | ~22,500 lines across core (7K), sdkjs (15K), web-apps (200) | High — contributor accessibility |
| Admin panel | Already built by Euro-Office (not from upstream) | Done — needs activation |
| Mobile web UI | Complete for all 4 editors (306 JS files) | Done — native shells needed |
| Mobile native shells | None exist — must be built | Medium — Capacitor recommended |
| AI features | 4 production features, on-device AI already supported | Done — RAG and bundled models next |
| Desktop packaging | RPM + Debian + Windows exist; no Flatpak/Snap/AppImage | Low — gaps identified |
| CI/CD | 66 workflows across 12/19 repos | Good — 7 repos need CI |
| Nextcloud integration | Mature (46 PHP files) | Done |
| Dependency licensing | Audit in progress | TBD |
