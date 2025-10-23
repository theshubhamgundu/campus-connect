import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';
import '../services/websocket_service.dart';
import '../config/server_config.dart';

class CampusNetConnectionStatus extends StatefulWidget {
  final Widget child;
  final bool showStatusBar;

  const CampusNetConnectionStatus({
    Key? key,
    required this.child,
    this.showStatusBar = true,
  }) : super(key: key);

  @override
  _CampusNetConnectionStatusState createState() => _CampusNetConnectionStatusState();
}

class _CampusNetConnectionStatusState extends State<CampusNetConnectionStatus> with SingleTickerProviderStateMixin {
  bool _isConnected = false;
  String _statusMessage = 'Connecting to CampusNet...';
  bool _showFullBanner = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.wifi) {
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      
      if (wifiIP != null && wifiIP.startsWith('192.168.137.')) {
        setState(() {
          _isConnected = true;
          _statusMessage = 'Connected to CampusNet';
          _showFullBanner = false;
        });
      } else {
        setState(() {
          _isConnected = false;
          _statusMessage = '⚠️ Please connect to CampusNet WiFi (${ServerConfig.serverIp})';
          _showFullBanner = true;
        });
      }
    } else {
      setState(() {
        _isConnected = false;
        _statusMessage = '⚠️ Please connect to CampusNet WiFi (${ServerConfig.serverIp})';
        _showFullBanner = true;
      });
    }

    if (_showFullBanner) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showStatusBar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showFullBanner = !_showFullBanner;
                  if (_showFullBanner) {
                    _animationController.forward();
                  } else {
                    _animationController.reverse();
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: _isConnected ? Colors.green : Colors.orange,
                child: Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.wifi : Icons.wifi_off,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showFullBanner ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _showFullBanner = !_showFullBanner;
                          if (_showFullBanner) {
                            _animationController.forward();
                          } else {
                            _animationController.reverse();
                          }
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_showFullBanner && !_isConnected && widget.showStatusBar)
          Positioned(
            top: 48, // Height of the status bar
            left: 0,
            right: 0,
            child: Material(
              elevation: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connection Required',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'To use CampusNet, please connect to the CampusNet WiFi network:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    _buildNetworkStep(
                      '1. Open your device\'s WiFi settings',
                      Icons.settings,
                    ),
                    _buildNetworkStep(
                      '2. Connect to the network: CampusNet',
                      Icons.wifi,
                    ),
                    _buildNetworkStep(
                      '3. Ensure your IP is in the 192.168.137.x range',
                      Icons.info_outline,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Open WiFi settings
                        // Note: This requires the app_launcher package
                        // You can implement this based on your needs
                      },
                      icon: const Icon(Icons.wifi, size: 20),
                      label: const Text('Open WiFi Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNetworkStep(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
