<!--
SPDX-FileCopyrightText: 2026 Euro-Office contributors
SPDX-License-Identifier: CC0-1.0
-->

# Integration Planning: Euro-Office DocumentServer

## Overview

Euro-Office DocumentServer (a fork of ONLYOFFICE Document Server) should be integrated **INTO** the following platforms as a document editing backend. The integration direction is: each platform calls into DocumentServer to provide online document editing capabilities to its users — replacing or complementing proprietary solutions like Microsoft Office Online, Google Docs, or Collabora Online.

Euro-Office DocumentServer already supports the two primary integration protocols:

- **WOPI (Web Application Open Platform Interface)** — REST-based protocol by Microsoft for file access and editing. DocumentServer acts as a WOPI server; the host platform acts as a WOPI client.
- **Document Editors API (Docs API)** — ONLYOFFICE's own JavaScript API for embedding editors via an iframe with a JSON configuration object. Provides richer customization than WOPI.

Both protocols are production-ready. The choice between them depends on the target platform's existing integration architecture.

---

## Integration Protocols

### WOPI (Web Application Open Platform Interface)

WOPI is the industry-standard protocol for integrating online office editors into web applications. It defines a REST API between two parties:

- **WOPI Server** — The document editing service (Euro-Office DocumentServer). Provides the editing UI and manages document conversion.
- **WOPI Client** — The host application (OpenCloud, SOGo, etc.). Stores files and handles user authentication.

**Key WOPI operations:**

| Operation | Purpose |
|-----------|---------|
| `CheckFileInfo` | Returns file metadata (name, size, owner, permissions, version) |
| `GetFile` | Retrieves the file content for editing |
| `PutFile` | Saves the edited file back to storage |
| `Lock` / `Unlock` / `RefreshLock` | Manages file locking for concurrent editing |
| `PutRelativeFile` | Creates a new file or saves a copy |

**WOPI Discovery:** DocumentServer exposes a discovery XML endpoint (`/hosting/discovery`) that describes supported file extensions, actions (view/edit), and URL templates. WOPI clients use this to construct editor URLs.

**Authentication flow:**
1. User clicks "Edit" in the host platform.
2. Host platform generates an access token for the file and user.
3. Host platform redirects the user to DocumentServer with the WOPI source URL and access token.
4. DocumentServer calls back to the host's WOPI endpoints (`CheckFileInfo`, `GetFile`) using the access token to retrieve the file.
5. User edits the document in DocumentServer's editor UI.
6. On save, DocumentServer calls `PutFile` on the host to persist changes.

**Security:** WOPI uses proof keys (RSA key pairs) for request verification. The WOPI client signs requests with its private key; DocumentServer verifies using the public key from the discovery XML. This prevents unauthorized parties from accessing files.

### Document Editors API (Docs API)

The Docs API is Euro-Office's native JavaScript integration method. It offers more features than WOPI at the cost of a tighter coupling:

- **Richer customization:** Branding, toolbar control, plugin injection, template passing
- **More events:** File rename, sharing settings, mail merge, comparison, save-as, user mentions, new file creation
- **More methods:** Download-as, set favorite, show message
- **Collaboration modes:** Real-time and paragraph-locking co-editing with mode switching
- **Security:** JWT-based request signing on both sides (browser-to-server and server-to-callback)

**When to use Docs API over WOPI:**
- The host platform can embed an iframe with JavaScript configuration
- Deep customization of the editor UI is required
- Additional events/methods beyond WOPI's scope are needed
- Real-time and paragraph-locking co-editing mode switching is desired

### WebDAV

WebDAV is not a document editing protocol itself but provides file access. Some platforms use WebDAV as a storage backend that the editor reads from and writes to. Euro-Office DocumentServer does not natively speak WebDAV for editing — WOPI or Docs API should be used instead. WebDAV may serve as the underlying file storage layer that the WOPI client accesses.

---

## Platform Integration Plans

### 1. OpenCloud

- **Platform:** OpenCloud is a fork of ownCloud focused on digital sovereignty. It provides file sync, share, and collaboration capabilities. Being a Nextcloud/ownCloud derivative, it inherits the same app-based extension architecture.

- **Current editor support:** OpenCloud, like ownCloud and Nextcloud, uses the `richdocuments` (Nextcloud Office) app pattern to integrate office editors. This app acts as a WOPI client — it implements the WOPI REST endpoints and embeds the editor via iframe. The existing `eurooffice-nextcloud` integration (46 PHP files) already provides a mature connector for Nextcloud that should be adaptable to OpenCloud.

- **Integration approach:** **WOPI** (primary) with Docs API as a fallback. The `richdocuments` app architecture is the standard WOPI client pattern for Nextcloud/ownCloud-family platforms. Euro-Office already has a working Nextcloud connector (`eurooffice-nextcloud`) that can be adapted.

