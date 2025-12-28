# FEATURE ROADMAP - HIGH LEVEL


### First customer use-case:

MVP (Version 0 - private alpha) - Typical use-case
1. User gets paged on slack or pagerduty or any other system
2. User opens Decamp
3. Asks decamp to investigate
4. Decamp queries the logs via ssh + google cloud logs
5. Decamp provides the log output and the summary.

### Critical path tasks (before first customer onboarding)

[ ] A stop button (ability to cancel a chat stream or any command)

[X] Project settings replication for LLM settings and secrets

[X] Feedback button

[X] Shared activity indicator (when a command is in progress or streaming is in progress, all clients should see the activity indicator)

[ ] Support for thoughts streaming and display (expandable)*
*Can't test

[ ] "App needs an update"  Check app version and schema when connecting

[X] Ability to connect to a remote server without creating a project. (To allow getting all of the project information from the remote server)

[ ] Always SUMMARIZE log and HTML outputs that are larger than X (tool outputs in general). (IDEA: Add summarize as part of the request tool)

[ ] ERROR HANDLING - stuck loading when error

[ ] For the header, leave a small button to show it

[ ] Add prompts list

[X] Be able to save certain prompts

[ ] A button for quick lookup of prompts and shell commands

[ ] Support adding multiple snippets from multi-tool command calls

[ ] Make snippets searchable

[ ] Move agent instructions to an SQLite table and make them versioned

[ ] Auto-Truncate SQLite log periodically to make sure it does not grow too big

[ ] Do not use natural keys for secrets

[ ] Add "Visible to AI" switch for secrets editing dialog.

### Smoother onboarding:
[X] When no project exists, automatically pop up the new project dialog

[X] Replace the OCR-based scan buttons with QR-based - (simplify to allow single field replacement)

[X] When no model configuration exists, guide the user through setting up.*

[X] Support sudo for local command execution at the remote agent side

[ ] Display step-by-step instructions in the app: eg instruct the user that they need a server
and access, "Open a terminal and ssh to your development machine, type curl ... get.few.sh | bash"

### General papercuts:
[ ] Add a context menu button to re-run command

[ ] Tool result should carry information about the original tool that we invoked

[ ] "Test SSH" button needs an ability to cancel the operation, or shorten the timeout.

[ ] "Test LLM" button needs an ability to cancel the operation, or shorten the timeout.

[X] Eliminate all non-expandable ellipsis in any of the text controls

[X] Show currently active project on the projects page

[X] When selecting a peroject from projects list, close the projects page

[X] An indicator/icon when a project is remote

[X] A connection and activity indicator for remote project (eg when connected/disconnected, whebn sending data)

[X] Only sync the remote projects that belong to the agent

[ ] Auto-detect when SUDO fails and prompt for password, allow a checkbox to save the sudo password to secrets


## Bugs

[X] If a remote project disconnects (eg server down), it falls back to using local mode. | Expected: Should block the user from typing messages, should have a clearer connection indication.

[X] Concatenation of user-level agent instruction with project-level agent instruction does not work. When we enable the checkbox, it does not remember the setting.

[ ] API Key secrets and others that have non-alphanumeric characters can't be edited - do not pop up the edit dialog, instead show a message with a deep link to the proper settings page.

[ ] Gemini 3 in llm_dart: tool calling does not work because is requires migration to support thoughtSignatures.
https://medium.com/google-cloud/migrating-to-gemini-3-implementing-stateful-reasoning-with-thought-signatures-4f11b625a8c9


[ ] Loading state tends to get stuck for a whole session after a message gets interrupted (eg server goes down)

[ ] (Claude only) If a tool call is interrupted, it's not possible to send messages in that session again. We get an error: "tool_use ids were found without tool_result blocks"

[X] Tool call is not working for gpt-5 (it tries execute_shell_command as the command)

-----------------------------------


[ ] +-- Add choice/action buttons to rich-chat-content.

Onboarding shell script:
[ ] Provide options for the user:
    = Guided "Wizard-like"
    = Custom "Select from various tools":
      - QR Code


Basic architecture:

[Phone] -> SSH -> [Appliance(Docker or micro isntance*) + gcloud CLI]
*NOTE: Micro instance preferred

### Error handling:
[ ] When not connected to server  

[X] When SSH throws an error

### Feature brainstorm (random ideas in no particular order)

[ ] Allow editing/viewing each chat section in raw JSON using https://pub.dev/packages/json_editor_flutter, ensure JSON is validated before saving

[ ] Ability to toggle a message as being visible/not visible to LLM

[ ] Built-in interactive terminal screen https://pub.dev/packages/xterm

+ [ Support for interactive and persistent sessions ] 

[X] Sync with desktop

[X] Sync across multiple users (live collaborative sessions)

[ ] Runbooks

[X] Snippets

[ ] Push notifications - we could set up our own service

[ ] Slack integration

[ ] Export sessions as markdown files

[ ] Import sessions from markdown files

[ ] Compact/summarize session

[ ] Display token usage

[X] Built-in fetch/curl tool for direct api calls without a shell box

[ ] A set of pre-made quick API references in a compressed, summarized format that the LLM can search/include

[ ] Ability to set up multiple SSH configurations (just like we have for models)

[ ] Ability to attach a note to anything, eg a note for an SSH configuration that LLM would see

[ ] Run a session inside a docker or podman environment

[ ] Integration with claude code CLI, exposing it as a tool

[ ] Display who is viewing/interacting with a session on the session card



Background agent:
[ ] Reactive system to alerts (Webhooks)

Onboarding:
[ ] Agent-guided onboarding

[ ] Need minimal tools to be able to invoke cloud APIs in order to:
    1. Spin up a docker instance
    2. Open a communication channel to it


## Website Design

[ ] some inspiration to conside https://archerhume.com/, https://www.abundant.ai/
