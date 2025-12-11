+++
title = "Fewshell"
date = 2025-01-01
template = "page.html"
[extra]
stylesheets = ["css/custom.css"]
+++

Mobile assistant for DevOps practitioners and on-calls. Safely manage your infrastructure from anywhere.

<form class="signup-form" action="/api/signup" method="POST">
    <input type="email" name="email" placeholder="Enter your email" class="signup-input" required />
    <button type="submit" class="signup-button">Sign Up</button>
</form>

Already have Fewshell? [Set it up](@/qr.md)

## About

**Fewshell** is an AI-assistant for devops practitioners and on-calls with a strong emphasis on safety, allowing full management of cloud and on-premise infrastructure on the go without sacrificing effectiveness.

Infrastructure management and on-call has been a long-standing pain point for engineering teams across industries. Being on-call is a particularly dreaded part of the job for many software engineers and devops, requiring the on-call engineer to be within minutes of their laptop at all times.

AI researchers are also confronted with complex infrastructure. Training models involves highly parallelized workloads, such as RL with verifiable rewards, and distributing weights across many GPUs. With training runs that take hours or days, having visibility and being able to remotely stop a training run is essential.

## Features

##### Secure-by-default design
Full end-to-end encryption along with secrets storage on your device's keychain and automated redaction of secrets from all logs and AI.

##### First-class AI safety
You are always in control - no command is ever run without your approval.

##### A powerful sysadmin in your pocket
Familiar coding/shell assistant interface, optimized for mobile efficiency and ergonomics.

##### Full session history
Maintains a complete record of every interaction. Say goodbye to keeping a manual journal of what you changed and when.

##### Flexible architecture
Supports direct SSH or secure client-server WebSocket agent deployment.

##### Real-time collaboration
Optional support for team collaboration in client-server mode to keep your team in the loop and maintain full history of all sessions.

##### BYO Intelligence
Deploy in your own cloud and use your own language model (supports most frontier models, including Claude, OpenAI, and open weight models).

##### Secure sync
Synchronizes securely in real time between mobile, desktop, and tablet.

<script src="/js/custom.js"></script>
