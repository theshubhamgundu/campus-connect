import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectionStatus extends StatefulWidget {
  final String serverIp;
  final Widget child;
  
  const ConnectionStatus({
    Key? key,
    required this.serverIp,
    required this.child,
  }) : super(key: key);

  @override
  _ConnectionStatusState createState() => _ConnectionStatusState();
}

class _ConnectionStatusState extends State<ConnectionStatus> with SingleTickerProviderStateMixin {
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isConnected = true;
  bool _isServerReachable = true;
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _initConnectivity();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      _updateConnectionStatus(result);
    });
  }

  Future<void> _initConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      await _updateConnectionStatus(connectivityResult);
    } on PlatformException catch (e) {
      debugPrint('Couldn\'t check connectivity status: $e');
    }
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    final isConnected = result != ConnectivityResult.none;
    bool isServerReachable = false;

    if (isConnected) {
      // Try to ping the server or check a known endpoint
      isServerReachable = await _checkServerReachability();
    }

    if (mounted) {
      setState(() {
        _isConnected = isConnected;
        _isServerReachable = isServerReachable;
      });
    }
  }

  Future<bool> _checkServerReachability() async {
    if (!mounted) return false;
    
    // If we're in development mode, assume local server is reachable
    if (ServerConfig.isDevelopment) return true;

    try {
      final client = http.Client();
      final response = await client
          .get(Uri.parse('${ServerConfig.baseUrl}/health'))
          .timeout(const Duration(seconds: 3));
          
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Server reachability check failed: $e');
      }
      return false;
    }
  }

  Future<void> _reconnect() async {
    await _initConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        StreamBuilder<bool>(
          stream: _connectionStatusService.connectionState,
          builder: (context, snapshot) {
            final isConnected = snapshot.data ?? false;
            _isConnected = isConnected;
            
            if (isConnected) {
              // Show brief connection restored message
              if (_wasDisconnected) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Connection restored'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  _wasDisconnected = false;
                });
              }
              return const SizedBox.shrink();
            }
            
            _wasDisconnected = true;
            return GestureDetector(
              onTap: () async {
                // Try to reconnect when tapped
                if (await _checkServerReachability()) {
                  await _connectionStatusService.reconnect();
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unable to connect to the server'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.red,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.signal_wifi_off, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'No connection',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    if (ServerConfig.isDevelopment) ...[
                      const SizedBox(width: 8),
                      const Text(
                        '(Development Mode)',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        if (!_isConnected || !_isServerReachable) ..._buildDisconnectedOverlay(),
      ],
    );
  }

  List<Widget> _buildDisconnectedOverlay() {
    return [
      // Semi-transparent overlay
      Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
      ),
      // Disconnected message
      Positioned.fill(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0F2027),
                        Color(0xFF203A43),
                        Color(0xFF2C5364),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated icon
                      AnimatedBuilder(
                        animation: _glowAnimation,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.withOpacity(0.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.6),
                                  blurRadius: 20 * _glowAnimation.value,
                                  spreadRadius: 5 * _glowAnimation.value,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.signal_wifi_off_rounded,
                              size: 48,
                              color: Colors.redAccent,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      // Title with glow effect
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.redAccent, Colors.red],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'Disconnected from CampusNet!',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.redAccent,
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Server info
                      Text(
                        'Please reconnect to your nearest CampusNet server',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[300],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Server: ${widget.serverIp}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[200],
                          fontFamily: 'RobotoMono',
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Reconnect button with animation
                      AnimatedBuilder(
                        animation: _glowAnimation,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: const LinearGradient(
                                colors: [Colors.blueAccent, Colors.blue],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.6),
                                  blurRadius: 15 * _glowAnimation.value,
                                  spreadRadius: 2 * _glowAnimation.value,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _reconnect,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.refresh, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'RECONNECT',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Manual IP input option
                      TextButton(
                        onPressed: () {
                          // TODO: Show manual IP input dialog
                        },
                        child: Text(
                          'Change Server IP',
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}
