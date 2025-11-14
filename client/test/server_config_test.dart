import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:splitwise/config/server_config.dart';

// Mock SharedPreferences
class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late MockSharedPreferences mockPrefs;
  
  setUp(() {
    mockPrefs = MockSharedPreferences();
    // Reset the singleton instance
    SharedPreferences.setMockInitialValues({});
  });

  test('ServerConfig should use default values when not initialized', () async {
    // Arrange
    when(mockPrefs.getString(any)).thenReturn(null);
    when(mockPrefs.getInt(any)).thenReturn(null);
    when(mockPrefs.getBool(any)).thenReturn(null);
    
    // Act
    await ServerConfig.initialize();
    final config = await ServerConfig.getServerConfig();
    
    // Assert
    expect(config['ip'], '192.168.137.91');
    expect(config['port'], 8083);
    expect(config['useHttps'], false);
  });

  test('ServerConfig should load saved values from SharedPreferences', () async {
    // Arrange
    when(mockPrefs.getString('server_ip')).thenReturn('192.168.1.100');
    when(mockPrefs.getInt('server_port')).thenReturn(9000);
    when(mockPrefs.getBool('use_https')).thenReturn(true);
    
    // Act
    await ServerConfig.initialize();
    final config = await ServerConfig.getServerConfig();
    
    // Assert
    expect(config['ip'], '192.168.1.100');
    expect(config['port'], 9000);
    expect(config['useHttps'], true);
  });

  test('isLocalServer should correctly identify local IPs', () {
    // Test various IP formats
    expect(ServerConfig.isLocalServer, true); // Default is local
    
    // Test with different IP formats
    expect(ServerConfig.isLocalServer, true);
    
    // Test with non-local IP
    // Note: This is a simplified test - in real usage, you'd mock the serverIp
    ServerConfig.saveServerConfig('8.8.8.8', 80);
    expect(ServerConfig.isLocalServer, false);
  });

  test('webSocketUrl should use correct protocol', () {
    // Test HTTP
    ServerConfig.saveServerConfig('192.168.1.1', 8080, useHttps: false);
    expect(ServerConfig.webSocketUrl, 'ws://192.168.1.1:8080/ws');
    
    // Test HTTPS
    ServerConfig.saveServerConfig('192.168.1.1', 8443, useHttps: true);
    expect(ServerConfig.webSocketUrl, 'wss://192.168.1.1:8443/ws');
  });

  test('resetToDefaults should restore default values', () async {
    // Arrange
    await ServerConfig.saveServerConfig('192.168.1.100', 9000, useHttps: true);
    
    // Act
    await ServerConfig.resetToDefaults();
    final config = await ServerConfig.getServerConfig();
    
    // Assert
    expect(config['ip'], '192.168.137.91');
    expect(config['port'], 8083);
    expect(config['useHttps'], false);
  });
}
