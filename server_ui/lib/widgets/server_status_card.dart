import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';

class ServerStatusCard extends StatelessWidget {
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
                Row(
                  children: [
                    Icon(
                      Icons.dashboard,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Server Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStatusItem(
                  context,
                  'Status',
                  server.status,
                  server.isRunning ? Colors.green : Colors.red,
                  server.isRunning ? Icons.check_circle : Icons.error,
                ),
                const SizedBox(height: 12),
                _buildStatusItem(
                  context,
                  'Port',
                  server.port.toString(),
                  Colors.blue,
                  Icons.settings_ethernet,
                ),
                const SizedBox(height: 12),
                _buildStatusItem(
                  context,
                  'Total Connections',
                  server.totalConnections.toString(),
                  Colors.orange,
                  Icons.people,
                ),
                const SizedBox(height: 12),
                _buildStatusItem(
                  context,
                  'Total Messages',
                  server.totalMessages.toString(),
                  Colors.purple,
                  Icons.message,
                ),
                const SizedBox(height: 12),
                _buildStatusItem(
                  context,
                  'Active Clients',
                  server.connectedClients.length.toString(),
                  Colors.teal,
                  Icons.person,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusItem(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
