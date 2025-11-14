import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/network_service.dart';

class OnlineUsersScreen extends StatefulWidget {
  const OnlineUsersScreen({Key? key}) : super(key: key);

  @override
  _OnlineUsersScreenState createState() => _OnlineUsersScreenState();
}

class _OnlineUsersScreenState extends State<OnlineUsersScreen> {
  late NetworkService _networkService;
  List<User> _onlineUsers = [];
  bool _isLoading = true;
  String? _error;
  Set<String> _pendingRequests = {};

  @override
  void initState() {
    super.initState();
    _networkService = NetworkService();
    _loadOnlineUsers();
  }

  Future<void> _loadOnlineUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // In a real app, this would call an endpoint like:
      // final users = await _networkService.getOnlineUsers();
      // For now, we'll use mock data
      final users = await _fetchOnlineUsers();

      if (mounted) {
        setState(() {
          _onlineUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load online users: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<User>> _fetchOnlineUsers() async {
    // Mock data - replace with actual API call
    await Future.delayed(const Duration(seconds: 1));
    return [
      User(
        userId: 'STU001',
        name: 'Alice Johnson',
        email: 'alice@campus.edu',
        role: UserRole.student,
        department: 'Computer Science',
        isOnline: true,
        lastSeen: DateTime.now(),
      ),
      User(
        userId: 'FAC001',
        name: 'Dr. Smith',
        email: 'smith@campus.edu',
        role: UserRole.faculty,
        department: 'Computer Science',
        isOnline: true,
        lastSeen: DateTime.now(),
      ),
      User(
        userId: 'STU002',
        name: 'Bob Wilson',
        email: 'bob@campus.edu',
        role: UserRole.student,
        department: 'Engineering',
        isOnline: true,
        lastSeen: DateTime.now(),
      ),
      User(
        userId: 'STU003',
        name: 'Carol Davis',
        email: 'carol@campus.edu',
        role: UserRole.student,
        department: 'Business',
        isOnline: true,
        lastSeen: DateTime.now(),
      ),
    ];
  }

  Future<void> _sendFriendRequest(User user) async {
    try {
      setState(() {
        _pendingRequests.add(user.userId);
      });

      await _networkService.sendFriendRequest(user, 'Hello, let\'s connect!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request sent to ${user.name}')),
        );
        setState(() {
          _pendingRequests.remove(user.userId);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pendingRequests.remove(user.userId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context).currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Now'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOnlineUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadOnlineUsers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _onlineUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          const Text('No online users right now'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOnlineUsers,
                      child: ListView.builder(
                        itemCount: _onlineUsers.length,
                        itemBuilder: (context, index) {
                          final user = _onlineUsers[index];
                          final isSelf = currentUser?.userId == user.userId;

                          return UserCard(
                            user: user,
                            isSelf: isSelf,
                            isPending: _pendingRequests.contains(user.userId),
                            onAddFriend: () => _sendFriendRequest(user),
                          );
                        },
                      ),
                    ),
    );
  }
}

class UserCard extends StatelessWidget {
  final User user;
  final bool isSelf;
  final bool isPending;
  final VoidCallback onAddFriend;

  const UserCard({
    Key? key,
    required this.user,
    required this.isSelf,
    required this.isPending,
    required this.onAddFriend,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      // Online indicator
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          user.isFaculty ? 'Faculty' : 'Student',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: user.isFaculty
                            ? theme.colorScheme.tertiaryContainer
                            : theme.colorScheme.secondaryContainer,
                        labelStyle: TextStyle(
                          color: user.isFaculty
                              ? theme.colorScheme.onTertiaryContainer
                              : theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (user.department != null)
                        Text(
                          user.department!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.userId,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Action Button
            if (!isSelf)
              ElevatedButton(
                onPressed: isPending ? null : onAddFriend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  disabledBackgroundColor: theme.colorScheme.outlineVariant,
                ),
                child: Text(
                  isPending ? 'Pending...' : 'Add',
                  style: TextStyle(
                    color: isPending
                        ? theme.colorScheme.outline
                        : theme.colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
