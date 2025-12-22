import 'package:flutter/material.dart';

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
