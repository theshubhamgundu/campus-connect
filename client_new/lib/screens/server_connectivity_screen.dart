import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../services/websocket_service.dart';
import '../config/server_config.dart';

enum ConnectivityState {
  searching,
  wifiDetected,
  connecting,
  connected,
  error,
}

class ServerConnectivityScreen extends StatefulWidget {
  const ServerConnectivityScreen({Key? key}) : super(key: key);

  @override
  _ServerConnectivityScreenState createState() => _ServerConnectivityScreenState();
}

class _ServerConnectivityScreenState extends State<ServerConnectivityScreen>
    with TickerProviderStateMixin {
  ConnectivityState _currentState = ConnectivityState.searching;
  bool _isScanning = false;
  String? _currentSSID;
  String? _errorMessage;
  
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _glowController;
  late AnimationController _particleController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _particleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startScanning();
  }

  void _initializeAnimations() {
    // Pulse animation for radar
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Wave animation for WiFi waves
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    // Glow animation for neon effects
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Particle animation for success
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.elasticOut),
    );

    // Start animations
    _pulseController.repeat(reverse: true);
    _waveController.repeat();
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _currentState = ConnectivityState.searching;
    });

    try {
      // Check current WiFi connection
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.wifi)) {
        final networkInfo = NetworkInfo();
        final wifiIP = await networkInfo.getWifiIP();
        final wifiName = await networkInfo.getWifiName();
        
        setState(() {
          _currentSSID = wifiName?.replaceAll('"', '');
        });

        // Check if connected to CampusNet
        if (_currentSSID?.contains('CampusNet') == true || 
            (wifiIP != null && wifiIP.startsWith('192.168.137.'))) {
          _detectCampusNetServer();
        } else {
          _scanForNetworks();
        }
      } else {
        _scanForNetworks();
      }
    } catch (e) {
      setState(() {
        _currentState = ConnectivityState.error;
        _errorMessage = 'Failed to scan networks: $e';
      });
    }
  }

  Future<void> _scanForNetworks() async {
    try {
      // Simulate scanning delay
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _isScanning = false;
        _currentState = ConnectivityState.wifiDetected;
      });
    } catch (e) {
      setState(() {
        _currentState = ConnectivityState.error;
        _errorMessage = 'Failed to scan WiFi networks: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _detectCampusNetServer() async {
    setState(() {
      _currentState = ConnectivityState.connecting;
    });

    try {
      final webSocketService = Provider.of<WebSocketService>(context, listen: false);
      await webSocketService.initialize();
      
      // Wait a moment to show connecting state
      await Future.delayed(const Duration(seconds: 2));
      
      if (webSocketService.isConnected) {
        setState(() {
          _currentState = ConnectivityState.connected;
        });
        _particleController.forward();
        
        // Show success and close after delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _currentState = ConnectivityState.error;
          _errorMessage = 'Failed to connect to CampusNet server';
        });
      }
    } catch (e) {
      setState(() {
        _currentState = ConnectivityState.error;
        _errorMessage = 'Connection error: $e';
      });
    }
  }

  Future<void> _connectToCampusNet() async {
    HapticFeedback.lightImpact();
    await _detectCampusNetServer();
  }

  Widget _buildRadarAnimation() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse rings
              ...List.generate(3, (index) {
                final delay = index * 0.3;
                final animationValue = (_pulseAnimation.value - delay).clamp(0.0, 1.0);
                final scale = 0.5 + (animationValue * 0.5);
                final opacity = (1.0 - animationValue) * 0.6;
                
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF005DFA).withOpacity(opacity),
                        width: 2,
                      ),
                    ),
                  ),
                );
              }),
              
              // Center WiFi icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00FFD1).withOpacity(0.8),
                      const Color(0xFF005DFA).withOpacity(0.4),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FFD1).withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wifi,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaveAnimation() {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(300, 300),
          painter: WavePainter(
            animationValue: _waveAnimation.value,
            color: const Color(0xFF00FFD1),
          ),
        );
      },
    );
  }

  Widget _buildGlassmorphismCard({required Widget child, double? width, double? height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF005DFA).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }

  Widget _buildStateContent() {
    switch (_currentState) {
      case ConnectivityState.searching:
        return _buildSearchingState();
      case ConnectivityState.wifiDetected:
        return _buildWifiDetectedState();
      case ConnectivityState.connecting:
        return _buildConnectingState();
      case ConnectivityState.connected:
        return _buildConnectedState();
      case ConnectivityState.error:
        return _buildErrorState();
    }
  }

  Widget _buildSearchingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildRadarAnimation(),
        const SizedBox(height: 40),
        Shimmer.fromColors(
          baseColor: const Color(0xFF00FFD1),
          highlightColor: Colors.white,
          child: Text(
            '🔍 Searching for CampusNet Server…',
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF00FFD1),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Scanning WiFi networks...',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildWifiDetectedState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00FFD1).withOpacity(_glowAnimation.value * 0.3),
                    const Color(0xFF005DFA).withOpacity(_glowAnimation.value * 0.1),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FFD1).withOpacity(_glowAnimation.value * 0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.wifi_find,
                size: 60,
                color: Color(0xFF00FFD1),
              ),
            );
          },
        ),
        const SizedBox(height: 30),
        Text(
          '📡 Server Wi-Fi Detected!',
          style: GoogleFonts.orbitron(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00FFD1),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildGlassmorphismCard(
          width: 300,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'SSID: "CampusNet-Server"',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Server WebSocket URL:\nws://192.168.137.167:8080',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _connectToCampusNet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFD1),
                    foregroundColor: const Color(0xFF030B1A),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 10,
                    shadowColor: const Color(0xFF00FFD1).withOpacity(0.5),
                  ),
                  child: Text(
                    '✅ Connect to CampusNet Server',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildWaveAnimation(),
        const SizedBox(height: 40),
        Text(
          '🔗 Connecting to Server…',
          style: GoogleFonts.orbitron(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF005DFA),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          width: 200,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.white.withOpacity(0.2),
          ),
          child: LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
              const Color(0xFF00FFD1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _particleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_particleAnimation.value * 0.2),
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00FFD1).withOpacity(0.8),
                      const Color(0xFF005DFA).withOpacity(0.4),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FFD1).withOpacity(0.6),
                      blurRadius: 40,
                      spreadRadius: 15,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 30),
        Text(
          '✅ Connected — You\'re Back Online!',
          style: GoogleFonts.orbitron(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00FFD1),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FFD1),
            foregroundColor: const Color(0xFF030B1A),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 15,
            shadowColor: const Color(0xFF00FFD1).withOpacity(0.7),
          ),
          child: Text(
            'Continue 🚀',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(0.2),
            border: Border.all(
              color: Colors.red.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 30),
        Text(
          'Connection Error',
          style: GoogleFonts.orbitron(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),
        Text(
          _errorMessage ?? 'Unknown error occurred',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _startScanning,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF005DFA),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: Text(
            'Retry',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030B1A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              Color(0xFF030B1A),
              Color(0xFF0A1A2E),
              Color(0xFF030B1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Text(
                  'You are Offline',
                  style: GoogleFonts.orbitron(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Connect to CampusNet Wi-Fi to continue',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // Main content
                Expanded(
                  child: Center(
                    child: _buildStateContent(),
                  ),
                ),
                
                // Footer
                Text(
                  'CampusNet Intranet System',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw multiple wave rings
    for (int i = 0; i < 3; i++) {
      final waveProgress = (animationValue + i * 0.3) % 1.0;
      final radius = waveProgress * maxRadius;
      final opacity = (1.0 - waveProgress) * 0.8;
      
      paint.color = color.withOpacity(opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
