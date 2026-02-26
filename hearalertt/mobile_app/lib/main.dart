import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:mobile_app/providers/sound_provider.dart';
import 'package:mobile_app/providers/settings_provider.dart';
import 'package:mobile_app/screens/splash_screen.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/firebase_database_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    // Sign in anonymously — gives each device a unique UID (no login screen).
    await AuthService().signInAnonymously();

    // Request notification permissions
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get the FCM token for this device
    String? fcmToken = await messaging.getToken();

    // Log this device's presence and token to Firebase
    FirebaseDatabaseService()
        .updatePresence(
          platform: 'android',
          appVersion: '1.0.0',
          fcmToken: fcmToken,
        )
        .catchError((e) => debugPrint('Presence update failed: $e'));

    // Listen for FCM token refreshes
    messaging.onTokenRefresh.listen((newToken) {
      FirebaseDatabaseService().updatePresence(fcmToken: newToken);
    });

  } catch (e) {
    debugPrint('Firebase init/auth failed (offline mode): $e');
  }

  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProxyProvider<SettingsProvider, SoundProvider>(
          create: (_) => SoundProvider(),
          update: (_, settings, soundProvider) =>
              soundProvider!..updateSettings(settings),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'HearAlert',
          debugShowCheckedModeBanner: false,
          // Use the dynamic theme generator
          theme: AppTheme.create(
            settings.accentColor,
            Brightness.light,
            highContrast: settings.highContrast,
            largeText: settings.largeText,
          ),
          darkTheme: AppTheme.create(
            settings.accentColor,
            Brightness.dark,
            highContrast: settings.highContrast,
            largeText: settings.largeText,
          ),
          themeMode: settings.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
