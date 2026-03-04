+++
title = "Configuration"
description = "Configure Fewshell projects, servers, and global settings."
date = 2026-03-01
weight = 10
template = "docs/page.html"

[extra]
lead = "Learn how to configure Fewshell for your infrastructure."
toc = true
+++

## Settings Scope

Fewshell settings can be configured at two levels, similar to VS Code's User/Workspace settings:

- **Global** — Applied across all projects.
- **Per-Project** — Override global settings for a specific project.

Per-project settings always take precedence over global settings.

## Project Settings

Each project can be configured with:

- **Server connections** — Host, port, and authentication details.
- **AGENTS.md** — Custom instructions for the AI assistant.
- **Secrets** — Encrypted credentials and API keys.
- **Snippets** — Reusable command templates.

## Editing AGENTS.md

The AGENTS.md file provides context to the AI assistant about your infrastructure. You can edit it directly within the app:

1. Open your project settings.
2. Navigate to the **AGENTS.md** tab.
3. Write instructions describing your infrastructure, common tasks, and preferences.

## GitHub Integration

Fewshell can sync snippets, markdown files, and tools from a GitHub repository, making it easy to share configurations across your team.
