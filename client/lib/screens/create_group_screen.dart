import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/group_chat_service.dart';
import '../services/connection_service.dart';
import '../models/online_user.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final Set<String> _selectedMembers = {};
  List<OnlineUser> _availableUsers = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
  }

  Future<void> _loadAvailableUsers() async {
    setState(() => _loading = true);
    try {
      // Skip throttle for group creation UI to get immediate fresh list
      final users = await ConnectionService.instance.fetchOnlineUsers(skipThrottle: true);
      final currentUserId = ConnectionService.instance.currentUserId;
      
      // Filter out self
      final filtered = users.where((u) => u.userId != currentUserId).toList();
      
      setState(() => _availableUsers = filtered);
      print('✅ Loaded ${filtered.length} available users for group');
    } catch (e) {
      print('❌ Error loading users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    try {
      setState(() => _loading = true);

      final groupService = Provider.of<GroupChatService>(context, listen: false);
      final group = await groupService.createGroup(
        groupName: groupName,
        memberIds: _selectedMembers.toList(),
        description: _descriptionController.text.trim(),
      );

      print('✅ Group created: ${group.id} - ${group.name}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "$groupName" created successfully!')),
        );
        Navigator.pop(context, group);
      }
    } catch (e) {
      print('❌ Error creating group: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group name input
              TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'Enter group name',
                  prefixIcon: const Icon(Icons.group),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                enabled: !_loading,
              ),
              const SizedBox(height: 16),

              // Description input
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What is this group about?',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 2,
                enabled: !_loading,
              ),
              const SizedBox(height: 24),

              // Members selection header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Members (${_selectedMembers.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_selectedMembers.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _selectedMembers.clear()),
                      child: const Text('Clear All'),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Members list
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_availableUsers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('No other users available'),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _availableUsers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final user = _availableUsers[index];
                      final isSelected = _selectedMembers.contains(user.userId);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: !_loading
                            ? (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedMembers.add(user.userId);
                                  } else {
                                    _selectedMembers.remove(user.userId);
                                  }
                                });
                              }
                            : null,
                        title: Text(user.name),
                        subtitle: Text('${user.role} • ${user.ip}'),
                        secondary: CircleAvatar(
                          child: Text(user.name.isNotEmpty ? user.name[0] : '?'),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 32),

              // Create button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _createGroup,
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Group'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
