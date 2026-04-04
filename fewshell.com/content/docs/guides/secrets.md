+++
title = "Secrets Management"
description = "Securely manage credentials and API keys in Fewshell."
date = 2026-03-01
weight = 20
template = "docs/page.html"

[extra]
lead = "Keep your credentials safe with Fewshell's built-in secrets management."
toc = true
+++

## Overview

Fewshell provides secure storage for sensitive values like API keys, passwords, and tokens. Secrets are encrypted at rest and can be scoped globally or per-project.

## Adding Secrets

1. Navigate to **Project Settings** → **Secrets**.
2. Select User Secrets or Project Secrets tab as desired.
3. Tap **Add User Secret** or **Add Project Secret.**
4. Enter a name of the environment variable. Eg `GOOGLE_API_KEY`.
NOTE: Only valid UNIX environment variable name characters are allowed.
5. You can enable or disable secret visibility. NOTE: The actual secret content is *never* visible to the agent. Only the name of the secret is visible and whether it can be used.

## Using Secrets in Sessions

Secrets are available during shell sessions. The agent is aware of configured secrets (by their names) and can reference them when composing commands. The system will never expose the values in the chat history.

CAUTION: Shell commands and shell scripts that you use on your system can potentially leak secrets by writing them to log files or exposing them in the process list. While fewshell itself protects its commands and redacts the secrets from history, it is the responsibility of the user to ensure their host is a trusted system and that the scripts and tools they run will not expose secrets to other users of the system or the internet.

## Security

- Secrets are encrypted using platform-native secure storage.
- Values are never logged or stored in plain text by Fewshell.
- Secrets are transmitted to servers only over encrypted SSH tunnel.
