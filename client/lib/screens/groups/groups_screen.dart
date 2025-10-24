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
    final webSocketService = Provider.of<WebSocketService>(context, listen: false);
    
    if (!webSocketService.isConnected) {
      setState(() => _isLoading = false);
      _showError('No connection to server. Please check your internet connection.');
      return;
    }

    try {
      setState(() => _isLoading = true);
      
      // Load initial groups
      await groupService.loadGroups();
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load groups: ${e.toString()}');
      }
    }

    // Listen for group updates
    _groupsSubscription = groupService.watchGroups().listen((groups) {
      if (mounted) {
        setState(() {
          _groups = groups;
          _filterGroups(_searchController.text);
        });
      }
    }, onError: (error) {
      if (mounted) {
        _showError('Error updating groups: ${error.toString()}');
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

  Future<void> _navigateToGroupChat(Group group) async {
    final webSocketService = Provider.of<WebSocketService>(context, listen: false);
    
    if (!webSocketService.isConnected) {
      _showError('Cannot open group. No connection to server.');
      return;
    }

    // Show loading indicator
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final overlaySize = overlay?.size ?? Size.zero;
    final overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Semi-transparent background
          Container(
            width: overlaySize.width,
            height: overlaySize.height,
            color: Colors.black54,
          ),
          // Loading indicator
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      ),
    );

    try {
      // Show loading overlay
      Overlay.of(context).insert(overlayEntry);
      
      // Add a small delay to ensure the overlay is shown
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Navigate to group chat
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupChatScreen(group: group),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to open group: ${e.toString()}');
      }
    } finally {
      // Remove loading overlay
      overlayEntry.remove();
    }
  }

  void _showCreateGroupDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const CreateEditGroupScreen(),
    );
  }

  @override
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No groups yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the + button to create a new group',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadGroups,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final webSocketService = Provider.of<WebSocketService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Groups'),
            if (!webSocketService.isConnected) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
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
