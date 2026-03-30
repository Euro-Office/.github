<!--
SPDX-FileCopyrightText: 2026 Euro-Office contributors
SPDX-License-Identifier: CC0-1.0
-->

# Contributing to Euro-Office

Thanks for your interest in contributing to Euro-Office! This guide will help you get set up and understand how we work. If you have questions, don't hesitate to open an issue.

See the [organization profile](https://github.com/Euro-Office) and [roadmap](ROADMAP.md) for more context about the project.

---

## Getting Started

1. **Fork** the repository you want to contribute to.
2. **Clone** your fork locally:
   ```sh
   git clone git@github.com:<your-username>/<repo-name>.git
   cd <repo-name>
   ```
3. **Build** the Docker image for development:
   ```sh
   # From the DocumentServer/develop directory
   cd develop
   make pull    # use latest pre-built image
   # or
   make build  # build from scratch (required for ARM64)
   ```
4. **Start** the development environment:
   ```sh
   make
   ```
   The editor is available at `http://localhost:8081/`.

For full build and development instructions, see the [DocumentServer build docs](https://github.com/Euro-Office/DocumentServer/tree/main/build) and [development setup](https://github.com/Euro-Office/DocumentServer/tree/main/develop).

---

## Repository Overview

Euro-Office is a monorepo organization with 19 repositories. The main integration point is **DocumentServer**, which assembles the other components into a deployable service.

| Repository | Purpose | Language | Link |
|---|---|---|---|
| [DocumentServer](https://github.com/Euro-Office/DocumentServer) | Docker/Debian package assembly, CI/CD, integration tests | Shell, Make | [repo](https://github.com/Euro-Office/DocumentServer) |
| [core](https://github.com/Euro-Office/core) | Document rendering engine (OOXML, ODF, PDF conversion) | C++ | [repo](https://github.com/Euro-Office/core) |
| [server](https://github.com/Euro-Office/server) | Node.js backend (document service, converter, metrics, admin panel) | JavaScript | [repo](https://github.com/Euro-Office/server) |
| [sdkjs](https://github.com/Euro-Office/sdkjs) | JavaScript SDK for the document editor | JavaScript | [repo](https://github.com/Euro-Office/sdkjs) |
| [web-apps](https://github.com/Euro-Office/web-apps) | HTML/JS UI for document, spreadsheet, and presentation editors | HTML, JavaScript, CSS | [repo](https://github.com/Euro-Office/web-apps) |
| [desktop-apps](https://github.com/Euro-Office/desktop-apps) | Desktop packaging and build infrastructure | JavaScript, Make | [repo](https://github.com/Euro-Office/desktop-apps) |
| [DesktopEditors](https://github.com/Euro-Office/DesktopEditors) | Desktop editor application (Chromium-based) | C++ | [repo](https://github.com/Euro-Office/DesktopEditors) |
| [desktop-sdk](https://github.com/Euro-Office/desktop-sdk) | SDK for third-party desktop integrations, AI plugins | C++, JavaScript | [repo](https://github.com/Euro-Office/desktop-sdk) |
| [eurooffice-nextcloud](https://github.com/Euro-Office/eurooffice-nextcloud) | Nextcloud integration app | JavaScript, PHP | [repo](https://github.com/Euro-Office/eurooffice-nextcloud) |
| [document-server-integration](https://github.com/Euro-Office/document-server-integration) | Integration examples in Go, Python, PHP, Java, C#, Node.js, Ruby | Multiple | [repo](https://github.com/Euro-Office/document-server-integration) |
| [document-server-package](https://github.com/Euro-Office/document-server-package) | Debian/RPM packaging for DocumentServer | Shell | [repo](https://github.com/Euro-Office/document-server-package) |
| [docker-ci](https://github.com/Euro-Office/docker-ci) | CI Docker images and build tooling | Dockerfile, Shell | [repo](https://github.com/Euro-Office/docker-ci) |
| [core-fonts](https://github.com/Euro-Office/core-fonts) | Font packages for document rendering | Shell | [repo](https://github.com/Euro-Office/core-fonts) |
| [dictionaries](https://github.com/Euro-Office/dictionaries) | Spell-check dictionaries | Text | [repo](https://github.com/Euro-Office/dictionaries) |
| [document-formats](https://github.com/Euro-Office/document-formats) | Document format templates and definitions | XML | [repo](https://github.com/Euro-Office/document-formats) |
| [document-templates](https://github.com/Euro-Office/document-templates) | Sample document templates | Multiple | [repo](https://github.com/Euro-Office/document-templates) |
| [sdkjs-forms](https://github.com/Euro-Office/sdkjs-forms) | Forms plugin for the JavaScript SDK | JavaScript | [repo](https://github.com/Euro-Office/sdkjs-forms) |
| [plugin-aiautofill](https://github.com/Euro-Office/plugin-aiautofill) | AI-powered auto-fill plugin | JavaScript | [repo](https://github.com/Euro-Office/plugin-aiautofill) |
| [.github](https://github.com/Euro-Office/.github) | Organization profile, contributing guide, roadmap | Markdown | [repo](https://github.com/Euro-Office/.github) |

---

## Development Setup

### Docker (recommended)

The Docker-based development environment is the fastest way to get started. It provides a fully isolated build environment with all tooling pre-installed.

1. Follow the [DocumentServer/develop setup](https://github.com/Euro-Office/DocumentServer/tree/main/develop)
2. Enter the container: `docker compose exec eo bash`
3. Build individual components:
   ```sh
   make web-apps    # JavaScript UI
   make sdkjs       # Editor SDK
   make core        # C++ rendering engine
   make server      # Node.js backend
   ```

Quick rebuilds (no dependency install) are available with `-dev` targets:
```sh
make web-apps-dev  # fast rebuild for UI work
```

Pass `DEBUG=1` for debug builds:
```sh
make sdkjs DEBUG=1
```

### ARM64 (Apple Silicon / Graviton)

ARM64 is supported with automatic fallbacks for x86_64-only tooling. No pre-built ARM64 image is available yet, so build locally with `make build`.

### Testing

Tests run as part of CI. To run them locally inside the development container, check the specific repository's test documentation.

---

## Making Changes

### Branching

- Create a descriptive branch from `main`: `git checkout -b fix/login-redirect main`
- Keep branches focused on one concern each.

### Commit Messages

Write clear, plain English commit messages that explain what changed and why.

**Good:**
```
Fix typos in README.md
Add FAQ entry regarding Euro-Office's openness
Remove unused import in document converter
```

**Bad:**
```
fix: login redirect
feat(ui): add button
update stuff
```

No semantic prefixes (`feat:`, `fix:`, `chore:`). Just say what you did.

### Pull Requests

1. Push your branch to your fork.
2. Open a PR against the upstream `main` branch.
3. Describe what the PR does and why. Link related issues.
4. Keep PRs small and focused. Large changes should be split into a series.
5. A maintainer will review your PR. Be ready to discuss and iterate.

---

## Code Style

- **Language**: All code comments and commit messages must be in English.
- **Follow existing patterns**: When in doubt, match the style of the surrounding code.
- **No binary blobs**: Do not add compiled binaries, obfuscated code, or minified files without a clear reason discussed in the PR.
- **Clear naming**: Use descriptive variable and function names. Avoid single-letter names except in tight loops.

Each repository may have more specific style guides. Check for linter configurations (`.eslintrc`, `.clang-format`, etc.) in the repo you're working on.

---

## Reporting Issues

Found a bug or have a feature request? Great, please report it!

1. **Search first** — check if the issue already exists in [DocumentServer/issues](https://github.com/Euro-Office/DocumentServer/issues) or the relevant repository.
2. **Be specific** — include steps to reproduce, expected vs. actual behavior, and your environment (OS, browser, Docker version).
3. **Screenshots help** — attach screenshots or screen recordings when applicable.
4. **One issue per report** — don't bundle unrelated problems into one issue.

### Good issue reports include:

- **What happened**: clear description of the problem
- **What you expected**: what should have happened instead
- **Steps to reproduce**: numbered steps anyone can follow
- **Environment**: OS, browser, Docker version, branch/commit
- **Logs**: relevant error messages or stack traces

---

## Community Guidelines

Euro-Office is built by people from different backgrounds and countries. We are committed to providing a welcoming and respectful environment for everyone.

- Be respectful and constructive in all interactions.
- Assume good intent.
- Focus on the code, not the person.

<!-- TODO: add Code of Conduct link -->
<!-- TODO: add Matrix/Discourse community channel link -->

---

## License

Euro-Office is licensed under the [GNU AGPLv3](https://www.gnu.org/licenses/agpl-3.0.en.html).

All source files must include SPDX license headers. For new files, use:

```
SPDX-FileCopyrightText: 2026 Euro-Office contributors
SPDX-License-Identifier: AGPL
```

See individual repository headers for existing files. When modifying a file, keep its existing license header intact.
