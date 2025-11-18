/// Application-wide constants

/// Maximum number of lines to display in a code block before truncating
const int kTerminalMaxLines = 24;

/// Number of lines to show from start and end when truncating
/// (shows first N + last N lines with ellipsis in between)
const int kTerminalEllipsisHalfLines = 12;

// IDEA: In the future we should grab this list from a central source or config
// or use the APIs to fetch supported models dynamically from their providers.

// ============================================================================
// LLM Model Constants
// ============================================================================

/// Supported models for OpenAI
const List<String> kOpenAIModels = [
  // GPT-5 models (latest recommended)
  'gpt-5.1-codex',
  'gpt-5.1',
  'gpt-5',
  'gpt-5-mini',
  'gpt-5-nano',
  'gpt-5-pro',
  'gpt-5-codex',
  'gpt-5.1-chat-latest',
  'gpt-5-chat-latest',
  // GPT-4.1 models
  'gpt-4.1',
  'gpt-4.1-mini',
  'gpt-4.1-nano',
  // GPT-4o models
  'gpt-4o',
  'gpt-4o-2024-11-20',
  'gpt-4o-2024-08-06',
  'gpt-4o-2024-05-13',
  'chatgpt-4o-latest',
  'gpt-4o-mini',
  'gpt-4o-mini-2024-07-18',
  // o-series reasoning models
  'o3',
  'o3-mini',
  'o3-pro',
  'o3-deep-research',
  'o4-mini',
  'o4-mini-deep-research',
  'o1',
  'o1-preview',
  'o1-preview-2024-09-12',
  'o1-mini',
  'o1-mini-2024-09-12',
  // GPT-4 Turbo models
  'gpt-4-turbo',
  'gpt-4-turbo-2024-04-09',
  'gpt-4-turbo-preview',
  'gpt-4-0125-preview',
  'gpt-4-1106-preview',
  // GPT-4 models
  'gpt-4',
  'gpt-4-0613',
  // GPT-3.5 Turbo models
  'gpt-3.5-turbo',
  'gpt-3.5-turbo-0125',
  'gpt-3.5-turbo-1106',
];

/// Supported models for Anthropic (Claude)
const List<String> kAnthropicModels = [
  // Claude 4 models (latest)
  'claude-haiku-4-5', // alias
  'claude-sonnet-4-5-20250929',
  'claude-sonnet-4-5', // alias
  'claude-haiku-4-5-20251001',
  'claude-opus-4-1-20250805',
  'claude-opus-4-1', // alias
  // Claude 3.5 models (legacy)
  'claude-3-5-sonnet-20241022',
  'claude-3-5-sonnet-20240620',
  'claude-3-5-haiku-20241022',
  // Claude 3 models (legacy)
  'claude-3-opus-20240229',
  'claude-3-sonnet-20240229',
  'claude-3-haiku-20240307',
];

/// Supported models for Google (Gemini)
const List<String> kGoogleModels = [
  // Gemini 3 models (latest)
  'gemini-3-pro',
  'gemini-3-pro-latest',
  // Gemini 2.5 models
  'gemini-2.5-pro',
  'gemini-2.5-pro-latest',
  'gemini-2.5-flash',
  'gemini-2.5-flash-latest',
  'gemini-2.5-flash-lite',
  'gemini-2.5-flash-lite-latest',
  // Gemini 2.0 models
  'gemini-2.0-flash',
  'gemini-2.0-flash-latest',
  'gemini-2.0-flash-lite',
  'gemini-2.0-flash-lite-latest',
  'gemini-2.0-flash-exp',
  // Generic latest aliases
  'gemini-pro-latest',
  'gemini-flash-latest',
  // Gemini 1.5 models (legacy)
  'gemini-1.5-pro',
  'gemini-1.5-pro-002',
  'gemini-1.5-pro-001',
  'gemini-1.5-flash',
  'gemini-1.5-flash-002',
  'gemini-1.5-flash-001',
  'gemini-1.5-flash-8b',
  // Gemini 1.0 models (legacy)
  'gemini-1.0-pro',
  'gemini-1.0-pro-001',
  'gemini-1.0-pro-vision',
];

/// Supported models for DeepSeek
const List<String> kDeepSeekModels = ['deepseek-chat', 'deepseek-reasoner'];

/// Supported models for Groq
const List<String> kGroqModels = [
  'llama-3.3-70b-versatile',
  'llama-3.1-70b-versatile',
  'llama-3.1-8b-instant',
  'llama-3.2-1b-preview',
  'llama-3.2-3b-preview',
  'llama-3.2-11b-vision-preview',
  'llama-3.2-90b-vision-preview',
  'mixtral-8x7b-32768',
  'gemma-7b-it',
  'gemma2-9b-it',
];

/// Supported models for xAI (Grok)
const List<String> kXAIModels = ['grok-beta', 'grok-vision-beta'];

/// Common Ollama models (users can add custom models)
const List<String> kOllamaModels = [
  'llama3.2',
  'llama3.1',
  'llama3',
  'llama2',
  'mistral',
  'mixtral',
  'codellama',
  'phi3',
  'gemma',
  'gemma2',
  'qwen2.5',
  'qwen2',
  'deepseek-coder',
  'deepseek-r1',
  'yi',
  'solar',
  'vicuna',
  'orca-mini',
];

/// Models for OpenAI-compatible APIs (generic suggestions)
const List<String> kOpenAICompatibleModels = [
  'gpt-4',
  'gpt-3.5-turbo',
  'claude-3',
  'llama-2',
  'mistral',
];
