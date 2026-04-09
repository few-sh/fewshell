+++
title = "Quick Start"
description = "Get up and running with Fewshell in minutes."
date = 2026-03-01
weight = 20
template = "docs/page.html"

[extra]
toc = true
+++

You will need:

- A server with SSH (Linux or macOS).
- An API key from <a href="https://platform.claude.com/" target="_blank">Claude</a>, <a href="https://platform.openai.com/api-keys" target="_blank">OpenAI</a>, or any compatible provider or a self-hosted endpoint.

- A client device — iOS, MacOS, or Linux desktop.

# Get the app

<a href="https://apps.apple.com/us/app/fewshell/id6755896752" target="_blank"><img src="/app-store-badge.svg" alt="Download on the App Store" height="40"></a>

<a href="https://play.google.com/store/apps/details?id=sh.few.fewshell" target="_blank"><img src="/google-play-badge.png" alt="Download on Google Play" style="height: 40px; vertical-align: middle;"></a>

<a href="https://release.few.sh/releases/latest/Fewshell-1.0.2.dmg" target="_blank"><img src="/macos-badge.png" alt="Download for macOS" style="height: 40px; vertical-align: middle;"></a>

<a href="https://release.few.sh/releases/latest/fewshell-app-linux-amd64.tar.gz" target="_blank"><img src="/linux-badge.png" alt="Get it on Linux" style="height: 40px; vertical-align: middle;"></a>

<a href="https://release.few.sh/releases/latest/fewshell-app-linux-arm64.tar.gz" target="_blank"><img src="/linux-badge-arm64.png" alt="Get it on Linux" style="height: 40px; vertical-align: middle;"></a>

## SSH Setup (easy mode)

1. Click Connect via SSH -> Automated Pairing -> Begin Pairing.

<img src="/ssh-dialog.png" alt="SSH Pairing Dialog" style="max-width: 700px;">

2. On your server, run:
```
curl -LsSf https://get.fewshell.com | bash
```
Enter the 6-digit code.

3. Verify the information.
Use the Test Connection button, if all works, hit save.

NOTE: If you are on a LAN, behind a NAT or VPN, you may need to update the IP address in the dialog.

### How it works:

1. The client generates a public-private SSH key pair.
2. The public key is pulled by the installation+pairing script using the one-time 6 digit code. (We use a simple service to relay your public key.)
3. Your new public key is added to ~/.ssh/authorized_keys on your server. Private key is kept on the keychain on the client device.

If you prefer not using our relay, you can manually generate the key pair and paste the private key into the SSH tunnel dialog on the app.



## Adding LLM configuration

1. Tap on the upper-left menu icon. Go to Settings -> Add Model
2. Configure the settings, test until works, save.

<img src="/add-ai-model-dialog.png" alt="Add AI Model Dialog" style="max-width: 400px;">

## Example Workflow

```
> Check disk usage on all servers
```

Fewshell will suggest and execute the appropriate commands, presenting results in a readable format.

## Next Steps

- Learn about [Configuration](../../guides/configuration/) to customize your setup.
- Explore [Secrets Management](../../guides/secrets/) to securely manage credentials.
