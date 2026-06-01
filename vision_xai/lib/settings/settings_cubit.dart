import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:locale_names/locale_names.dart';
import 'package:vision_xai/settings/settings_state.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Cubit responsible for managing application settings, including
/// language preferences.
class SettingsCubit extends Cubit<SettingsState> {
  /// Initializes the [SettingsCubit] with a default state.
  ///
  /// The initial state sets the current locale to the first supported locale
  /// and provides all supported locales as available languages.
  SettingsCubit()
      : super(SettingsState(
          currentLocale: AppLocalizations.supportedLocales.first,
          availableLanguages: AppLocalizations.supportedLocales,
        )) {
    initializeSettings();
  }

  /// Initialize settings
  /// Initializes settings by loading saved preferences from Hive.
  ///
  /// - Loads the saved locale, defaulting to 'bn' (Bengali) if not found.
  /// - Emits a new state with the loaded settings.
  Future<void> initializeSettings() async {
    var box = await Hive.openBox('settings');

    final localeCode = box.get('locale', defaultValue: 'bn');
    final newLocale = AppLocalizations.supportedLocales.firstWhere(
      (locale) => locale.languageCode == localeCode,
      orElse: () =>
          const Locale('bn'), // Fallback to Bengali if locale not found
    );

    emit(state.copyWith(currentLocale: newLocale));

    debugPrint(
        'State emitted with locale: ${state.currentLocale.defaultDisplayLanguage}');
  }

  /// Update language preference
  /// Updates the application's language preference and persists it to Hive.
  ///
  /// Only updates if the [languageCode] is different from the current locale.
  /// Emits a new state with the updated locale.
  ///
  /// [languageCode]: The language code (e.g., 'en', 'bn') for the new locale.
  Future<void> updateLanguage(String languageCode) async {
    final newLocale = Locale(languageCode);
    if (state.currentLocale == newLocale) return;

    var box = await Hive.openBox('settings');
    await box.put('locale', languageCode);
    emit(state.copyWith(currentLocale: newLocale));
  }
}
