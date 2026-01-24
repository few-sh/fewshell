import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agent_core/agent_core.dart';
import '../services/storage/flutter_secure_storage_impl.dart';

// Circular import for provider access
import 'providers.dart';

// Re-export SecretsCrdt for providers.dart to import
export 'package:agent_core/agent_core.dart' show SecretsCrdt, Secret, KeychainService, SecretRedactor;

// Secret provider declarations are now in providers.dart
// This file is kept for potential future secret-related business logic
