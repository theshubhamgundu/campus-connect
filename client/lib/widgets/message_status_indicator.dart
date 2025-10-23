import 'package:flutter/material.dart';
import '../models/message.dart';

class MessageStatusIndicator extends StatelessWidget {
  final MessageStatus status;
  final double size;
  final Color? color;

  const MessageStatusIndicator({
    Key? key,
    required this.status,
    this.size = 16.0,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.colorScheme.onSurface.withOpacity(0.6);
    
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
          ),
        );
        
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: size,
          color: iconColor,
        );
        
      case MessageStatus.delivered:
        return Stack(
          children: [
            Positioned(
              left: 0,
              child: Icon(
                Icons.check,
                size: size,
                color: iconColor,
              ),
            ),
            Positioned(
              right: 0,
              child: Icon(
                Icons.check,
                size: size,
                color: iconColor,
              ),
            ),
          ],
        );
        
      case MessageStatus.read:
        return Stack(
          children: [
            Positioned(
              left: 0,
              child: Icon(
                Icons.check,
                size: size,
                color: theme.colorScheme.primary,
              ),
            ),
            Positioned(
              right: 0,
              child: Icon(
                Icons.check,
                size: size,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        );
        
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          size: size,
          color: theme.colorScheme.error,
        );
    }
  }
}
