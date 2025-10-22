import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Profile'),
              background: Image.asset(
                'assets/images/profile_background.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey,
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'John Doe',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hey there! I am using CampusNet',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                _buildProfileItem(
                  icon: Icons.person_outline,
                  title: 'Account',
                  onTap: () {
                    // TODO: Navigate to account settings
                  },
                ),
                _buildProfileItem(
                  icon: Icons.chat_bubble_outline,
                  title: 'Chats',
                  onTap: () {
                    // TODO: Navigate to chat settings
                  },
                ),
                _buildProfileItem(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () {
                    // TODO: Navigate to notification settings
                  },
                ),
                _buildProfileItem(
                  icon: Icons.storage_outlined,
                  title: 'Storage and Data',
                  onTap: () {
                    // TODO: Navigate to storage settings
                  },
                ),
                _buildProfileItem(
                  icon: Icons.help_outline,
                  title: 'Help',
                  onTap: () {
                    // TODO: Show help
                  },
                ),
                _buildProfileItem(
                  icon: Icons.info_outline,
                  title: 'About',
                  onTap: () {
                    // TODO: Show about dialog
                  },
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Implement logout
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF128C7E),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Log Out',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF128C7E)),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
