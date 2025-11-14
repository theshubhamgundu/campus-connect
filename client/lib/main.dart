import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'services/websocket_service.dart';
import 'services/group_service.dart';
import 'config/server_config.dart';
import 'services/identity_service.dart';
import 'services/chat_service.dart';
import 'providers/auth_provider.dart';

// Screens
import 'screens/entry_screen.dart';
import 'screens/login_screen_fixed.dart';
import 'screens/home_screen.dart' as home_screen;
import 'screens/onboarding/onboarding_screen.dart';

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
  
  // Initialize providers
  final authProvider = AuthProvider();
  final webSocketService = WebSocketService();
  
  // Note: Connection and discovery are handled by ConnectionService after login.
  // Keep WebSocketService instance available for legacy code paths.
  
  // Initialize chat layer listeners
  unawaited(ChatService().initialize());
  
  // Create GroupService instance
  final groupService = GroupService(webSocketService.channel, webSocketService.userId ?? 'user');
  
  // Run the app with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: webSocketService),
        Provider<GroupService>.value(value: groupService),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const EntryScreen(),
          '/login': (context) => const LoginScreenFixed(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/home': (context) => const home_screen.HomeScreen(),
        },
        onGenerateRoute: (settings) {
          // Handle any other routes here
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Not Found')),
              body: Center(
                child: Text('No route defined for ${settings.name}'),
              ),
            ),
          );
        },
      ),
    ),
  );
}
