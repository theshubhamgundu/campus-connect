import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group.dart';
import '../../models/user.dart';
import '../../services/group_service.dart';
import '../../services/user_service.dart';
import '../../widgets/avatar.dart';
import '../../widgets/loading_button.dart';

class GroupMembersScreen extends StatefulWidget {
  final Group group;
  final bool isAdmin;

  const GroupMembersScreen({
    Key? key,
    required this.group,
    this.isAdmin = false,
  }) : super(key: key);

  @override
  _GroupMembersScreenState createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final _searchController = TextEditingController();
  
  bool _isLoading = true;
  bool _isAddingMembers = false;
  List<User> _members = [];
  List<User> _filteredMembers = [];
  List<User> _availableUsers = [];
  List<User> _selectedUsers = [];
  
  final UserService _userService = UserService();
  late GroupService _groupService;
  
  @override
  void initState() {
    super.initState();
    _groupService = Provider.of<GroupService>(context, listen: false);
    _loadData();
    _searchController.addListener(_filterMembers);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    try {
      // In a real app, you would fetch members and available users from your services
      // For now, we'll use placeholder data
      _members = List.generate(5, (index) => User(
        id: 'member_$index',
        name: 'Member ${index + 1}',
        email: 'member${index + 1}@example.com',
        isOnline: index % 3 == 0, // Some online, some offline
      ));
      
      _availableUsers = List.generate(10, (index) => User(
        id: 'user_$index',
        name: 'User ${index + 1}',
        email: 'user${index + 1}@example.com',
      )).where((user) => !_members.any((m) => m.id == user.id)).toList();
      
      _filteredMembers = List.from(_members);
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to load members');
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _filterMembers() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredMembers = _members.where((user) {
        return user.name.toLowerCase().contains(query) ||
               user.email.toLowerCase().contains(query);
      }).toList();
    });
  }
  
  void _toggleAddMembers() {
    setState(() {
      _isAddingMembers = !_isAddingMembers;
      _selectedUsers.clear();
      if (!_isAddingMembers) {
        _searchController.clear();
        _filterMembers();
      }
    });
  }
  
  Future<void> _addSelectedMembers() async {
    if (_selectedUsers.isEmpty) return;
    
    try {
      // In a real app, you would call your group service to add members
      // await _groupService.addGroupMembers(
      //   widget.group.id,
      //   _selectedUsers.map((u) => u.id).toList(),
      // );
      
      setState(() {
        _members.addAll(_selectedUsers);
        _availableUsers.removeWhere((user) => 
          _selectedUsers.any((u) => u.id == user.id)
        );
        _selectedUsers.clear();
        _isAddingMembers = false;
        _searchController.clear();
        _filterMembers();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Members added successfully')),
        );
      }
    } catch (e) {
      _showError('Failed to add members');
    }
  }
  
  Future<void> _removeMember(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove ${user.name} from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'REMOVE',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // In a real app, you would call your group service to remove the member
        // await _groupService.removeGroupMember(widget.group.id, user.id);
        
        setState(() {
          _members.removeWhere((m) => m.id == user.id);
          _availableUsers.add(user);
          _filteredMembers = List.from(_members);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member removed')),
          );
        }
      } catch (e) {
        _showError('Failed to remove member');
      }
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  Widget _buildMemberList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_filteredMembers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No members found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (widget.isAdmin)
              TextButton(
                onPressed: _toggleAddMembers,
                child: const Text('Add Members'),
              ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _filteredMembers.length,
            itemBuilder: (context, index) {
              final member = _filteredMembers[index];
              return ListTile(
                leading: Stack(
                  children: [
                    Avatar(
                      name: member.name,
                      imageUrl: member.avatarUrl,
                      radius: 24,
                    ),
                    if (member.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(member.name),
                subtitle: Text(
                  member.isOnline ? 'Online' : 'Last seen recently',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: member.isOnline ? Colors.green : null,
                  ),
                ),
                trailing: widget.isAdmin
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _removeMember(member),
                      )
                    : null,
                onTap: () {
                  // TODO: Show user profile
                },
              );
            },
          ),
        ),
        if (widget.isAdmin && !_isAddingMembers)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _toggleAddMembers,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Members'),
            ),
          ),
      ],
    );
  }
  
  Widget _buildAddMembersView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterMembers();
                      },
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: _availableUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No users available to add'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _toggleAddMembers,
                        child: const Text('Back to Members'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _availableUsers.length,
                  itemBuilder: (context, index) {
                    final user = _availableUsers[index];
                    final isSelected = _selectedUsers.any((u) => u.id == user.id);
                    
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedUsers.add(user);
                          } else {
                            _selectedUsers.removeWhere((u) => u.id == user.id);
                          }
                        });
                      },
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      secondary: Avatar(
                        name: user.name,
                        imageUrl: user.avatarUrl,
                        radius: 20,
                      ),
                    );
                  },
                ),
        ),
        if (_selectedUsers.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedUsers.length} selected',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _toggleAddMembers,
                      child: const Text('CANCEL'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addSelectedMembers,
                      child: const Text('ADD MEMBERS'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isAddingMembers ? 'Add Members' : 'Group Members',
        ),
        actions: [
          if (_isAddingMembers)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleAddMembers,
            )
          else if (widget.isAdmin)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'leave') {
                  // TODO: Handle leave group (with confirmation)
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'leave',
                  child: Text('Leave Group', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
      body: _isAddingMembers ? _buildAddMembersView() : _buildMemberList(),
    );
  }
}
