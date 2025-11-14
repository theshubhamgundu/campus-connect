import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';

class ConnectedClientsCard extends StatelessWidget {
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
                      Icons.people,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Connected Clients',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Chip(
                      label: Text('${server.connectedClients.length}'),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: server.connectedClients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_off,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No clients connected',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: server.connectedClients.length,
                          itemBuilder: (context, index) {
                            final client = server.connectedClients[index];
                            return _buildClientItem(context, client, server);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClientItem(
    BuildContext context,
    ClientInfo client,
    ServerProvider server,
  ) {
    final duration = DateTime.now().difference(client.connectedAt);
    final durationText = _formatDuration(duration);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(
            Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(
          client.address,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Connected for $durationText'),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'disconnect',
              child: Row(
                children: [
                  Icon(Icons.close, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Disconnect'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'disconnect') {
              server.disconnectClient(client.id);
            }
          },
        ),
        isThreeLine: false,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
