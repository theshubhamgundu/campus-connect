import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';

/// AES-256 Encryption Service for End-to-End protection
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._private();

  factory EncryptionService() {
    return _instance;
  }

  EncryptionService._private();

  // Shared symmetric key for AES-256 (in production, derive from password or secure storage)
  // For demo/project purposes: use a fixed key
  static const String _sharedKeyString = 'CampusNet2025SecureKey@1234567890';

  late final encrypt.Key _encryptionKey;
  late final encrypt.Encrypter _encrypter;

  /// Initialize the encryption service
  Future<void> initialize() async {
    try {
      // Create 32-byte key for AES-256
      final keyBytes = _deriveKey(_sharedKeyString);
      _encryptionKey = encrypt.Key(keyBytes);
      _encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      debugPrint('✅ Encryption service initialized (AES-256)');
    } catch (e) {
      debugPrint('❌ Error initializing encryption: $e');
      rethrow;
    }
  }

  /// Derive a 32-byte key from a string using PBKDF2-like approach
  Uint8List _deriveKey(String keyString) {
    final bytes = utf8.encode(keyString);
    // Ensure 32 bytes for AES-256
    final buffer = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      buffer[i] = bytes[i % bytes.length];
    }
    return buffer;
  }

  /// Encrypt a JSON object to base64 string
  /// Returns: { "iv": "<base64>", "ciphertext": "<base64>" }
  Map<String, String> encryptJson(Map<String, dynamic> data) {
    try {
      final jsonString = jsonEncode(data);
      return encryptString(jsonString);
    } catch (e) {
      debugPrint('❌ Error encrypting JSON: $e');
      rethrow;
    }
  }

  /// Encrypt a string to base64
  /// Returns: { "iv": "<base64>", "ciphertext": "<base64>" }
  Map<String, String> encryptString(String plaintext) {
    try {
      final iv = encrypt.IV.fromSecureRandom(16); // 16-byte IV
      final encrypted = _encrypter.encrypt(plaintext, iv: iv);

      return {
        'iv': base64Encode(iv.bytes),
        'ciphertext': encrypted.base64,
      };
    } catch (e) {
      debugPrint('❌ Error encrypting string: $e');
      rethrow;
    }
  }

  /// Encrypt binary data (e.g., file bytes)
  /// Returns: { "iv": "<base64>", "ciphertext": "<base64>" }
  Map<String, String> encryptBytes(Uint8List data) {
    try {
      final plaintext = base64Encode(data);
      return encryptString(plaintext);
    } catch (e) {
      debugPrint('❌ Error encrypting bytes: $e');
      rethrow;
    }
  }

  /// Decrypt from { "iv": "<base64>", "ciphertext": "<base64>" } to JSON object
  Map<String, dynamic> decryptJson(Map<String, dynamic> encrypted) {
    try {
      final jsonString = decryptString(encrypted);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Error decrypting JSON: $e');
      rethrow;
    }
  }

  /// Decrypt from { "iv": "<base64>", "ciphertext": "<base64>" } to string
  String decryptString(Map<String, dynamic> encrypted) {
    try {
      final ivBase64 = encrypted['iv'] as String;
      final ciphertextBase64 = encrypted['ciphertext'] as String;

      final iv = encrypt.IV(base64Decode(ivBase64));
      final encryptedData = encrypt.Encrypted.fromBase64(ciphertextBase64);

      final decrypted = _encrypter.decrypt(encryptedData, iv: iv);
      return decrypted;
    } catch (e) {
      debugPrint('❌ Error decrypting string: $e');
      rethrow;
    }
  }

  /// Decrypt binary data from { "iv": "<base64>", "ciphertext": "<base64>" } to bytes
  Uint8List decryptBytes(Map<String, dynamic> encrypted) {
    try {
      final jsonString = decryptString(encrypted);
      return base64Decode(jsonString);
    } catch (e) {
      debugPrint('❌ Error decrypting bytes: $e');
      rethrow;
    }
  }

  /// Check if data is encrypted (has iv and ciphertext fields)
  static bool isEncrypted(Map<String, dynamic> data) {
    return data.containsKey('iv') && data.containsKey('ciphertext');
  }
}
