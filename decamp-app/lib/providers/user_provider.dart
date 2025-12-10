import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart';

class UserNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;
  static const String _key = 'username';

  UserNotifier(this._prefs) : super('User') {
    _loadUsername();
  }

  void _loadUsername() {
    final username = _prefs.getString(_key);
    if (username != null) {
      state = username;
    }
  }

  Future<void> setUsername(String username) async {
    state = username;
    await _prefs.setString(_key, username);
  }
}

final userProvider = StateNotifierProvider<UserNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UserNotifier(prefs);
});
