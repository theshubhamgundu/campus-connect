import 'dart:io';
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'file_picker_button.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(File, String) onSendFile;
  final Function()? onTyping;
  final String? replyToMessage;
  final Function()? onCancelReply;
  final String hintText;
  final bool isUploading;

  const ChatInput({
    Key? key,
    required this.onSendMessage,
    required this.onSendFile,
    this.onTyping,
    this.replyToMessage,
    this.onCancelReply,
    this.hintText = 'Type a message...',
    this.isUploading = false,
  }) : super(key: key);

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isEmojiVisible = false;
  bool _isTyping = false;
  String _currentText = '';

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textController.text.trim();
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      widget.onTyping?.call();
    } else if (text.isEmpty && _isTyping) {
      _isTyping = false;
      widget.onTyping?.call();
    }
    _currentText = text;
  }

  void _handleSubmitted(String text) {
    final trimmedText = text.trim();
    if (trimmedText.isNotEmpty) {
      widget.onSendMessage(trimmedText);
      _textController.clear();
      _currentText = '';
      _isTyping = false;
      widget.onTyping?.call();
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _isEmojiVisible = !_isEmojiVisible;
    });
    if (!_isEmojiVisible) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _onEmojiSelected(Emoji emoji) {
    final text = _textController.text;
    final selection = _textController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji.emoji,
    );
    final cursorPosition = selection.start + emoji.emoji.length;
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }

  void _onFileSelected(File file, String mimeType) {
    widget.onSendFile(file, mimeType);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply preview
        if (widget.replyToMessage != null && widget.replyToMessage!.isNotEmpty)
          _buildReplyPreview(context),
          
        // Input area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4.0,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Emoji button
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    onPressed: _toggleEmojiPicker,
                    color: Theme.of(context).hintColor,
                  ),
                  
                  // File picker button
                  FilePickerButton(
                    onFileSelected: _onFileSelected,
                    isImageOnly: false,
                    tooltip: 'Attach file',
                  ),
                  
                  // Text field
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 100),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        onSubmitted: _handleSubmitted,
                        onTap: () {
                          if (_isEmojiVisible) {
                            setState(() => _isEmojiVisible = false);
                          }
                        },
                      ),
                    ),
                  ),
                  
                  // Send button
                  if (_currentText.trim().isNotEmpty || widget.isUploading)
                    IconButton(
                      icon: widget.isUploading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      onPressed: widget.isUploading
                          ? null
                          : () => _handleSubmitted(_currentText),
                      color: Theme.of(context).primaryColor,
                    )
                  else
                    const SizedBox(width: 12), // For consistent spacing
                ],
              ),
              
              // Emoji picker
              if (_isEmojiVisible)
                SizedBox(
                  height: 250,
                  child: EmojiPicker(
                    onEmojiSelected: (category, emoji) {
                      _onEmojiSelected(emoji);
                    },
                    config: Config(
                      columns: 7,
                      emojiSizeMax: 32.0,
                      verticalSpacing: 0,
                      horizontalSpacing: 0,
                      initCategory: Category.RECENT,
                      bgColor: Theme.of(context).cardColor,
                      indicatorColor: Theme.of(context).primaryColor,
                      iconColor: Colors.grey,
                      iconColorSelected: Theme.of(context).primaryColor,
                      progressIndicatorColor: Theme.of(context).primaryColor,
                      backspaceColor: Theme.of(context).primaryColor,
                      skinToneDialogBgColor: Colors.white,
                      skinToneIndicatorColor: Colors.grey,
                      enableSkinTones: true,
                      showRecentsTab: true,
                      recentsLimit: 28,
                      noRecentsText: 'No Recents',
                      noRecentsStyle: const TextStyle(
                        fontSize: 20,
                        color: Colors.black26,
                      ),
                      tabIndicatorAnimDuration: kTabScrollDuration,
                      categoryIcons: const CategoryIcons(),
                      buttonMode: ButtonMode.MATERIAL,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      color: Theme.of(context).dividerColor.withOpacity(0.1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Replying to message',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: widget.onCancelReply,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.replyToMessage!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
