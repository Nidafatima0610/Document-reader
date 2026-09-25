import 'package:all_documents_reader/core/theme/app_theme.dart';
import 'package:all_documents_reader/services/ad_mob_service.dart';
import 'package:all_documents_reader/services/premium_service.dart';
import 'package:all_documents_reader/services/settings_service.dart';
import 'package:all_documents_reader/views/home_view.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SettingsService.instance.init();
  try {
    await PremiumService.instance.init();
    await AdMobService.instance.initialize();
  } catch (e) {
    debugPrint('Monetization services initialization skipped or failed: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsService.instance.themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: currentThemeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const HomeView(),
        );
      },
    );
  }
}
