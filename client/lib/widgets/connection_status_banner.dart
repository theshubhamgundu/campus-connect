import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/websocket_service.dart';

class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final webSocketService = Provider.of<WebSocketService>(context, listen: true);
    
    if (webSocketService.isConnected) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.orange,
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Disconnected from server. Trying to reconnect...',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: webSocketService.isConnecting ? null : webSocketService.reconnect,
            child: Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
