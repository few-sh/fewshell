+++
title = "Fewshell — SSH Copilot for On-Calls"
description = "Fewshell is a self-hosted AI SSH client for iOS, Android, macOS and Linux. Run DevOps and on-call tasks from any device with secret redaction and human approval on every command."

template = "homepage.html"
[extra]
stylesheets = ["css/custom.css"]
+++

**Fewshell** is an SSH copilot for on-call engineers, sysadmins, DevOps and MLOps teams. Fearlessly use AI to troubleshoot and run commands on your infrastructure from any phone or desktop — every command approved by you, every secret redacted from the model.

<div class="get-app-section">
<div class="get-app-badges">

<a href="https://apps.apple.com/us/app/fewshell/id6755896752" target="_blank"><img src="/app-store-badge.svg" alt="Download on the App Store" height="40"></a>

<a href="https://play.google.com/store/apps/details?id=sh.few.fewshell" target="_blank"><img src="/google-play-badge.png" alt="Download for macOS" style="height: 40px; vertical-align: middle;"></a>

<a href="https://release.few.sh/releases/latest/Fewshell-1.0.2.dmg" target="_blank"><img src="/macos-badge.png" alt="Download for macOS" style="height: 40px; vertical-align: middle;"></a>

<a href="https://release.few.sh/releases/latest/fewshell-app-linux-amd64.tar.gz" target="_blank"><img src="/linux-badge.png" alt="Get it on Linux" style="height: 40px; vertical-align: middle;"></a>

<a href="https://release.few.sh/releases/latest/fewshell-app-linux-arm64.tar.gz" target="_blank"><img src="/linux-badge-arm64.png" alt="Get it on Linux ARM64" style="height: 40px; vertical-align: middle;"></a>

[Quick Start Guide](/docs/getting-started/quick-start/)

[Source Code](https://github.com/few-sh/fewshell)

</div>
<div class="get-app-screenshots">
<img src="/fewshell-ai-ssh-client-ios.png" alt="Fewshell AI SSH client on iPhone approving a shell command" class="screenshot-ios">
<img src="/fewshell-ai-ssh-client-desktop.png" alt="Fewshell AI SSH copilot on macOS desktop with terminal and chat" class="screenshot-desktop">
</div>
</div>

## Features

### Security
Secrets stored in your device's keychain, automatically redacted from AI. Never stored on disk. [Learn how secrets work →](/docs/guides/secrets/)

### Privacy
No cloud services, no sign-ups. Works with your existing infrastructure. Use self-hosted models or frontier providers.

### Ergonomics
Turn "clean up old Docker images" into `docker images --format '{{.Repository}}:{{.Tag}} {{.CreatedSince}} {{.Size}}' | grep -E 'months|years' | awk '{print $1}' | xargs -r docker rmi` — reviewed and approved before anything runs.

### Safety
Every command requires your explicit approval. There is no way to turn this off. No accidents or surprises. Designed for critical infrastructure.

### Transparency
Every interaction recorded on your device and your server. Know exactly what changed and when.

### Control
Organize projects, prompts, context, and snippets. Keep your workflows at your fingertips. Set up on your desktop and seamlessly sync to your phone. [Configure Fewshell →](/docs/guides/configuration/)

### Collaboration
Connect multiple devices and share real-time sessions. Share with your team or seamlessly switch between desktop and mobile - securely over your SSH tunnel.

### Simplicity
Easy to set up. Minimalist interface. Designed to do one thing and do it well. [Quick start guide →](/docs/getting-started/quick-start/)

## Frequently asked questions

### Can the AI run shell commands without my approval?
No. Every command the model proposes is staged for your review in the terminal UI and only executes after you explicitly approve it. This behavior cannot be disabled.

### Which LLM providers does Fewshell support?
Fewshell is BYOM — bring your own model. It works with OpenAI, Anthropic (Claude), Google Gemini, DeepSeek, xAI, Groq, OpenRouter, and any OpenAI-compatible endpoint including self-hosted Ollama.

### Is Fewshell self-hosted?
Yes. The Fewshell agent runs on a server you control (any Linux or macOS host with SSH). Clients connect over your SSH tunnel — there is no Fewshell cloud service in the data path.

### Does Fewshell send my secrets to the LLM?
No. Secrets are stored in your device keychain and held only in server memory. Their values — in both plaintext and base64 — are redacted from the context sent to the LLM.

### What devices does Fewshell run on?
Fewshell has native clients for iOS, Android, macOS, and Linux (x86_64 and ARM64). Windows support is planned.

### Is Fewshell open source?
Yes. Fewshell is licensed under AGPL-3.0. [Source on GitHub](https://github.com/few-sh/fewshell).


<script src="/js/custom.js"></script>