- **Required work in Euro-Office:**
  - Verify compatibility of the existing `eurooffice-nextcloud` connector with OpenCloud's app API
  - Test and fix any OpenCloud-specific differences from Nextcloud (app info XML, capabilities API, sharing hooks)
  - Ensure WOPI discovery endpoint (`/hosting/discovery`) returns correct metadata for OpenCloud's WOPI client
  - Validate JWT secret exchange configuration between OpenCloud and DocumentServer

- **Configuration (admin):**
  - Install the Euro-Office connector app in OpenCloud
  - Configure DocumentServer URL and JWT secret in OpenCloud admin settings
  - Enable WOPI in DocumentServer config (`wopi.enable = true`)
  - Restrict DocumentServer IP whitelist to OpenCloud server IP(s)

- **Complexity:** Low — existing Nextcloud integration provides a strong starting point

- **Priority:** P1 — OpenCloud is a listed Euro-Office partner and the most natural first integration target

---

### 2. SOGo

- **Platform:** SOGo is an open-source groupware server providing email (via IMAP/SMTP), calendaring (CalDAV), contacts (CardDAV), and active sync. It is widely used in academic and government environments across Europe. SOGo has a web frontend but does not have a native document editing module — it relies on external integrations.

- **Current editor support:** SOGo does not have a built-in document editor. It historically lacked any office document editing integration. ONLYOFFICE does not list a dedicated SOGo connector. Some third-party efforts have explored integrating Collabora Online with SOGo via WOPI, but there is no widely adopted solution. Document editing in SOGo would typically need to be added as a new capability, likely through a Zimlet-like extension mechanism or by embedding the editor in the web UI.

- **Integration approach:** **WOPI** (recommended). Since SOGo has no existing editor integration architecture, building a WOPI client is the cleanest approach. SOGo would need to implement WOPI REST endpoints (`CheckFileInfo`, `GetFile`, `PutFile`, lock operations) and embed the DocumentServer editor iframe in its web UI. An alternative would be a custom Docs API integration for deeper UI customization.

- **Required work in Euro-Office:**
  - Provide WOPI client implementation guidance and reference code for SOGo
  - Ensure DocumentServer's WOPI endpoint is fully compatible with standard WOPI client behavior
  - Test file locking behavior (SOGo may need to handle concurrent access from CalDAV/CardDAV and the editor)
  - Provide authentication token format documentation for SOGo's WOPI implementation

- **Configuration (admin):**
  - Deploy DocumentServer and enable WOPI (`wopi.enable = true`)
  - Install the SOGo WOPI integration module (to be developed)
  - Configure DocumentServer URL and JWT/proof-key settings in SOGo
  - Map SOGo user authentication to WOPI access tokens

- **Complexity:** High — requires building a new WOPI client layer for SOGo from scratch

- **Priority:** P2 — SOGo is widely deployed in European institutions but requires the most development effort

---

### 3. Open-Xchange

- **Platform:** Open-Xchange (OX) App Suite is a comprehensive email and collaboration platform. It includes mail, calendar, contacts, tasks, and file storage (OX Drive). OX has its own document editing product called **OX Documents** (OX Text, OX Spreadsheet, OX Presentation), which is built on a different technology stack.

- **Current editor support:** Open-Xchange ships its own OX Documents editor. However, OX also supports integration with third-party editors. The OX App Suite has a Nextcloud integration module and supports WOPI-based office integration. OX can be configured to use Collabora Online as an alternative document editor. The OX Connector app (documented by Univention) manages the integration between OX and file storage backends.

- **Integration approach:** **WOPI** (primary). Open-Xchange already supports WOPI-based integration for external editors (Collabora). Euro-Office DocumentServer would need to register as an alternative WOPI server. OX would need a configuration option to point to a Euro-Office DocumentServer instance instead of (or alongside) OX Documents or Collabora.

- **Required work in Euro-Office:**
  - Verify that DocumentServer's WOPI discovery endpoint conforms to OX's expectations (OX may have specific requirements for discovery XML format)
  - Test interoperability with OX Drive as the file storage backend
  - Ensure proper file format handling for ODF documents (OX Documents is ODF-native)
  - Document the OX-specific configuration steps for connecting to DocumentServer

- **Configuration (admin):**
  - Deploy DocumentServer and enable WOPI
  - Configure OX App Suite to use DocumentServer as the WOPI server endpoint
  - Set up JWT or proof-key authentication between OX and DocumentServer
  - Configure file format conversion settings (OX users may expect ODF-first workflows)

- **Complexity:** Medium — OX already supports WOPI integration but has its own editor product, so adoption requires convincing OX admins to switch or add an alternative

- **Priority:** P2 — OX is a significant platform in enterprise environments, especially in Germany

