import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';
import '../widgets/server_status_card.dart';
import '../widgets/connected_clients_card.dart';
import '../widgets/server_logs_card.dart';
import '../widgets/server_controls.dart';

class ServerDashboard extends StatelessWidget {
  const ServerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/app_icon.png',
              height: 32,
              width: 32,
            ),
            const SizedBox(width: 12),
            const Text('CampusNet Server'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<ServerProvider>(
            builder: (context, server, child) {
              return IconButton(
                icon: Icon(
                  server.isRunning ? Icons.stop : Icons.play_arrow,
                  color: server.isRunning ? Colors.red : Colors.green,
                ),
                onPressed: () {
                  if (server.isRunning) {
                    server.stopServer();
                  } else {
                    server.startServer();
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server Controls
            const ServerControls(),
            const SizedBox(height: 16),
            
            // Status Cards Row
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child: ServerStatusCard(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ConnectedClientsCard(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Server Logs
            Expanded(
              flex: 3,
              child: ServerLogsCard(),
            ),
          ],
        ),
      ),
    );
  }
}
