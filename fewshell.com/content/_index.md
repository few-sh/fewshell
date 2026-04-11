+++
title = "Fewshell: Human-Gated AI SSH"

template = "homepage.html"
[extra]
stylesheets = ["css/custom.css"]
+++

Fearlessly use AI for your infrastructure.

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
<img src="/landing-screenshot-ios.png" alt="Fewshell on iOS" class="screenshot-ios">
<img src="/landing-screenshot-desktop.png" alt="Fewshell on desktop" class="screenshot-desktop">
</div>
</div>

## Features

##### Security
Secrets stored in your device's keychain, automatically redacted from AI. Never stored on disk.

##### Privacy
No cloud services, no sign-ups. Works with your existing infrastructure. Use self-hosted models or frontier providers.

##### Ergonomics
Turn "clean up old Docker images" into `docker images --format '{{.Repository}}:{{.Tag}} {{.CreatedSince}} {{.Size}}' | grep -E 'months|years' | awk '{print $1}' | xargs -r docker rmi` — reviewed and approved before anything runs.

##### Safety
Every command requires your explicit approval. There is no way to turn this off. No accidents or surprises. Designed for critical infrastructure.

##### Transparency
Every interaction recorded on your device and your server. Know exactly what changed and when.

##### Control
Organize projects, prompts, context, and snippets. Keep your workflows at your fingertips. Set up on your desktop and seamlessly sync to your phone.

##### Collaboration
Connect multiple devices and share real-time sessions. Share with your team or seamlessly switch between desktop and mobile - securely over your SSH tunnel.

##### Simplicity
Easy to set up. Minimalist interface. Designed to do one thing and do it well.


<script src="/js/custom.js"></script>