---

### 4. Zimbra

- **Platform:** Zimbra is a widely deployed email and collaboration suite providing mail, calendar, contacts, tasks, and file storage (Zimbra Briefcase). Zimbra 10 introduced built-in online document editing capabilities using ONLYOFFICE Document Server.

- **Current editor support:** Zimbra 10 Network Edition (NE) natively integrates ONLYOFFICE Document Server for document editing in Briefcase and attachment viewing. The integration uses a dedicated package (`zimbra-onlyoffice`) that bundles a fork of the ONLYOFFICE server (`Zimbra/zm-onlyoffice` — forked from `ONLYOFFICE/server`). Key components:
  - `zimbra-onlyoffice` — The document server backend (forked ONLYOFFICE server)
  - `zimbra-rabbitmq-server` — Message queue required by the document server
  - `zimbra-zimlet-classic-document-editor` — Zimlet for the classic Zimbra web UI
  - Configuration via `zmprov ms $(zmhostname) zimbraDocumentServerHost $(zmhostname)`
  - Setup script: `/opt/zimbra/onlyoffice/bin/zmonlyofficeconfig`

  **Important limitation:** The ONLYOFFICE integration in Zimbra 10 NE is a **Network Edition (proprietary)** feature. The open-source edition (FOSS) does not include it. Zimbra has forked the ONLYOFFICE server into `Zimbra/zm-onlyoffice` and maintains it independently.

