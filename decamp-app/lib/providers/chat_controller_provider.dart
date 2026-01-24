import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';

// Circular import for provider access
import 'providers.dart';

// Re-export classes for providers.dart to import
export 'package:agent_core/agent_core.dart' show ChatController, ChatState;

// Chat controller provider declarations are now in providers.dart
// This file is kept for potential future chat controller-related business logic
