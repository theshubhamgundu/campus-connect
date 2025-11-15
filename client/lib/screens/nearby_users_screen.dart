import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connection_service.dart';
import '../services/chat_service_v3.dart';
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
      final currentUserId = ConnectionService.instance.currentUserId;
      
      print('🔍 Fetched ${users.length} users from server');
      print('   Current logged-in user: $currentUserId');
      for (final u in users) {
        print('   - ${u.userId} (${u.name}) at ${u.ip}');
      }
      
      // Filter out the current user by userId only
      final filteredUsers = users.where((u) {
        final isMe = u.userId == currentUserId;
        if (isMe) {
          print('   ❌ Filtering out self: $currentUserId');
        }
        return !isMe;
      }).toList();
      
      print('✅ After filtering: ${filteredUsers.length} users remaining');
      setState(() => _users = filteredUsers);
    } catch (e) {
      print('❌ Error loading users: $e');
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
                        print('👉 TAPPED USER: ${u.userId} - ${u.name}');
                        
                        // Enrich ChatService with user name
                        Provider.of<ChatServiceV3>(context, listen: false)
                            .setUserName(u.userId, u.name);
                        
                        print('📱 Navigating to DirectChatScreenV2...');
                        
                        // Navigate to direct chat with this user
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DirectChatScreenV2(
                              receiverId: u.userId,
                              receiverName: u.name,
                            ),
                          ),
                        ).then((result) {
                          print('✅ Returned from chat screen');
                        });
                      },
                    );
                  },
                ),
    );
  }
}
