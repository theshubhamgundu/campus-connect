import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/server_dashboard.dart';
import 'providers/server_provider.dart';

void main() {
  runApp(const CampusNetServerApp());
}

class CampusNetServerApp extends StatelessWidget {
  const CampusNetServerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ServerProvider(),
      child: MaterialApp(
        title: 'CampusNet Server',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
        ),
        home: const ServerDashboard(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}