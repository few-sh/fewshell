/// Represents a single tool action with its parameters
class ToolAction {
  final String id;
  final String toolName;
  final Map<String, dynamic> params;
  bool isSelected;

  ToolAction({
    required this.id,
    required this.toolName,
    required this.params,
    this.isSelected = false, // Deselected by default
  });

  /// Primary display text - works for any tool type
  String get primaryDisplay {
    // For shell commands, show the command
    if (params['command'] != null) return params['command'].toString();
    // For fetch, show method + URL
    if (params['url'] != null) {
      final method = params['method']?.toString().toUpperCase() ?? 'GET';
      return '$method ${params['url']}';
    }
    // Fallback: show tool name
    return toolName;
  }

  String get explanation => params['explanation']?.toString() ?? '';
  bool get requiresPrivileges => params['sudo_required'] as bool? ?? false;

  // Legacy getters for backwards compatibility
  String get command => primaryDisplay;
  bool get isSudoRequired => requiresPrivileges;
}
