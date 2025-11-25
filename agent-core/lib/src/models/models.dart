// Models for project configuration and data.
//
// These models are shared between client and server:
// - ProjectSettings - LLM, SSH, and system prompt configuration
// - LlmSettings - LLM provider/model configuration
// - SshSettings - SSH connection configuration
// - Snippet - Reusable text snippets
// - SecretMetadata - Secret metadata (values stored separately)
// - Secret - Secret with value (server-side only)

export 'llm_settings.dart';
export 'ssh_settings.dart';
export 'project_settings.dart';
export 'snippet.dart';
export 'secret.dart';
