# Fewshell

**Human-gated AI shell for production systems.**

Fewshell is a mobile/desktop, self-hosted, collaborative terminal AI agent designed for incident response and infrastructure workflows.

It works like a typical terminal agent, with one important caveat:

- Every command requires human approval.

There is no autonomous ("YOLO") mode, and no way to enable it.

[Website](https://fewshell.com) · [Quick Start](https://fewshell.com/docs/getting-started/quick-start/) · [Download](https://fewshell.com)

<!-- Screenshot placeholder: add a screenshot or demo GIF here -->

## The on-call problem

Fewshell is an attempt to make something that is safe to use for on-calls, AI researchers, self-hosting enthusiasts or anyone who regularly needs to interact with the terminal in order to fix, restart, or check on something while on the go.

While LLMs are increasingly good at using the terminal, sysadmin tasks and troubleshooting, there are many cases where you really don't want (or are not allowed) to give admin-level access to an LLM.

## Core design principles

### 1. Secure defaults

- Communication over SSH tunnel and domain socket
- Secrets stored in the client device keychain (iOS Keychain, macOS Keychain, Android Keystore) and only stored in memory on the server side
- Secrets automatically redacted (including base64-encoded forms) from history and LLM context

### 2. Self-hosted

- No mandatory cloud dependency — bring your own LLM provider
- Optional relay service for push notifications and SSH public key provisioning

### 3. Local-first sync

- CRDT-based data model with real-time sync and offline mode
- Multiple clients can attach to the same session with shared state
- Full session history preservation and replication

## Features

- **Mobile and desktop clients** — iOS, Android, macOS, Linux, Windows
- **Cross-device sync** — CRDT-based sync through the self-hosted agent
- **Real-time sessions** — multiple clients can share the same terminal and chat
- **Session archival** — full transcript of every session, useful for postmortems
- **BYOM — bring your own model** () — supports OpenAI, Anthropic, Google, DeepSeek, Ollama, Groq, xAI, OpenRouter, and more
- **Custom agent instructions** — global and per-project system prompts with template variables
- **Command snippet library** — reusable commands injected into LLM context
- **Secret management** — global and per-project secrets, stored in keychain, with per-secret LLM visibility control

- **Push notifications** for long-running commands (optional relay service)


## Architecture overview

Fewshell has four components:

```
┌──────────────────┐       SSH tunnel         ┌──────────────────┐
│                  │       or mTLS            │                  │
│   Client App     │◄────────────────────────►│   Agent Server   │
│  (mobile/desktop)│                          │  (self-hosted)   │
│                  │                          │                  │
│  • Keychain      │                          │  • Shell (PTY)   │
│  • CRDT sync     │                          │  • CRDT sync     │
│  • Chat UI       │                          │  • Secret redact │
│  • SSH client    │                          │  • Agent loop    │
└──────────────────┘                          └────────┬─────────┘
                                                       │
                                                       │ API call
                                                       ▼
┌──────────────────┐                          ┌──────────────────┐
│                  │                          │                  │
│ Relay (optional) │                          │   LLM Provider   │
│                  │                          │  (user-provided) │
│ • Push notifs    │                          │                  │
│ • SSH public key │                          │  • Suggests cmds │
│                  │                          │  • Never executes│
└──────────────────┘                          └──────────────────┘
```

**Client** (mobile / desktop)
- Stores secrets in system keychain
- Generates SSH keypair (private key never leaves device)
- Sends user input and command approvals
- Displays terminal output and AI interaction

**Agent Server** (self-hosted)
- Executes approved shell commands in a PTY
- Streams command output to all connected clients
- Holds secrets in memory only during execution
- Redacts secret values before sending context to the LLM
- Calls the LLM API with redacted context

**LLM Provider** (user-provided)
- Receives redacted command and output context
- Suggests next commands
- Cannot execute anything directly

**Relay** (optional)
- Sends push notifications for long-running commands (APNs)
- Facilitates SSH public key exchange during device pairing

### Flow

1. User describes intent
2. Agent server sends context to LLM
3. LLM suggests a command
4. User reviews, edits, or rejects
5. On approval, server executes command
6. Output is streamed back to all connected clients
7. Output (with secrets redacted) is added to LLM context

## Security model

Fewshell assumes:

- The client device is trusted
- The server is controlled by the user
- The LLM provider may be untrusted

Key properties:

- Secrets are stored in the device keychain and synced to the server over an encrypted channel
- Secrets are held in server memory only during execution — never persisted to disk on the server
- Secrets are redacted (plaintext and base64) before being sent to the LLM
- The LLM cannot execute commands — all tool calls require explicit user approval
- Client–server connections use mTLS with certificate pinning, or SSH tunnels
- Server identity is verified via CRDT node ID to prevent cross-server sync

## Project structure

| Directory | Description |
|---|---|
| `decamp-app/` | Flutter client (iOS, Android, macOS, Linux, Windows) |
| `decamp-agent/` | Dart server — shell execution, sync, agent loop |
| `agent-core/` | Shared library — database schema, CRDT, LLM integration |
| `decamp-relay/` | Rust microservice — push notifications, SSH key pairing |
| `llm_dart/` | LLM provider library — multi-provider, streaming, tool use |
| `dartssh2/` | SSH client library (fork with domain socket support) |
| `native_pty/` | Native PTY bindings for Linux/macOS |

## Getting started

See the [Quick Start Guide](https://fewshell.com/docs/getting-started/quick-start/).

## Status

Early-stage. Expect rough edges.

## License

This project is licensed under the [GNU Affero General Public License v3.0](LICENSE) (AGPL-3.0).

You can use, modify, and self-host freely. If you run a modified version and expose it over a network, you must provide the source code.
