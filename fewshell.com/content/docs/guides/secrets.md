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
2. Tap **Add Secret**.
3. Enter a name and value.
4. Choose the scope (Global or Project).

## Using Secrets in Sessions

Secrets are available during shell sessions. The AI assistant is aware of configured secrets and can reference them when composing commands, without exposing the values in the chat history.

## Security

- Secrets are encrypted using platform-native secure storage.
- Values are never logged or stored in plain text.
- Secrets are transmitted to servers only over encrypted connections (mTLS).
