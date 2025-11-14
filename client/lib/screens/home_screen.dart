import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../services/websocket_service.dart';
import '../services/connection_service.dart';
import '../providers/auth_provider.dart';
import 'chats_screen.dart';
import 'groups/groups_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _lastConnected = false;
  DateTime _lastToastAt = DateTime.fromMillisecondsSinceEpoch(0);
  VoidCallback? _connListener;
  
  final List<Widget> _screens = [
    const ChatsScreen(),
    const GroupsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
    // Subscribe to connection changes for throttled SnackBars via ConnectionService
    final conn = ConnectionService.instance;
    _lastConnected = conn.connectionStatus.value == ConnectionStatus.connected;
    _connListener = () {
      final connected = conn.connectionStatus.value == ConnectionStatus.connected;
      final now = DateTime.now();
      final elapsed = now.difference(_lastToastAt).inSeconds;
      if (connected != _lastConnected && elapsed >= 8) {
        _lastToastAt = now;
        _lastConnected = connected;
        if (!mounted) return;
        final text = connected ? 'Connected to CampusNet' : 'Disconnected — Connect to CampusNet Wi‑Fi';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
        );
      } else {
        _lastConnected = connected;
      }
    };
    conn.connectionStatus.addListener(_connListener!);
  }

  @override
  void dispose() {
    if (_connListener != null) ConnectionService.instance.connectionStatus.removeListener(_connListener!);
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // On app start, initialize ConnectionService using saved user info (if any).
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        final userId = userMap['userId']?.toString() ?? '';
        final name = userMap['name']?.toString() ?? userId;
        final role = userMap['role']?.toString() ?? 'student';
        // Start connection in background; don't block the UI
        Future(() async {
          try {
            await ConnectionService.instance.init(userId: userId, name: name, role: role);
          } catch (e) {
            // Log and continue; UI will show disconnected banner
            debugPrint('ConnectionService.init failed on startup: $e');
          }
        });
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _isLoading = false);
  }

  void _onTabTapped(int index) {
    if (_isLoading) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ws = WebSocketService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusNet'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                // TODO: Navigate to settings
              } else if (value == 'new_group') {
                // TODO: Create new group
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'new_group',
                child: Text('New group'),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Text('Settings'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Connection banner
                ValueListenableBuilder<ConnectionStatus>(
                  valueListenable: ConnectionService.instance.connectionStatus,
                  builder: (context, status, _) {
                    final connected = status == ConnectionStatus.connected;
                    if (connected) return const SizedBox(height: 0);
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      color: Colors.orange,
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off, color: Colors.white),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Disconnected from CampusNet. Reconnecting...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              if (authProvider.currentUser?.userId != null) {
                                // Attempt reconnect (use last known server IP or default)
                                ConnectionService.instance.connectTo('192.168.137.1');
                              }
                            },
                            child: const Text(
                              'Retry',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Content
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _screens,
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        showUnselectedLabels: true,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: _selectedIndex == 0 
                    ? Theme.of(context).primaryColor.withOpacity(0.1) 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 24),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chat, size: 24),
            ),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: _selectedIndex == 1 
                    ? Theme.of(context).primaryColor.withOpacity(0.1) 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.groups_outlined, size: 24),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.groups, size: 24),
            ),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: _selectedIndex == 2 
                    ? Theme.of(context).primaryColor.withOpacity(0.1) 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_outline, size: 24),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person, size: 24),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
