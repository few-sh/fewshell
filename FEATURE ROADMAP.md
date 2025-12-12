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

[ ] Project settings replication for LLM settings and secrets

[ ] Feedback button

[ ] Shared activity indicator (when a command is in progress or streaming is in progress, all clients should see the activity indicator)

[ ] Support for thoughts streaming and display (expandable)

[ ] "App needs an update"  Check app version and schema when connecting

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

[X] Eliminate all non-expandable ellipsis in any of the text controls

[X] Show currently active project on the projects page

[X] When selecting a peroject from projects list, close the projects page

[X] An indicator/icon when a project is remote

[X] A connection and activity indicator for remote project (eg when connected/disconnected, whebn sending data)

[X] Only sync the remote projects that belong to the agent

[ ] Auto-detect when SUDO fails and prompt for password, allow a checkbox to save the sudo password to secrets


## Bugs

[ ] If a remote project disconnects (eg server down), it falls back to using local mode. | Expected: Should block the user from typing messages, should have a clearer connection indication.

[ ] Loading state tends to get stuck for a whole session after a message gets interrupted (eg server goes down)

[ ] (Claude only) If a tool call is interrupted, it's not possible to send messages in that session again. We get an error: "tool_use ids were found without tool_result blocks"

[ ] Tool call is not working for gpt-5 (it tries execute_shell_command as the command)

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
