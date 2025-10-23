import 'package:flutter/material.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  _GroupsScreenState createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final List<Map<String, dynamic>> _groups = [
    {
      'id': '1',
      'name': 'Campus Connect',
      'description': 'Official college announcements',
      'members': 250,
      'isPinned': true,
      'lastMessage': 'Welcome to Campus Connect!',
      'time': '10:30 AM',
      'unread': 0,
      'icon': Icons.school,
    },
    {
      'id': '2',
      'name': 'Class of 2023',
      'description': 'Batch 2023 students group',
      'members': 120,
      'isPinned': true,
      'lastMessage': 'Assignment due tomorrow!',
      'time': 'Yesterday',
      'unread': 3,
      'icon': Icons.group,
    },
    {
      'id': '3',
      'name': 'Study Group',
      'description': 'Study sessions and notes sharing',
      'members': 15,
      'isPinned': false,
      'lastMessage': 'Let\'s meet at the library',
      'time': '2h ago',
      'unread': 0,
      'icon': Icons.menu_book,
    },
  ];

  void _showGroupDetails(Map<String, dynamic> group) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                radius: 30,
                child: Icon(
                  group['icon'],
                  size: 30,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              group['name'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${group['members']} members',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              group['description'],
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to group chat
                },
                child: const Text('Open Group'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _groups.length,
        itemBuilder: (context, index) {
          final group = _groups[index];
          return Dismissible(
            key: Key(group['id']),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              setState(() {
                _groups.removeAt(index);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${group['name']} group dismissed'),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () {
                      setState(() {
                        _groups.insert(index, group);
                      });
                    },
                  ),
                ),
              );
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 1,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).primaryColor.withOpacity(0.2),
                  radius: 24,
                  child: Icon(
                    group['icon'],
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      group['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (group['isPinned'] == true) ...{
                      const SizedBox(width: 8),
                      const Icon(Icons.push_pin, size: 16, color: Colors.grey),
                    },
                  ],
                ),
                subtitle: Text(
                  group['lastMessage'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      group['time'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (group['unread'] > 0) ...{
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${group['unread']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    },
                  ],
                ),
                onTap: () => _showGroupDetails(group),
                onLongPress: () {
                  // Show options on long press
                  _showGroupOptions(group);
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateGroupDialog();
        },
        icon: const Icon(Icons.group_add),
        label: const Text('New Group'),
        elevation: 2,
      ),
    );
  }
}
