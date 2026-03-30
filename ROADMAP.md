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
- [ ] Remove or replace binary blobs and compiled/obfuscated code sections
- [ ] Translate Russian code comments and commit messages to English
- [ ] Audit and clean up third-party dependencies with unclear licensing
- [ ] Establish a code style guide and contribution guidelines (`CONTRIBUTING.md`)

### Build System
- [ ] Fix unreliable and outdated build instructions
- [ ] Set up reproducible builds with containerized toolchains
- [ ] Add CI/CD pipelines for all major repositories (DocumentServer, core, sdkjs, web-apps, server, desktop-apps)
- [ ] Document per-repository build and test procedures

### Community Infrastructure
- [ ] Establish issue triage and PR review workflows
- [ ] Create onboarding documentation for new contributors
- [ ] Set up communication channels (Matrix, Discourse, or similar)

---

## Phase 2 — Feature Parity & Restoration

> Goal: Restore features that were removed or closed off in the ONLYOFFICE upstream.

### Administrator Panel
- [ ] Audit the removed admin panel functionality
- [ ] Design and implement a modern admin panel (likely in the `server` repository)
- [ ] Configuration management for DocumentServer deployments

### Mobile Applications
- [ ] Identify and document the proprietary sections in existing mobile apps
- [ ] Re-implement mobile editing capabilities as fully open-source code
- [ ] Release native mobile apps for iOS and Android

### Document Compatibility
- [ ] Improve Microsoft Office file format compatibility (DOCX, XLSX, PPTX)
- [ ] Strengthen ODF support (ODT, ODS, ODP)
- [ ] Improve PDF viewing and editing capabilities

---

## Phase 3 — Desktop Applications

> Goal: Deliver production-quality desktop editors.

### Desktop Editors
- [ ] Stabilize the Chromium-based desktop editor framework (`DesktopEditors`, `desktop-apps`)
- [ ] Improve Linux packaging (AppImage, Flatpak, Snap)
- [ ] Improve macOS and Windows packaging and installer experience
- [ ] Add offline-first capabilities with seamless cloud sync

### Desktop SDK
- [ ] Document the desktop SDK (`desktop-sdk`) for third-party integrations
- [ ] Publish SDK packages and examples

---

## Phase 4 — Integration Ecosystem

> Goal: Make Euro-Office the default document editing component for European digital workplace solutions.

### Platform Integrations
- [ ] Mature the Nextcloud integration (`eurooffice-nextcloud`)
- [ ] Provide first-class integration guides for XWiki, OpenProject, Proton
- [ ] Build and maintain integration SDKs for common platforms (Web, REST API, WOPI)
- [ ] Expand language support for integration examples (Go, Python, PHP, Java, C#, Node.js, Ruby)

### Collaboration with LibreOffice/Collabora
- [ ] Explore collaboration opportunities (e.g., shared document converter)
- [ ] Investigate interoperability testing between Euro-Office and LibreOffice

---

## Phase 5 — Innovation

> Goal: Differentiate Euro-Office with modern features.

### AI-Powered Features
- [ ] Expand the AI auto-fill plugin (`plugin-aiautofill`)
- [ ] Develop the AI agent plugin for desktop (`desktop-sdk/.../ai-agent`)
- [ ] Add on-device AI capabilities (local LLM support) for air-gapped environments

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
- **Submit PRs** — Start with good-first-issues labeled in any repository
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
