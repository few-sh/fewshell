# FEATURE ROADMAP - HIGH LEVEL


First customer use-case:

MVP (Version 0 - private alpha) - Typical use-case
1. User gets paged on slack or pagerduty or any other system
2. User opens Decamp
3. Asks decamp to investigate
4. Decamp queries the logs via ssh + google cloud logs
5. Decamp provides the log output and the summary.

[ ] Project settings replication for LLM settings and secrets


[ ] Feedback button
[ ] Shared activity indicator (when a command is in progress or streaming is in progress, all clients should see the activity indicator)
[ ] Support for thoughts streaming and display (expandable)
[ ] A stop button (ability to cancel a chat stream or any command)


Smoother onboarding:
[X] When no project exists, automatically pop up the new project dialog
[X] Replace the OCR-based scan buttons with QR-based - (simplify to allow single field replacement)
[X] When no model configuration exists, guide the user through setting up.*

[X] Support sudo for local command execution at the remote agent side

General papercuts:
[ ] Add a context menu button to re-run command
[X] Eliminate all non-expandable ellipsis in any of the text controls
[X] Show currently active project on the projects page
[X] When selecting a peroject from projects list, close the projects page

[X] An indicator/icon when a project is remote
[X] A connection and activity indicator for remote project (eg when connected/disconnected, whebn sending data)

[X] Only sync the remote projects that belong to the agent

[ ] Auto-detect when SUDO fails and prompt for password, allow a checkbox to save the sudo password to secrets




* Display step-by-step instructions in the app: eg instruct the user that they need a server
and access, "Open a terminal and ssh to your development machine, type curl ... get.few.sh | bash"


[ ] +-- Add choice/action buttons to rich-chat-content.

Onboarding shell script:
[ ] Provide options for the user:
    = Guided "Wizard-like"
    = Custom "Select from various tools":
      - QR Code


Basic architecture:

[Phone] -> SSH -> [Appliance(Docker or micro isntance*) + gcloud CLI]
*NOTE: Micro instance preferred

Error handling:
[ ] When not connected to server  
[X] When SSH throws an error

Feature brainstorm (random ideas in no particular order)

[ ] Sync with desktop
[ ] Sync across multiple users (live collaborative sessions)
[ ] Runbooks
[ ] Snippets
[ ] Push notifications - we could set up our own service
[ ] Slack integration
[ ] Export sessions as markdown files
[ ] Import sessions from markdown files
[ ] Compact/summarize session
[ ] Display token usage
[ ] Built-in fetch/curl tool for direct api calls without a shell box
[ ] A set of pre-made quick API references in a compressed, summarized format that the LLM can search/include
[ ] Ability to set up multiple SSH configurations (just like we have for models)
[ ] Abulity to add attach note to anything, eg a note for an SSH configuration that LLM would see
[ ] A toggle switch to toggle a segret to be "Available to agent", with a help tooltip: available means the agent can use it to provide to commands. SSH keys should not be available to the agent by default, but
is available for use by the underlying connection. All secrets are redacted from the LLM itself in the conversation.


Background agent:
[ ] Reactive system to alerts (Webhooks)

Onboarding:
[ ] Agent-guided onboarding
[ ] Need minimal tools to be able to invoke cloud APIs in order to:
    1. Spin up a docker instance
    2. Open a communication channel to it


## Website Desing

[ ] some inspiration to conside https://archerhume.com/, https://www.abundant.ai/
