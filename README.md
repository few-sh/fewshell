# fewshell

**A self-hosted AI agent for sysadmins, on-calls, devops, MLOps, AI researchers and self-hosting enthusiasts.**

<a href="https://apps.apple.com/us/app/fewshell/id6755896752"><img src="https://fewshell.com/app-store-badge.svg" alt="Download on the App Store" height="40"></a>
<a href="https://play.google.com/store/apps/details?id=sh.few.fewshell" target="_blank"><img src="https://fewshell.com/google-play-badge.png" alt="Download on Google Play" style="height: 40px; vertical-align: middle;"></a>
<a href="https://release.few.sh/releases/latest/Fewshell-1.0.2.dmg"><img src="https://fewshell.com/macos-badge.png" alt="Download for macOS" height="40"></a>
<a href="https://release.few.sh/releases/1.0.2/fewshell-app-linux-amd64.tar.gz"><img src="https://fewshell.com/linux-badge.png" alt="Get it on Linux" height="40"></a>
<a href="https://release.few.sh/releases/1.0.2/fewshell-app-linux-arm64.tar.gz"><img src="https://fewshell.com/linux-badge-arm64.png" alt="Get it on Linux (ARM64)" height="40"></a>

[Quick Start](https://fewshell.com/docs/getting-started/quick-start/)

tl;dr - using ssh on a phone is painful. AI can help, but agents are risky and hard to configure for critical tasks.

fewshell is an attempt to solve this *without sacrificing security, privacy and safety*.

It's designed around three core principles:

1. Secure defaults: mandatory SSH and secrets management.
2. Must be self-hosted: Eg, cloudless desktop-mobile sync.
3. Human-first: AI will not run any command without your approval.

![Fewshell demo](https://release.few.sh/misc/github_anim_sm.gif)

## Why this exists

Use fewshell if you want to...

- Have a way to restart, fix, update your autonomous agent (eg OpenClaw) remotely, without using the agent itself (in case it fails to start back up.)
- Start some long-running command from your desktop and then check on it while on the go.
- Manage a self-hosted server remotely and run admin commands while on the go.
- Run serverless infrastructure and use cloud CLI to occasionally fix things remotely via a bastion.
- Keep track of every command you ever ran on your infrastructure, lab environment, etc through one interface.

## What fewshell is not:

It is not meant to be a coding agent or an autonomous AI assistant. There are many powerful open source and commercial agents for this. You can configure some to do the same or similar thing as Fewshell, but it usually takes extra effort. 

It is not packed with features or many customizable options. It's intended to do one thing and do it well.
Constrained by-design to allow easy setup and reduce the risk of accidental misconfiguration.

## Features

- **Mobile and desktop clients** — iOS, macOS, Linux, (Android and Windows planned)
- **Secret management** — user and per-project secrets, stored in keychain, with per-secret LLM visibility control
- **Cross-device sync** — seamless session sync between devices using your server
- **Command snippet library** — reusable commands injected into LLM context
- **Session archival** — full transcript of every session, useful for postmortems
- **BYOM — bring your own model** — supports OpenAI, Anthropic, Google, DeepSeek, Ollama, Groq, xAI, OpenRouter, and more
- **Custom agent instructions** — user and per-project system prompts with template variables

- **Push notifications** for long-running commands (optional relay service)


## Architecture overview

**fewshell client app** (mobile / desktop)
- Stores secrets in system keychain
- Optionally generates SSH keypair during setup (private key never leaves device)
- Sends user input and command approvals
- Displays terminal output and AI interaction

**fewshell server** (self-hosted)
- Executes approved shell commands in a PTY
- Streams command output to all connected clients
- Keeps persistent sessions and synchronizes them across multiple authenticated clients
- Holds secrets in memory for command use and replication across authenticated devices
- Redacts secret values before sending context to the LLM
- Calls the LLM API with redacted context

**LLM Provider** (self-hosted or third-party)
- Receives context, command input and output (secrets redacted)
- Requests command execution for human approval

**Notification Relay** (optional)
- Sends push notifications for long-running commands (APNs)
- Facilitates SSH public key provisioning during initial device pairing (optional)


![Fewshell architecture](fewshell-arch-diagram.png)

1. SSH Tunnel is the only communication link between client and server.
2. Domain socket: client connection is forwarded to the local domain socket on the host to communicate with the server. This provides additional access controls for host accounts. Eg, non-privilege users will only have access to their server instance.
3. OS Keychain stores the secrets (API keys, passwords) on the trusted client device.
4. SQLite is used on the client side for storage of sessions and offline support.
5. SQLite on the server side stores and replicates the authoritative session, chat history and project data. It is replicated to the connected clients in real time.
6. External API connection for LLM and relay over an untrusted network (HTTPS).
7. bash sessions are spawned by the server for executing commands.


## Security model

Fewshell assumes:

- The client device is trusted
- The server is controlled by the user
- The LLM provider may be untrusted

Key properties:

- Secrets are stored in the device keychain and synced to the server over SSH tunnel
- Secrets are held in server memory — never persisted to disk on the server
- Secrets are redacted (plaintext and base64) before being sent to the LLM
- The LLM cannot execute commands — all tool calls require explicit user approval
- Client–server connections SSH tunnel to user-owned domain socket on the server
- Server identity is verified via CRDT node ID to prevent cross-server sync

## Project structure

| Directory | Description |
|---|---|
| `decamp-app/` | Flutter client (iOS, Android, macOS, Linux, Windows) |
| `decamp-agent/` | Dart server — shell execution, sync, agent loop |
| `agent-core/` | Shared client/server code — database schema, CRDT, LLM integration |
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

If your organization disallows the use of AGPL, please [contact us](https://fewshell.com/contact/) for custom licensing options.
