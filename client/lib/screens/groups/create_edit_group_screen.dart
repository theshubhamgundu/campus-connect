import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/group.dart';
import '../../models/user.dart';
import '../../services/group_service.dart';
import '../../services/user_service.dart';
import '../../widgets/avatar.dart';
import '../../widgets/loading_button.dart';

class CreateEditGroupScreen extends StatefulWidget {
  final Group? group;

  const CreateEditGroupScreen({
    Key? key,
    this.group,
  }) : super(key: key);

  @override
  _CreateEditGroupScreenState createState() => _CreateEditGroupScreenState();
}

class _CreateEditGroupScreenState extends State<CreateEditGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPrivate = false;
  File? _imageFile;
  String? _imageUrl;
  
  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  List<User> _selectedUsers = [];
  
  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(_filterUsers);
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    
    try {
      // In a real app, you would fetch users from your user service
      // For now, we'll use a placeholder list
      _allUsers = List.generate(20, (index) => User(
        id: 'user_$index',
        name: 'User ${index + 1}',
        email: 'user${index + 1}@example.com',
      ));
      
      _filteredUsers = List.from(_allUsers);
      
      // If editing, populate the form with group data
      if (widget.group != null) {
        _nameController.text = widget.group!.name;
        _descriptionController.text = widget.group!.description ?? '';
        _isPrivate = widget.group!.isPrivate;
        _imageUrl = widget.group!.imageUrl;
        
        // In a real app, you would fetch the group members here
        // _selectedUsers = await _userService.getGroupMembers(widget.group!.id);
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to load data');
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        return user.name.toLowerCase().contains(query) ||
               user.email.toLowerCase().contains(query);
      }).toList();
    });
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _imageUrl = null; // Clear any existing URL if we have a new file
      });
    }
  }
  
  Future<void> _saveGroup() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedUsers.isEmpty) {
      _showError('Please add at least one member');
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final groupService = Provider.of<GroupService>(context, listen: false);
      final userService = Provider.of<UserService>(context, listen: false);
      
      final currentUserId = userService.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not logged in');
      }
      
      // Include current user in the members list
      final memberIds = _selectedUsers.map((u) => u.id).toList()..add(currentUserId);
      
      if (widget.group == null) {
        // Create new group
        await groupService.createGroup(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          memberIds: memberIds,
          isPrivate: _isPrivate,
          imageFile: _imageFile,
        );
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group created successfully')),
          );
        }
      } else {
        // Update existing group
        await groupService.updateGroup(
          groupId: widget.group!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          memberIds: memberIds,
          isPrivate: _isPrivate,
          imageFile: _imageFile,
        );
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group updated successfully')),
          );
        }
      }
    } catch (e) {
      _showError('Failed to save group');
      setState(() => _isSaving = false);
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Center(
        child: Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipOval(
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : _imageUrl != null
                        ? Image.network(_imageUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.group, size: 60, color: Colors.grey),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSelectedUsers() {
    if (_selectedUsers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Text('No members added yet'),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selected Members',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedUsers.length,
            itemBuilder: (context, index) {
              final user = _selectedUsers[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Avatar(
                          name: user.name,
                          imageUrl: user.avatarUrl,
                          radius: 30,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedUsers.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60,
                      child: Text(
                        user.name.split(' ')[0],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group == null ? 'Create Group' : 'Edit Group'),
        actions: [
          if (widget.group != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                // TODO: Implement delete group
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildImagePicker(),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Group Name',
                              prefixIcon: Icon(Icons.group),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a group name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description (Optional)',
                              prefixIcon: Icon(Icons.description),
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Private Group'),
                            subtitle: const Text(
                                'Only members can see who is in the group and what they post'),
                            value: _isPrivate,
                            onChanged: (value) {
                              setState(() {
                                _isPrivate = value;
                              });
                            },
                          ),
                          const Divider(),
                          _buildSelectedUsers(),
                          const Text(
                            'Add Members',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          TextField(
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
                                        _filterUsers();
                                      },
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _filteredUsers.isEmpty
                                ? const Center(child: Text('No users found'))
                                : ListView.builder(
                                    controller: _scrollController,
                                    itemCount: _filteredUsers.length,
                                    itemBuilder: (context, index) {
                                      final user = _filteredUsers[index];
                                      final isSelected = _selectedUsers.any((u) => u.id == user.id);
                                      
                                      return ListTile(
                                        leading: Avatar(
                                          name: user.name,
                                          imageUrl: user.avatarUrl,
                                        ),
                                        title: Text(user.name),
                                        subtitle: Text(user.email),
                                        trailing: isSelected
                                            ? const Icon(Icons.check_circle, color: Colors.green)
                                            : const Icon(Icons.add_circle_outline),
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedUsers.removeWhere((u) => u.id == user.id);
                                            } else {
                                              _selectedUsers.add(user);
                                            }
                                          });
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: LoadingButton(
                      onPressed: _saveGroup,
                      isLoading: _isSaving,
                      child: Text(widget.group == null ? 'Create Group' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
