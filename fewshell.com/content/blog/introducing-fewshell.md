+++
title = "Introducing Fewshell: an SSH copilot built for on-calls"
description = "Why we built Fewshell — a self-hosted AI SSH client that keeps humans in the loop and secrets out of the LLM."
date = 2026-04-16
draft = true
[taxonomies]
tags = ["announcements"]
+++

SSH on a phone is painful. AI agents can help — but handing an autonomous agent root access to your production fleet is not something any on-call engineer wants to do at 3 a.m.

Fewshell is our take on the middle ground: a self-hosted AI SSH client where every command is proposed by the model and approved by you. Secrets never reach the LLM. Sessions sync between your desktop and phone over your own SSH tunnel. No cloud service sits in the middle.

This post is a placeholder — full launch write-up coming soon. In the meantime:

- [Quick start guide](/docs/getting-started/quick-start/)
- [How secrets are redacted](/docs/guides/secrets/)
- [Source on GitHub](https://github.com/few-sh/fewshell)
