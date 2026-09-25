import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._internal();
  static final SettingsService instance = SettingsService._internal();

  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyDefaultSort = 'app_default_sort';
  static const String _keyDefaultViewMode = 'app_default_view_mode';
  static const String _keyKeepScreenAwake = 'app_keep_screen_awake';
  static const String _keyFullscreenReading = 'app_fullscreen_reading';
  static const String _keyShowPageNumbers = 'app_show_page_numbers';
  static const String _keyAutoCacheCleanup = 'app_auto_cache_cleanup';
  static const String _keyConfirmBeforeDelete = 'app_confirm_before_delete';
  static const String _keyGeminiApiKey = 'app_gemini_api_key';
  static const String _keyAiProvider = 'app_ai_provider'; // 'local' or 'gemini'

  late SharedPreferences _prefs;

  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  final ValueNotifier<String> aiProviderNotifier = ValueNotifier<String>('local');

  final ValueNotifier<String> defaultSortNotifier = ValueNotifier<String>(
    'recent',
  );

  final ValueNotifier<String> defaultViewModeNotifier = ValueNotifier<String>(
    'vertical',
  );

  final ValueNotifier<bool> keepScreenAwakeNotifier = ValueNotifier<bool>(true);

  final ValueNotifier<bool> fullscreenReadingNotifier = ValueNotifier<bool>(
    false,
  );

  final ValueNotifier<bool> showPageNumbersNotifier = ValueNotifier<bool>(true);

  final ValueNotifier<bool> autoCacheCleanupNotifier = ValueNotifier<bool>(
    true,
  );

  final ValueNotifier<bool> confirmBeforeDeleteNotifier = ValueNotifier<bool>(
    true,
  );

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final themeModeStr = _prefs.getString(_keyThemeMode) ?? 'light';
    themeModeNotifier.value = _parseThemeMode(themeModeStr);

    defaultSortNotifier.value = _prefs.getString(_keyDefaultSort) ?? 'recent';
    defaultViewModeNotifier.value =
        _prefs.getString(_keyDefaultViewMode) ?? 'vertical';
    keepScreenAwakeNotifier.value = _prefs.getBool(_keyKeepScreenAwake) ?? true;
    fullscreenReadingNotifier.value =
        _prefs.getBool(_keyFullscreenReading) ?? false;
    showPageNumbersNotifier.value = _prefs.getBool(_keyShowPageNumbers) ?? true;
    autoCacheCleanupNotifier.value =
        _prefs.getBool(_keyAutoCacheCleanup) ?? true;
    confirmBeforeDeleteNotifier.value =
        _prefs.getBool(_keyConfirmBeforeDelete) ?? true;
    aiProviderNotifier.value = _prefs.getString(_keyAiProvider) ?? 'local';
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    await _prefs.setString(_keyThemeMode, _themeModeToString(mode));
  }

  Future<void> setDefaultSort(String sort) async {
    defaultSortNotifier.value = sort;
    await _prefs.setString(_keyDefaultSort, sort);
  }

  Future<void> setDefaultViewMode(String mode) async {
    defaultViewModeNotifier.value = mode;
    await _prefs.setString(_keyDefaultViewMode, mode);
  }

  Future<void> setKeepScreenAwake(bool value) async {
    keepScreenAwakeNotifier.value = value;
    await _prefs.setBool(_keyKeepScreenAwake, value);
  }

  Future<void> setFullscreenReading(bool value) async {
    fullscreenReadingNotifier.value = value;
    await _prefs.setBool(_keyFullscreenReading, value);
  }

  Future<void> setShowPageNumbers(bool value) async {
    showPageNumbersNotifier.value = value;
    await _prefs.setBool(_keyShowPageNumbers, value);
  }

  Future<void> setAutoCacheCleanup(bool value) async {
    autoCacheCleanupNotifier.value = value;
    await _prefs.setBool(_keyAutoCacheCleanup, value);
  }

  Future<void> setConfirmBeforeDelete(bool value) async {
    confirmBeforeDeleteNotifier.value = value;
    await _prefs.setBool(_keyConfirmBeforeDelete, value);
  }

  Future<String?> getGeminiApiKey() async {
    return _prefs.getString(_keyGeminiApiKey);
  }

  Future<void> setGeminiApiKey(String? key) async {
    if (key == null || key.trim().isEmpty) {
      await _prefs.remove(_keyGeminiApiKey);
    } else {
      await _prefs.setString(_keyGeminiApiKey, key.trim());
    }
  }

  Future<String> getAiProvider() async {
    return _prefs.getString(_keyAiProvider) ?? 'local';
  }

  Future<void> setAiProvider(String provider) async {
    aiProviderNotifier.value = provider;
    await _prefs.setString(_keyAiProvider, provider);
  }

  Future<int> getCacheSizeBytes() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!tempDir.existsSync()) return 0;
      int totalSize = 0;
      final entities = tempDir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          totalSize += entity.lengthSync();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint("Error calculating cache size: $e");
      return 0;
    }
  }

  Future<int> clearCache() async {
    int bytesFreed = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final entities = tempDir.listSync(followLinks: false);
        for (final entity in entities) {
          try {
            if (entity is File) {
              bytesFreed += entity.lengthSync();
              entity.deleteSync();
            } else if (entity is Directory) {
              final subEntities = entity.listSync(recursive: true, followLinks: false);
              for (final sub in subEntities) {
                if (sub is File) {
                  bytesFreed += sub.lengthSync();
                }
              }
              entity.deleteSync(recursive: true);
            }
          } catch (e) {
            debugPrint("Error deleting cached entity ${entity.path}: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("Error clearing cache: $e");
    }
    return bytesFreed;
  }

  Future<void> resetAllSettings() async {
    await setThemeMode(ThemeMode.light);
    await setDefaultSort('recent');
    await setDefaultViewMode('vertical');
    await setKeepScreenAwake(true);
    await setFullscreenReading(false);
    await setShowPageNumbers(true);
    await setAutoCacheCleanup(true);
    await setConfirmBeforeDelete(true);
  }
}
