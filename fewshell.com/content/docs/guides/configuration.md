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

- **User** — Applied across all projects.
- **Per-Project** — Override global settings for a specific project.

Per-project settings always take precedence over global settings.

## Project Settings

Each project can be configured with:

- **SSH Tunnel** — Host, port, and SSH key or password. You can reuse the tunnel setting for multiple projects.

- **Secrets** — Allows managing the encrypted credentials and API keys. These are stored in the OS keychain. When running commands, you can select from a list of secrets you defined to pass to the command as environment variables. The server does not persist these secrets to disk and will redact them from the conversation history.

The list of secret variable names are passed to the system prompt
for the LLM. This allows better understanding of context and
for the LLM to guess which secrets to pre-fill when requesting
to execute a command.

NOTE: The LLM can never see the contents of the secrets, only the names.

Secrets will automatically synchronize between your authenticated, connected devices as long as these devices are connected to the server at the same time.

The Secrets page will also display internal/system secrets such as SSH private key used by your app.

- **AI Models** - You can configure one or more models for each project and switch between them as needed. When you configure a model endpoint with an API key, it will show up in the Secrets
page.

- **Snippets** - You can define frequently used commands, long command examples or proprietary commands. These get passed to the context.

- **Quick Prompts** - Frequently-used prompts. Eg "Get the last 30 minutes of error logs from cloud watch logs"

- **Agent Instructions** - This is the system prompt that is passed to the session. It is scoped as both, User setting and Project setting. You can combine both into one prompt such that
user setting prompt is prepended with the project setting prompt.
For example, the user setting prompt might have the general instruction, while the Project setting would contain specific instructions for the infrastructure and systems that you use for that project.

