import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/websocket_service.dart';
import 'config/server_config.dart';
import 'services/identity_service.dart';
import 'services/chat_service.dart';

// Screens
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize notifications only on mobile
  if (!kIsWeb) {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  // Define the app theme
  final ThemeData appTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
  );

  // Initialize server config and start realtime connection in background
  await IdentityService.init();
  await ServerConfig.initialize();
  // Fire-and-forget; it auto-checks Wi‑Fi and connects on LAN
  unawaited(WebSocketService().initialize());
  // Initialize chat layer listeners
  unawaited(ChatService().initialize());

  // Run the app
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const SplashScreen(), // Or replace with LanTestScreen()
    ),
  );
}
