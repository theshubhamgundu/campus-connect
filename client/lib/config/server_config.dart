class ServerConfig {
  // Server configuration
  static const String serverIp = '192.168.137.167';
  static const int serverPort = 3000; // Default port, change if needed
  static const bool useHttps = false; // Set to true if using HTTPS

  // Get the base URL for API requests
  static String get baseUrl {
    return 'http${useHttps ? 's' : ''}://$serverIp:$serverPort';
  }

  // WebSocket URL for real-time communication
  static String get webSocketUrl {
    return 'ws${useHttps ? 's' : ''}://$serverIp:$serverPort/ws';
  }

  // Check if the current server is the local development server
  static bool get isLocalServer {
    return serverIp == '192.168.137.167' || 
           serverIp == 'localhost' || 
           serverIp == '127.0.0.1';
  }

  // Timeout duration for API requests
  static const Duration apiTimeout = Duration(seconds: 30);

  // Reconnection settings
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectInterval = Duration(seconds: 3);
}
