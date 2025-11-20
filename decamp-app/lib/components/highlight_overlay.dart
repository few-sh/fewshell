import 'package:flutter/material.dart';

/// Information about a highlight region
class HighlightInfo {
  final int offset;
  final int length;
  final Color color;
  final bool isActive;

  const HighlightInfo({
    required this.offset,
    required this.length,
    required this.color,
    this.isActive = false,
  });
}
