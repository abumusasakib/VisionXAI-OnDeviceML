import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class SettingsState extends Equatable {
  final Locale currentLocale;
  final List<Locale> availableLanguages;

  const SettingsState({
    required this.currentLocale,
    required this.availableLanguages,
  });

  // Override the `props` getter for Equatable comparison
  @override
  List<Object?> get props => [currentLocale, availableLanguages];

  // Implement the `copyWith` pattern
  SettingsState copyWith({
    Locale? currentLocale,
    List<Locale>? availableLanguages,
  }) {
    return SettingsState(
      currentLocale: currentLocale ?? this.currentLocale,
      availableLanguages: availableLanguages ?? this.availableLanguages,
    );
  }

  @override
  String toString() =>
      'SettingsState(currentLocale: $currentLocale, availableLanguages: $availableLanguages)';
}
