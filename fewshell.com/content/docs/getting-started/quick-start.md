+++
title = "Quick Start"
description = "Get up and running with Fewshell in minutes."
date = 2026-03-01
weight = 20
template = "docs/page.html"

[extra]
lead = "Get Fewshell installed and connect to your first server."
toc = true
+++

# Prerequisites

1. A server with SSH access (Linux or macOS).
2. An LLM provider — Claude, OpenAI, or a self-hosted endpoint. For hosted providers, you'll need an API key.

[Claude](https://platform.claude.com/)
[OpenAI](https://platform.openai.com/api-keys)


3. A client device — macOS, Linux desktop, or iOS.

# 3-step Installation

## Setting up SSH keys via automated pairing

1. Download the client app: 
[iOS](https://apps.apple.com/us/app/fewshell/id6755896752) 
[Mac OS](https://release.few.sh/releases/latest/Fewshell-1.0.2.dmg)
[Desktop Linux - AMD64](https://release.few.sh/releases/1.0.2/fewshell-app-linux-amd64.tar.gz)
[Desktop Linux - ARM64](https://release.few.sh/releases/1.0.2/fewshell-app-linux-amd64.tar.gz)
Android - Coming soon!

2. Click Connect via SSH -> Automated Pairing -> Begin Pairing
the app will display a 6 digit pairing code that rotates every 30 seconds.


3. On your server, run the installation+pairing script:
```
curl -LsSf https://get.fewshell.com | bash
```
Enter the 6-digit code.

4. Verify the auto-detected IP (if you are on a lan or a VPN, you may need to adjust it).
Use the Test Connection button, if all works, hit save.

### How it works:

1. The client generates a public-private SSH key pair.
2. The public key is pulled by the installation+pairing script using the one-time 6 digit code. (We use a simple service to relay your public key.)
3. Your new public key is added to ~/.ssh/authorized_keys on your server. Private key is added to the keychain on the client.

If you prefer not using the relay, you can manually generate the key pair and paste the private key into the SSH tunnel dialog on the app.



## Adding LLM configuration

1. Tap on the upper-left menu icon. Go to Settings -> Add Model
2. Follow the on-screen instructions.

## Example Workflow

```
> Check disk usage on all servers
```

Fewshell will suggest and execute the appropriate commands, presenting results in a readable format.

## Next Steps

- Learn about [Configuration](../../guides/configuration/) to customize your setup.
- Explore [Secrets Management](../../guides/secrets/) to securely manage credentials.
