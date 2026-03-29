import 'package:flutter/material.dart';

enum AppAppearanceMode {
  system('system', 'System', ThemeMode.system),
  light('light', 'Light', ThemeMode.light),
  dark('dark', 'Dark', ThemeMode.dark);

  const AppAppearanceMode(this.storageValue, this.label, this.themeMode);

  final String storageValue;
  final String label;
  final ThemeMode themeMode;

  static AppAppearanceMode fromStorage(String? value) {
    for (final mode in values) {
      if (mode.storageValue == value) {
        return mode;
      }
    }
    return AppAppearanceMode.system;
  }
}