- **Integration approach:** **Docs API** (primary, matching Zimbra's existing architecture). Since Zimbra already uses a forked ONLYOFFICE server, the integration follows the Docs API pattern rather than standard WOPI. The forked server is tightly integrated into Zimbra's infrastructure. To integrate Euro-Office, the most practical approach is to:
  1. Replace or complement the `zm-onlyoffice` fork with Euro-Office DocumentServer
  2. Ensure the Zimbra-specific API endpoints and authentication mechanisms are compatible
  3. Maintain the existing Zimbra integration packages (`zimbra-onlyoffice`, Zimlets) but point them to Euro-Office DocumentServer

  **WOPI** could be explored as an alternative if Zimbra's next-generation architecture moves toward standard WOPI.

- **Required work in Euro-Office:**
  - Audit the differences between `Zimbra/zm-onlyoffice` and the upstream ONLYOFFICE server (and by extension, Euro-Office's fork) to identify Zimbra-specific patches
  - Ensure Euro-Office DocumentServer exposes the same API endpoints that Zimbra's frontend expects
  - Test the `zmonlyofficeconfig` setup script compatibility with Euro-Office DocumentServer
  - Provide packaging guidance (RPM/DEB) that matches Zimbra's installation expectations
  - Document the migration path from `zm-onlyoffice` to Euro-Office DocumentServer

- **Configuration (admin):**
  - Deploy Euro-Office DocumentServer (standalone or co-located with Zimbra)
  - Run the Zimbra ONLYOFFICE setup script with the Euro-Office DocumentServer URL
  - Configure `zimbraDocumentServerHost` to point to the Euro-Office instance
  - Enable the `onlyoffice` service in Zimbra
  - For multi-server setups, configure the document server host separately

- **Complexity:** Medium — Zimbra already has a working ONLYOFFICE integration, but it uses a forked server and is NE-only

- **Priority:** P1 — Zimbra's existing ONLYOFFICE integration provides a clear migration path; large European deployment base

---

## Shared Requirements

The following capabilities must be available in Euro-Office DocumentServer for all four platform integrations:

### Protocol Support
- **WOPI endpoint** (`/hosting/discovery`, WOPI REST operations) — Required for OpenCloud, SOGo, Open-Xchange
- **Docs API** (JavaScript editor initialization with JSON config) — Required for Zimbra; optional enhancement for others
- **WOPI proof keys** — RSA key pair management for request signing/verification between the host platform and DocumentServer
- **JWT authentication** — Token-based access control for Docs API integrations

### File Operations
- **File locking** — WOPI lock/refreshLock/unlock operations for safe concurrent editing
- **File conversion** — On-the-fly conversion between OOXML (DOCX/XLSX/PPTX), ODF (ODT/ODS/ODP), PDF, and legacy formats
- **Version history** — Support for WOPI versioning and document history events
- **Co-editing** — Real-time collaborative editing via WebSocket connections

### Administrative Features
- **WOPI settings admin panel** — Already exists in `server/AdminPanel/` (React 18 SPA)
- **IP whitelisting** — Restrict which host platform IPs can access DocumentServer
- **Health check endpoint** — For the host platform to verify DocumentServer availability
- **Logging and monitoring** — Structured logs for integration troubleshooting

### Packaging and Deployment
- **Docker image** — For containerized deployments alongside the host platform
- **DEB/RPM packages** — For bare-metal installations (especially Zimbra)
- **Helm chart** — For Kubernetes deployments alongside OpenCloud and Open-Xchange
- **Environment variable configuration** — For common settings (WOPI enable, JWT secret, allowed origins)

---

## Implementation Roadmap

### Phase 1 — Foundation (DocumentServer-side)

Ensure Euro-Office DocumentServer is fully ready as an integration target:

- [ ] Verify WOPI endpoint correctness and completeness against the WOPI specification
- [ ] Ensure WOPI proof key generation and rotation work reliably
- [ ] Validate WOPI discovery XML output matches what standard WOPI clients expect
- [ ] Test Docs API compatibility with the patterns used by Zimbra's integration
- [ ] Document the WOPI client implementation requirements for third-party platforms
- [ ] Publish integration SDK examples (WOPI client reference, Docs API configuration)

### Phase 2 — OpenCloud Integration (P1)

Leverage the existing Nextcloud connector:

- [ ] Test `eurooffice-nextcloud` connector against OpenCloud's app API
- [ ] Fix any compatibility issues between Nextcloud and OpenCloud APIs
- [ ] Package the connector for OpenCloud's app store
- [ ] Write OpenCloud-specific installation and configuration documentation
- [ ] Set up CI testing against OpenCloud releases

### Phase 3 — Zimbra Integration (P1)

Build on Zimbra's existing ONLYOFFICE integration:

- [ ] Audit `Zimbra/zm-onlyoffice` fork to identify Zimbra-specific patches
- [ ] Determine whether these patches need to be ported to Euro-Office DocumentServer
- [ ] Test Euro-Office DocumentServer as a drop-in replacement for `zm-onlyoffice`
- [ ] Provide migration documentation from `zm-onlyoffice` to Euro-Office
- [ ] Explore making the integration available for Zimbra FOSS (currently NE-only)

### Phase 4 — Open-Xchange Integration (P2)

- [ ] Investigate OX's WOPI client implementation and configuration options
- [ ] Test DocumentServer with OX App Suite's WOPI integration
- [ ] Document OX-specific setup steps
- [ ] Handle ODF-first workflow expectations (format defaults, templates)

### Phase 5 — SOGo Integration (P2)

- [ ] Design the SOGo WOPI client module architecture
- [ ] Implement WOPI REST endpoints in SOGo (file access, locking)
- [ ] Build the editor embedding component for SOGo's web UI
- [ ] Handle SOGo's authentication model (IMAP-backed) for WOPI token generation
- [ ] Package the integration as a SOGo module/plugin

---

## References

### Protocol Documentation
- [WOPI Protocol Overview — Microsoft Learn](https://learn.microsoft.com/en-us/microsoft-365/cloud-storage-partner-program/online/)
- [WOPI Overview — ONLYOFFICE API](https://api.onlyoffice.com/docs/docs-api/using-wopi/overview/)
- [WOPI REST API — ONLYOFFICE API](https://api.onlyoffice.com/docs/docs-api/using-wopi/wopi-rest-api/)
- [WOPI Discovery — ONLYOFFICE API](https://api.onlyoffice.com/docs/docs-api/using-wopi/wopi-discovery/)
- [API vs WOPI Comparison — ONLYOFFICE API](https://api.onlyoffice.com/docs/docs-api/using-wopi/api-vs-wopi/)
- [Docs API Basic Concepts — ONLYOFFICE API](https://api.onlyoffice.com/docs/docs-api/get-started/basic-concepts/)

### Platform Documentation
- [ownCloud WOPI Integration](https://owncloud.com/microsoft-office-online-integration-with-wopi/)
- [Nextcloud Richdocuments App](https://github.com/nextcloud/richdocuments)
- [SOGo Documentation](https://www.sogo.nu/files/docs/SOGoInstallationGuide.pdf)
- [Open-Xchange Products](https://www.open-xchange.com/products/)
- [Zimbra Document Editing in Briefcase](https://blog.zimbra.com/2023/05/discover-zimbra-new-document-editing-in-briefcase/)
- [Zimbra ONLYOFFICE Integration Guide](https://imanudin.net/2023/12/02/how-to-integrate-onlyoffice-with-zimbra/)
- [Zimbra/zm-onlyoffice (forked ONLYOFFICE server)](https://github.com/Zimbra/zm-onlyoffice)

### Internal Resources
- [Euro-Office ROADMAP.md](ROADMAP.md) — Phase 4 integration targets
- [eurooffice-nextcloud connector](https://github.com/Euro-Office/eurooffice-nextcloud) — Existing Nextcloud integration (46 PHP files)
- [DocumentServer Admin Panel](https://github.com/Euro-Office/DocumentServer) — WOPI settings in `server/AdminPanel/`
