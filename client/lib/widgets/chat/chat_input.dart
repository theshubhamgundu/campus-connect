import 'package:flutter/material.dart';

class ChatInput extends StatefulWidget {
  /// Callback when the user sends a message
  final Function(String) onSend;
  
  /// Whether a message is being sent
  final bool isSending;
  
  /// Whether to show the attachment button
  final bool showAttachmentButton;
  
  /// Whether to show the emoji button
  final bool showEmojiButton;
  
  /// Callback when attachment button is pressed
  final VoidCallback? onAttachmentPressed;
  
  /// Callback when user is typing
  final Function(bool)? onTyping;
  
  /// Whether the input is enabled
  final bool enabled;
  
  /// Hint text for the input field
  final String hintText;
  
  /// Custom focus node
  final FocusNode? focusNode;
  
  /// Custom text controller
  final TextEditingController? controller;

  const ChatInput({
    Key? key,
    required this.onSend,
    this.isSending = false,
    this.showAttachmentButton = true,
    this.showEmojiButton = true,
    this.onAttachmentPressed,
    this.onTyping,
    this.enabled = true,
    this.hintText = 'Type a message...',
    this.focusNode,
    this.controller,
  }) : super(key: key);

  @override
  _ChatInputState createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isComposing = false;
  bool _isUploading = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller.addListener(_handleTextChange);
  }

  void _handleTextChange() {
    final isTyping = _controller.text.isNotEmpty;
    if (isTyping != _isTyping) {
      _isTyping = isTyping;
      widget.onTyping?.call(_isTyping);
    }
    setState(() => _isComposing = _controller.text.isNotEmpty);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      _controller.clear();
      setState(() => _isComposing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          if (widget.showAttachmentButton)
            IconButton(
              icon: widget.isSending || _isUploading
                  ? const SizedBox(
                      width: 24.0,
                      height: 24.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    )
                  : const Icon(Icons.attach_file),
              onPressed: (widget.isSending || _isUploading || !widget.enabled)
                  ? null
                  : widget.onAttachmentPressed,
              tooltip: 'Attach file',
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          const SizedBox(width: 4.0),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  if (widget.showEmojiButton) ...[
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined),
                      onPressed: () {
                        // TODO: Implement emoji picker
                        _focusNode.unfocus();
                      },
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4.0),
                  ],
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: 5,
                      minLines: 1,
                      enabled: widget.enabled,
                      textInputAction: TextInputAction.send,
                      keyboardType: TextInputType.multiline,
                      onChanged: (text) {
                        setState(() {
                          _isComposing = text.trim().isNotEmpty;
                        });
                      },
                      onSubmitted: _isComposing ? (_) => _handleSubmit() : null,
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        hintStyle: !widget.enabled
                            ? theme.textTheme.bodyMedium?.copyWith(
                                color: theme.hintColor.withOpacity(0.5),
                              )
                            : null,
                      ),
                    ),
                  ),
                  if (widget.isSending)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.0),
                      ),
                    )
                  else if (_isComposing)
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _handleSubmit,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
            ),
          ),
        ],
      ),
    );
  }
}