import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_service.dart';
import '../services/chat_service_v2.dart';
import '../models/online_user.dart';
import 'direct_chat_screen_v2.dart';

class NearbyUsersScreen extends StatefulWidget {
  const NearbyUsersScreen({Key? key}) : super(key: key);

  @override
  _NearbyUsersScreenState createState() => _NearbyUsersScreenState();
}

class _NearbyUsersScreenState extends State<NearbyUsersScreen> {
  bool _loading = false;
  List<OnlineUser> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await ConnectionService.instance.fetchOnlineUsers();
      
      // FIX #3: Filter out the current user using both userId AND IP
      // This ensures that:
      // - If multiple users have the same ID but different IPs, only hide the current device
      // - Other users with the same ID are still visible
      final currentUserId = ConnectionService.instance.currentUserId;
      final currentDeviceIp = ConnectionService.instance.localDeviceIp;
      
      final filteredUsers = users.where((u) {
        // A user is "self" only if BOTH userId AND IP match
        final isSelf = (u.userId == currentUserId && u.ip == currentDeviceIp);
        return !isSelf;
      }).toList();
      
      print('🔍 Loaded ${users.length} users, filtered to ${filteredUsers.length} (self: $currentUserId@$currentDeviceIp)');
      setState(() => _users = filteredUsers);
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _users = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby CampusNet Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
              ? const Center(child: Text('No CampusNet users online'))
              : ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final u = _users[i];
                    return ListTile(
                      title: Text(u.name),
                      subtitle: Text('${u.role} • ${u.ip}'),
                      leading: CircleAvatar(child: Text(u.name.isNotEmpty ? u.name[0] : '?')),
                      onTap: () {
                        // Enrich ChatService with user name
                        Provider.of<ChatServiceV2>(context, listen: false)
                            .setUserInfo(u.userId, u.name);
                        
                        // Navigate to direct chat with this user
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DirectChatScreenV2(
                              receiverId: u.userId,
                              receiverName: u.name,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
