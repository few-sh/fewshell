import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

@immutable
class ShadLayoutTheme extends ThemeExtension<ShadLayoutTheme> {
  final EdgeInsets pagePadding;

  const ShadLayoutTheme({required this.pagePadding});

  @override
  ShadLayoutTheme copyWith({EdgeInsets? pagePadding}) {
    return ShadLayoutTheme(pagePadding: pagePadding ?? this.pagePadding);
  }

  @override
  ShadLayoutTheme lerp(ThemeExtension<ShadLayoutTheme>? other, double t) {
    if (other is! ShadLayoutTheme) {
      return this;
    }
    return ShadLayoutTheme(
      pagePadding: EdgeInsets.lerp(pagePadding, other.pagePadding, t)!,
    );
  }
}

ShadContextMenuTheme getShadContextMenuTheme() {
  final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  if (!isMobile) {
    return const ShadContextMenuTheme();
  }

  return const ShadContextMenuTheme(
    itemPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}
