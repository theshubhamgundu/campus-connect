import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group.dart';
import '../../services/group_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/group_list_item.dart';
import 'create_edit_group_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  _GroupsScreenState createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<Group> _groups = [];
  List<Group> _filteredGroups = [];
  StreamSubscription? _groupsSubscription;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final groupService = Provider.of<GroupService>(context, listen: false);
    
    // Load initial groups
    try {
      // In a real app, you would fetch groups from the server here
      // For now, we'll use an empty list and listen for updates
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load groups');
    }

    // Listen for group updates
    _groupsSubscription = groupService.watchGroups().listen((groups) {
      if (mounted) {
        setState(() {
          _groups = groups;
          _filterGroups(_searchController.text);
        });
      }
    });
  }

  void _filterGroups(String query) {
    setState(() {
      _filteredGroups = _groups.where((group) {
        return group.name.toLowerCase().contains(query.toLowerCase()) ||
            (group.description?.toLowerCase().contains(query.toLowerCase()) ?? false);
      }).toList();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _navigateToGroupChat(Group group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupChatScreen(group: group),
      ),
    );
  }

  void _showCreateGroupDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const CreateEditGroupScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateGroupDialog,
            tooltip: 'Create Group',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search groups...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _filterGroups,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredGroups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.group_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No groups yet!\nTap + to create one.'
                                  : 'No groups found',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadGroups,
                        child: ListView.builder(
                          itemCount: _filteredGroups.length,
                          itemBuilder: (context, index) {
                            final group = _filteredGroups[index];
                            return GroupListItem(
                              group: group,
                              onTap: () => _navigateToGroupChat(group),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        child: const Icon(Icons.group_add),
      ),
    );
  }
}
