+++
title = "Introduction"
description = "What is Fewshell and how it helps the on-call."
date = 2026-03-01
weight = 10
template = "docs/page.html"

[extra]
lead = "Fewshell is a mobile AI-assistant for MLOps, DevOps and Sysadmins. Connect to your infrastructure securely from any device and safely troubleshoot issues on the go, or just run things."
toc = true
+++

## What is Fewshell?

Fewshell is a human-gated, collaborative AI terminal agent. It runs on your server and syncs state directly across your desktop and mobile clients — no cloud service required. Every command is staged for your review. Nothing executes until you say so.

Modern LLMs excel at terminal tasks and keep getting better — but letting an autonomous agent run shell commands against production infrastructure is too risky. Fewshell gives you the AI leverage while keeping a human in the loop.

## Key Features

- **Human-gated** — AI assists, you approve. No command runs without explicit confirmation. There is no autonomous mode — it can't be accidentally enabled or misconfigured.
- **Self-hosted** — The agent runs on your server. Clients connect directly over SSH tunnel.
- **Real-time sync** — Snippets, prompts, and settings sync across desktop and mobile with no cloud service needed.
- **Collaborative** — Multiple engineers can join a session for real-time incident response.
- **Multi-project / multi-session** — Organize infrastructure into projects, each with multiple concurrent sessions and settings.
- **Shell snippets** — Quick-access command templates for common operations. Snippets also give the AI context about your infrastructure.
- **Custom system prompts** — Tailor the AI behavior per project to match your infrastructure and workflows.
- **Secrets management** — Secrets are stored in the client device keychain and automatically redacted from history. Never stored on disk or sent to LLM.
- **Session history & export** — Full audit trail of every session. Export for postmortems, compliance, or experiment tracking.
- **BYOM** — Bring your own model, or use any OpenAI/Claude-compatible endpoint. Self-host or connect to your preferred provider.

## Use Cases

- **Incident response** — DevOps and sysadmins investigate logs, triage alerts, and perform root cause analysis from any device.
- **ML labs** — Monitor, restart, or adjust training runs and rollouts. Troubleshoot GPU nodes and pipelines via shell commands.
- **Infrastructure health** — Check system state, diagnose issues, and tune performance across your fleet.
- **Serverless & cloud CLI** — Works with serverless and cloud infrastructure through AWS, gcloud, Azure, or any CLI — for when you need hands-on access beyond what IaC covers.*

> **Note:** For serverless, you need to run one micro instance that hosts the agent and has the CLI installed.

## Next Steps

Ready to get started? Head over to the [Quick Start](../quick-start/) guide.
