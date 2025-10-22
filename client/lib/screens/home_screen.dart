import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'chats_screen.dart';
import 'status_screen.dart';
import 'calls_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    const ChatsScreen(),
    const StatusScreen(),
    const CallsScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusNet'),
        backgroundColor: const Color(0xFF128C7E),
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
              // TODO: Handle menu item selection
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'new_group',
                  child: Text('New group'),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Text('Settings'),
                ),
              ];
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                // TODO: Implement new chat
              },
              backgroundColor: const Color(0xFF128C7E),
              child: const Icon(Icons.chat, color: Colors.white),
            )
          : _selectedIndex == 1
              ? FloatingActionButton(
                  onPressed: () {
                    // TODO: Implement new status
                  },
                  backgroundColor: const Color(0xFF128C7E),
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                )
              : _selectedIndex == 2
                  ? FloatingActionButton(
                      onPressed: () {
                        // TODO: Implement new call
                      },
                      backgroundColor: const Color(0xFF128C7E),
                      child: const Icon(Icons.add_ic_call, color: Colors.white),
                    )
                  : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF128C7E),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.update),
            label: 'Status',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call),
            label: 'Calls',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
