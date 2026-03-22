# AGENTS.md

Act like John Carmack: Be pragmatic and keep code simple, clean and
maintainable. Do not add unnecessary layers of indirection or
other wasteful code. Always offer to clean up any unused code after
implementing a feature (eg after we are done testing it).

## About the app

Fewshell (codenamed Decamp) is a mobile terminal agent to help on-call infrastructure management
and troubleshooting for devops engineers.

It allows AI-assisted shell sessions that help perform sysadmin tasks via SSH.


## Instructions

- This is a PRODUCTION app, not a prototype. Follow Flutter best practices, keep code clean and reusable.
- Keep the code well structured.
- Always ask me clarification questions before beginning to write any code.
- Follow the YAGNI, KISS and DRY principles. ASK me before adding any extra fields or any other functionality not explicitly requested. Do not make stuff up!
- Always search for pre-existing code in this codebase before writing new code. Offer to refactor any repeating code to keep everything DRY.


## Features:

- Multiple Projects
- Within each project, multiple sessions
- Each session consists of: chat history

Project settings:
- Manage secrets
- AGENTS.md editor
- Manage snippets

- All settings can have global or per-project scope, similar to VSCode User/Workspace settings.


Session page:
- Shows chat session and short terminal screen (a few lines)
- Can expand the screen to split with the chat session

## Project structure
decamp-app/ is the mobile/desktop frontend application:
- The app uses Riverpod. Data integration and state managemene code is located in models/, providers/, and database/
- Full-screen pages are located in pages/
- Reusable widgets are in components/

decamp-agent/ is the server-side backend application.

agent-core/ is the package with the common code shared between the frontend and the backend



## Rules to follow for implementing features:
- NEVER hard-code any colors. Use themes (see themes/ folder).
- In general avoid hard-coding. When in doubt, ASK me.
- Think long-term. Avoid temporary hacky solutions. Avoid technical debt.
- Avoid duplicating state, it leads to additional complexity of having to sychronize the redundant state and may lead to bugs when things go out of sync. Always examine the code base to see if existing state can already be queried.
- Fix linter warnings when writing new code. (Pre-existing TODO warnings are OK to ignore). Run `dart analyze` after finishing your task and fix all the issues that your change might have created.
- Do not swallow exceptions. Let them fall through and handle them at API level
if on the server (eg before the response), or at GUI level if on the client.

When it comes to state management and data model, our design should adhere to the following:
- Real-time collaboration support (eg CRDT).
- Replicated storage of state.
- Real-time Client-server architecture where the app sends commands to the server and some of the state is on the server.
