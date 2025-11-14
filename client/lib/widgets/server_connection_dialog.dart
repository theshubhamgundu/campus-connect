import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/websocket_service.dart';
import '../services/connection_service.dart';
import '../config/server_config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class ServerConnectionDialog extends StatefulWidget {
  final bool isReconnecting;
  
  const ServerConnectionDialog({
    Key? key,
    this.isReconnecting = false,
  }) : super(key: key);

  @override
  _ServerConnectionDialogState createState() => _ServerConnectionDialogState();
}

class _ServerConnectionDialogState extends State<ServerConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  bool _isLoading = false;
  bool _isDiscovering = false;
  List<Map<String, dynamic>> _discoveredServers = [];
  bool _useHttps = false;
  final WebSocketService _webSocketService = WebSocketService();
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
    _startDiscovery();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    final config = await ServerConfig.getServerConfig();
    setState(() {
      _ipController.text = config['ip'] ?? '';
      _portController.text = (config['port'] ?? '').toString();
      _useHttps = config['useHttps'] ?? false;
    });
  }

  Future<void> _startDiscovery() async {
    if (_isDiscovering) return;
    
    setState(() {
      _isDiscovering = true;
      _discoveredServers.clear();
    });

    // Simulate server discovery (replace with actual discovery logic)
    // In a real app, you would use mDNS or similar to discover servers
    await Future.delayed(const Duration(seconds: 2));
    
    // Add some dummy discovered servers for demonstration
    setState(() {
      _discoveredServers = [
        {'ip': '192.168.1.100', 'port': 3000, 'name': 'CampusNet Server'},
        {'ip': '192.168.1.101', 'port': 3000, 'name': 'CampusNet Backup'},
      ];
      _isDiscovering = false;
    });
  }

  Future<void> _connectToServer() async {
    if (!_formKey.currentState!.validate()) return;
    
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 3000;

    setState(() {
      _isLoading = true;
    });

    try {
      // Save the server configuration
      await ServerConfig.saveServerConfig(ip, port, useHttps: _useHttps);
      
      // Connect to the server via ConnectionService (set manual IP)
      await ConnectionService.instance.connectTo(ip);
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onServerSelected(Map<String, dynamic> server) {
    setState(() {
      _ipController.text = server['ip'];
      _portController.text = server['port'].toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isReconnecting ? 'Reconnect to Server' : 'Connect to Server'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Server IP Input
              TextFormField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'Server IP',
                  hintText: 'e.g., 192.168.1.100',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter server IP';
                  }
                  // Basic IP validation
                  final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
                  if (!ipRegex.hasMatch(value)) {
                    return 'Please enter a valid IP address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Port Input
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: 'e.g., 3000',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter port number';
                  }
                  final port = int.tryParse(value);
                  if (port == null || port <= 0 || port > 65535) {
                    return 'Please enter a valid port number (1-65535)';
                  }
                  return null;
                },
              ),
              
              // HTTPS Toggle
              SwitchListTile(
                title: const Text('Use HTTPS'),
                value: _useHttps,
                onChanged: (value) {
                  setState(() {
                    _useHttps = value;
                  });
                },
              ),
              
              const Divider(),
              
              // Discovered Servers
              Row(
                children: [
                  const Text('Discovered Servers', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (_isDiscovering)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _isDiscovering ? null : _startDiscovery,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              
              if (_discoveredServers.isEmpty && !_isDiscovering)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('No servers found on the local network.'),
                )
              else if (_discoveredServers.isNotEmpty)
                ..._discoveredServers.map((server) => ListTile(
                  leading: const Icon(Icons.dns),
                  title: Text(server['name'] ?? '${server['ip']}:${server['port']}'),
                  subtitle: Text('${server['ip']}:${server['port']}'),
                  onTap: () => _onServerSelected(server),
                )).toList(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _connectToServer,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('CONNECT'),
        ),
      ],
    );
  }
}

Future<bool> showServerConnectionDialog(BuildContext context, {bool isReconnecting = false}) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: !isReconnecting,
    builder: (context) => ServerConnectionDialog(isReconnecting: isReconnecting),
  ) ?? false;
}
