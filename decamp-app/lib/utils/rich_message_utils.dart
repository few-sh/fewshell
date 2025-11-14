import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';

/// Utilities for creating rich message content with custom properties
class RichMessageUtils {
  /// Creates a message with selectable text (default behavior)
  static Map<String, dynamic> selectableMessage({bool showCopyButton = false}) {
    return {'enableTextSelection': true, 'showCopyButton': showCopyButton};
  }

  /// Creates a collapsible message section
  static Map<String, dynamic> collapsibleMessage({
    required String title,
    bool initiallyExpanded = false,
  }) {
    return {
      'enableTextSelection': true,
      'isCollapsible': true,
      'collapsibleTitle': title,
      'initiallyExpanded': initiallyExpanded,
    };
  }

  /// Creates an interactive message with action buttons
  static Map<String, dynamic> interactiveMessage({
    required List<MessageActionData> actions,
    bool enableTextSelection = true,
  }) {
    return {
      'enableTextSelection': enableTextSelection,
      'actions': actions.map((a) => a.toMap()).toList(),
    };
  }

  /// Creates a message with copy functionality
  static Map<String, dynamic> copyableMessage() {
    return {'enableTextSelection': true, 'showCopyButton': true};
  }

  /// Combines multiple message properties
  static Map<String, dynamic> combineProperties(
    List<Map<String, dynamic>> properties,
  ) {
    final combined = <String, dynamic>{};
    for (final props in properties) {
      combined.addAll(props);
    }
    return combined;
  }
}

/// Data class for message action buttons
class MessageActionData {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  MessageActionData({required this.label, this.icon, required this.onPressed});

  Map<String, dynamic> toMap() {
    return {'label': label, 'icon': icon, 'onPressed': onPressed};
  }
}

/// Extension methods for easy rich message creation
extension RichChatMessageExtensions on ChatMessage {
  /// Creates a copy with custom properties for rich content
  ChatMessage withRichProperties(Map<String, dynamic> properties) {
    return copyWith(customProperties: {...?customProperties, ...properties});
  }

  /// Creates a selectable message
  ChatMessage asSelectable({bool showCopyButton = false}) {
    return withRichProperties(
      RichMessageUtils.selectableMessage(showCopyButton: showCopyButton),
    );
  }

  /// Creates a collapsible message
  ChatMessage asCollapsible({
    required String title,
    bool initiallyExpanded = false,
  }) {
    return withRichProperties(
      RichMessageUtils.collapsibleMessage(
        title: title,
        initiallyExpanded: initiallyExpanded,
      ),
    );
  }

  /// Creates an interactive message with actions
  ChatMessage withActions(List<MessageActionData> actions) {
    return withRichProperties(
      RichMessageUtils.interactiveMessage(actions: actions),
    );
  }

  /// Creates a copyable message
  ChatMessage asCopyable() {
    return withRichProperties(RichMessageUtils.copyableMessage());
  }
}
