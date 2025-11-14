import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';

class ServerControls extends StatelessWidget {
  const ServerControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerProvider>(
      builder: (context, server, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Server Controls',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.settings_ethernet),
                        ),
                        keyboardType: TextInputType.number,
                        enabled: !server.isRunning,
                        controller: TextEditingController(
                          text: server.port.toString(),
                        ),
                        onChanged: (value) {
                          final port = int.tryParse(value);
                          if (port != null && port > 0 && port < 65536) {
                            server.setPort(port);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: server.isRunning
                          ? server.stopServer
                          : server.startServer,
                      icon: Icon(
                        server.isRunning ? Icons.stop : Icons.play_arrow,
                      ),
                      label: Text(
                        server.isRunning ? 'Stop Server' : 'Start Server',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: server.isRunning
                            ? Colors.red
                            : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      server.isRunning ? Icons.circle : Icons.circle_outlined,
                      color: server.isRunning ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Status: ${server.status}',
                      style: TextStyle(
                        color: server.isRunning ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (server.isRunning)
                      Text(
                        'ws://0.0.0.0:${server.port}/ws',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
