import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/chat.dart';


class ChatScreen extends StatefulWidget {
  final Chat chat;
  final Function(Message) onSendMessage;
  final Function(File) onSendImage;
  final Function(File) onSendFile;
  final Function(String, String) onUpdateProfile;
  final String currentUserId;

  const ChatScreen({
    Key? key,
    required this.chat,
    required this.onSendMessage,
    required this.onSendImage,
    required this.onSendFile,
    required this.onUpdateProfile,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _showEmojiPicker = false;
  
  List<Message> get _messages => widget.chat.messages ?? [];
  
  // Settings menu options
  final List<Map<String, dynamic>> _settingsOptions = [
    {
      'title': 'View contact',
      'icon': Icons.person_outline,
      'action': 'view_contact',
    },
    {
      'title': 'Media, links, and docs',
      'icon': Icons.photo_library_outlined,
      'action': 'media',
    },
    {
      'title': 'Search',
      'icon': Icons.search,
      'action': 'search',
    },
    {
      'title': 'Mute notifications',
      'icon': Icons.notifications_off_outlined,
      'action': 'mute',
    },
    {
      'title': 'Change profile photo',
      'icon': Icons.camera_alt_outlined,
      'action': 'change_photo',
    },
    {
      'title': 'Change name',
      'icon': Icons.edit_outlined,
      'action': 'change_name',
    },
    {
      'title': 'Clear chat',
      'icon': Icons.delete_outline,
      'action': 'clear_chat',
      'isDestructive': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }
  
  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.messages?.length != widget.chat.messages?.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: widget.currentUserId,
      text: text,
      timestamp: DateTime.now(),
      isRead: false,
    );

    widget.onSendMessage(message);
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        widget.onSendImage(file);
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        widget.onSendFile(file);
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            ..._settingsOptions.map((option) => ListTile(
                  leading: Icon(option['icon'] as IconData),
                  title: Text(
                    option['title'],
                    style: TextStyle(
                      color: option['isDestructive'] == true 
                          ? Colors.red 
                          : null,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _handleSettingsAction(option['action']);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _handleSettingsAction(String action) async {
    switch (action) {
      case 'change_photo':
        final source = await showDialog<ImageSource>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Choose source'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, ImageSource.camera),
                child: const Text('Camera'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, ImageSource.gallery),
                child: const Text('Gallery'),
              ),
            ],
          ),
        );
        if (source != null) {
          await _pickImage(source);
        }
        break;
        
      case 'change_name':
        final newName = await showDialog<String>(
          context: context,
          builder: (context) {
            final controller = TextEditingController(text: widget.chat.name);
            return AlertDialog(
              title: const Text('Change name'),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Enter new name',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, controller.text.trim()),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
        
        if (newName != null && newName.isNotEmpty) {
          widget.onUpdateProfile('name', newName);
        }
        break;
        
      case 'clear_chat':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear chat?'),
            content: const Text('All messages will be deleted. This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Clear'),
              ),
            ],
          ),
        );
        
        if (confirm == true) {
          // TODO: Implement clear chat
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat cleared')),
          );
        }
        break;
        
      // Handle other actions
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$action clicked')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () {
            // Show contact info
            _handleSettingsAction('view_contact');
          },
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: widget.chat.avatar.isNotEmpty
                        ? FileImage(File(widget.chat.avatar))
                        : null,
                    child: widget.chat.avatar.isEmpty
                        ? Text(
                            widget.chat.name.isNotEmpty ? widget.chat.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  if (widget.chat.isOnline)
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chat.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.chat.isOnline ? 'Online' : 'Last seen recently',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () {
              // TODO: Implement video call
              _handleSettingsAction('video_call');
            },
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () {
              // TODO: Implement voice call
              _handleSettingsAction('voice_call');
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleSettingsAction,
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'view_contact',
                  child: Text('View contact'),
                ),
                const PopupMenuItem(
                  value: 'media',
                  child: Text('Media, links, and docs'),
                ),
                const PopupMenuItem(
                  value: 'search',
                  child: Text('Search'),
                ),
                const PopupMenuItem(
                  value: 'mute',
                  child: Text('Mute notifications'),
                ),
                const PopupMenuItem(
                  value: 'wallpaper',
                  child: Text('Wallpaper'),
                ),
                const PopupMenuItem(
                  value: 'more',
                  child: Text('More'),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Send a message to start the conversation',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message.senderId == widget.currentUserId;
                          
                          // Group messages by time difference
                          final bool showTime = index == 0 || 
                              _messages[index - 1].timestamp.difference(message.timestamp).inMinutes > 5;
                              
                          // Show date header if it's a new day
                          final bool showDate = index == 0 || 
                              !DateUtils.isSameDay(
                                _messages[index - 1].timestamp, 
                                message.timestamp
                              );
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Date header
                              if (showDate)
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatDateHeader(message.timestamp),
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                    ),
                                  ),
                                ),
                              
