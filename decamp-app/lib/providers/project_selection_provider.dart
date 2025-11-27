import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';

/// Key for storing current project ID in SharedPreferences
const String _currentProjectIdKey = 'current_project_id';

/// StateProvider for the currently selected project ID
/// Initialized from SharedPreferences on first access
final currentProjectIdProvider = StateProvider<String?>((ref) {
  // Load from SharedPreferences on initialization
  final prefs = ref.watch(sharedPreferencesProvider);
  final savedProjectId = prefs.getString(_currentProjectIdKey);
  return savedProjectId;
});

/// Select a project as the current project
/// Persists the selection to SharedPreferences
Future<void> selectProject(WidgetRef ref, String? id) async {
  ref.read(currentProjectIdProvider.notifier).state = id;

  // Persist to SharedPreferences
  final prefs = ref.read(sharedPreferencesProvider);
  if (id != null) {
    await prefs.setString(_currentProjectIdKey, id);
  } else {
    await prefs.remove(_currentProjectIdKey);
  }
}
