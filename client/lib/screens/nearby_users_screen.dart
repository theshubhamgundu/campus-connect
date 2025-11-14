import 'package:flutter/material.dart';
import '../services/connection_service.dart';
import '../models/online_user.dart';

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
      setState(() => _users = users);
    } catch (e) {
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
                        // Open chat screen with this userId
                        Navigator.pushNamed(context, '/chat', arguments: {'userId': u.userId, 'name': u.name});
                      },
                    );
                  },
                ),
    );
  }
}