                              // Message bubble
                              Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (!isMe && showTime) ...[
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundImage: widget.chat.avatar.isNotEmpty
                                              ? FileImage(File(widget.chat.avatar))
                                              : null,
                                          child: widget.chat.avatar.isEmpty
                                              ? Text(
                                                  widget.chat.name.isNotEmpty 
                                                      ? widget.chat.name[0].toUpperCase() 
                                                      : '?',
                                                  style: const TextStyle(fontSize: 12, color: Colors.white),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: isMe 
                                                ? const Color(0xFFDCF8C6) 
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(0.2),
                                                spreadRadius: 1,
                                                blurRadius: 2,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (message.type == 'image')
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Image.file(
                                                    File(message.text),
                                                    width: double.infinity,
                                                    height: 200,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => 
                                                        const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                                                  ),
                                                )
                                              else if (message.type == 'file')
                                                _buildFileMessage(message)
                                              else
                                                Text(
                                                  message.text,
                                                  style: const TextStyle(fontSize: 16),
                                                ),
                                              
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    DateFormat('h:mm a').format(message.timestamp),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  if (isMe) ...[
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      message.isRead 
                                                          ? Icons.done_all_rounded 
                                                          : Icons.done_rounded,
                                                      size: 14,
                                                      color: message.isRead 
                                                          ? Colors.blue 
                                                          : Colors.grey[600],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildFileMessage(Message message) {
    final fileName = message.text.split('/').last;
    final fileSize = message.fileSize ?? 0;
    final fileExtension = fileName.split('.').last.toLowerCase();
    
    IconData fileIcon;
    switch (fileExtension) {
      case 'pdf':
        fileIcon = Icons.picture_as_pdf;
        break;
      case 'doc':
      case 'docx':
        fileIcon = Icons.description;
        break;
      case 'xls':
      case 'xlsx':
        fileIcon = Icons.table_chart;
        break;
      case 'zip':
      case 'rar':
        fileIcon = Icons.folder_zip;
        break;
      default:
        fileIcon = Icons.insert_drive_file;
    }

    return GestureDetector(
      onTap: () {
        // TODO: Open file
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening file: $fileName')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(fileIcon, size: 40, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatFileSize(fileSize),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) return 'Today';
    if (messageDate == yesterday) return 'Yesterday';
    
    return DateFormat('MMM d, yyyy').format(date);
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Reply or forward message preview
          // TODO: Implement reply/forward functionality
          
          // Main input row
          Row(
            children: [
              // Emoji button
              IconButton(
                icon: Icon(
                  _showEmojiPicker 
                      ? Icons.keyboard 
                      : Icons.emoji_emotions_outlined, 
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _showEmojiPicker = !_showEmojiPicker;
                  });
                },
              ),
              
              // Attachment menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.attach_file_outlined, color: Colors.grey),
                onSelected: (value) async {
                  switch (value) {
                    case 'camera':
                      await _pickImage(ImageSource.camera);
                      break;
                    case 'gallery':
                      await _pickImage(ImageSource.gallery);
                      break;
                    case 'document':
                      await _pickFile();
                      break;
                    case 'location':
                      // TODO: Implement location sharing
                      break;
                    case 'contact':
                      // TODO: Implement contact sharing
                      break;
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    const PopupMenuItem(
                      value: 'camera',
                      child: Row(
                        children: [
                          Icon(Icons.camera_alt, color: Colors.grey),
                          SizedBox(width: 12),
                          Text('Camera'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'gallery',
                      child: Row(
                        children: [
                          Icon(Icons.photo_library, color: Colors.grey),
                          SizedBox(width: 12),
                          Text('Gallery'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'document',
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file, color: Colors.grey),
                          SizedBox(width: 12),
                          Text('Document'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'location',
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.grey),
                          SizedBox(width: 12),
                          Text('Location'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'contact',
                      child: Row(
                        children: [
                          Icon(Icons.person_add, color: Colors.grey),
                          SizedBox(width: 12),
                          Text('Contact'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
              
              // Message input field
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    suffixIcon: _messageController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                            onPressed: () {
                              _messageController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _sendMessage(),
                  maxLines: 5,
                  minLines: 1,
                ),
              ),
              
              // Voice message or send button
              if (_messageController.text.trim().isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF128C7E)),
                  onPressed: _sendMessage,
                )
              else
                IconButton(
                  icon: const Icon(Icons.mic_none, color: Color(0xFF128C7E)),
                  onPressed: () {
                    // TODO: Implement voice message recording
                    _showVoiceMessageDialog();
                  },
                ),
            ],
          ),
          
          // Emoji picker
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              // TODO: Implement emoji picker
              child: Center(
                child: Text(
                  'Emoji Picker',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  void _showVoiceMessageDialog() {
    // TODO: Implement voice message recording UI
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Recording voice message...'),
            const SizedBox(height: 8),
            const Text('00:00', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 36),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 32),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green, size: 36),
                  onPressed: () {
                    // TODO: Send voice message
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Voice message sent')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
