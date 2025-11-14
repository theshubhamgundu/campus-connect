import 'package:flutter/foundation.dart';
import 'connection_service.dart';
import 'encryption_service.dart';
import 'package:uuid/uuid.dart';

/// Represents an incoming call
class IncomingCall {
  final String callerId;
  final String callerName;
  final String callId;
  final DateTime timestamp;

  IncomingCall({
    required this.callerId,
    required this.callerName,
    required this.callId,
    required this.timestamp,
  });
}

/// Represents an active call
class ActiveCall {
  final String callId;
  final String otherUserId;
  final String otherUserName;
  final DateTime startTime;
  bool isOngoing;

  ActiveCall({
    required this.callId,
    required this.otherUserId,
    required this.otherUserName,
    required this.startTime,
    this.isOngoing = true,
  });

  Duration get duration => DateTime.now().difference(startTime);
}

/// Service for handling voice/video calls over LAN with WebSocket signaling
class CallService extends ChangeNotifier {
  static final CallService _instance = CallService._private();

  factory CallService() {
    return _instance;
  }

  CallService._private();

  // Current incoming call (if any)
  IncomingCall? _incomingCall;
  IncomingCall? get incomingCall => _incomingCall;

  // Current active call (if any)
  ActiveCall? _activeCall;
  ActiveCall? get activeCall => _activeCall;

  // Reference to encryption service
  final _encryption = EncryptionService();

  /// Initialize and set up WebSocket listener for call events
  Future<void> initialize() async {
    try {
      await _encryption.initialize();
      
      ConnectionService.instance.incomingMessages.listen((msg) {
        final type = msg['type']?.toString() ?? '';

        if (type == 'call_request') {
          _handleCallRequest(msg);
        } else if (type == 'call_answer') {
          _handleCallAnswer(msg);
        } else if (type == 'call_reject') {
          _handleCallReject(msg);
        } else if (type == 'call_end') {
          _handleCallEnd(msg);
        }
      });

      print('✅ CallService initialized');
    } catch (e) {
      debugPrint('Error initializing CallService: $e');
    }
  }

  /// Handle incoming call request
  void _handleCallRequest(Map<String, dynamic> msg) {
    try {
      final from = msg['from']?.toString() ?? '';
      final callerName = msg['callerName']?.toString() ?? from;
      final callId = msg['callId']?.toString() ?? const Uuid().v4();

      if (from.isEmpty) return;

      _incomingCall = IncomingCall(
        callerId: from,
        callerName: callerName,
        callId: callId,
        timestamp: DateTime.now(),
      );

      print('📞 Incoming call from: $callerName ($from)');
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling call_request: $e');
    }
  }

  /// Handle call answer (acceptance/rejection)
  void _handleCallAnswer(Map<String, dynamic> msg) {
    try {
      final from = msg['from']?.toString() ?? '';
      final accepted = msg['accepted'] as bool? ?? false;
      final callId = msg['callId']?.toString() ?? '';

      print('${accepted ? '✅' : '❌'} Call ${accepted ? 'accepted' : 'rejected'} by $from');

      if (accepted && callId.isNotEmpty) {
        // Call was accepted by the other side
        final otherName = msg['callerName']?.toString() ?? from;

        _activeCall = ActiveCall(
          callId: callId,
          otherUserId: from,
          otherUserName: otherName,
          startTime: DateTime.now(),
        );
      } else {
        // Call was rejected
        _activeCall = null;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error handling call_answer: $e');
    }
  }

  /// Handle call rejection
  void _handleCallReject(Map<String, dynamic> msg) {
    try {
      final from = msg['from']?.toString() ?? '';
      print('❌ Call rejected by: $from');
      _activeCall = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling call_reject: $e');
    }
  }

  /// Handle call end
  void _handleCallEnd(Map<String, dynamic> msg) {
    try {
      final from = msg['from']?.toString() ?? '';
      print('📞 Call ended by: $from');

      _activeCall = null;
      _incomingCall = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling call_end: $e');
    }
  }

  /// Send call request to another user
  Future<void> sendCallRequest(String toUserId, String toUserName) async {
    try {
      final currentUserId = ConnectionService.instance.currentUserId;
      final currentName = ConnectionService.instance.currentUserName;

      if (currentUserId == null) return;

      final callId = const Uuid().v4();

      // Prepare payload
      final payload = {
        'type': 'call_request',
        'from': currentUserId,
        'callerName': currentName ?? currentUserId,
        'to': toUserId,
        'callId': callId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Encrypt for security
      try {
        final encrypted = _encryption.encryptJson(payload);
        final transmitPayload = {
          'type': 'call_request',
          'from': currentUserId,
          'callerName': currentName ?? currentUserId,
          'to': toUserId,
          'callId': callId,
          'iv': encrypted['iv'],
          'ciphertext': encrypted['ciphertext'],
          'timestamp': DateTime.now().toIso8601String(),
        };
        ConnectionService.instance.sendMessage(transmitPayload);
      } catch (e) {
        // Fall back to unencrypted if encryption fails
        debugPrint('⚠️ Encryption failed, sending unencrypted: $e');
        ConnectionService.instance.sendMessage(payload);
      }

      print('📞 Call request sent to: $toUserId');
    } catch (e) {
      debugPrint('Error sending call request: $e');
    }
  }

  /// Accept an incoming call
  Future<void> acceptCall() async {
    try {
      if (_incomingCall == null) return;

      final currentUserId = ConnectionService.instance.currentUserId;
      final currentName = ConnectionService.instance.currentUserName;

      final payload = {
        'type': 'call_answer',
        'from': currentUserId,
        'callerName': currentName ?? currentUserId,
        'to': _incomingCall!.callerId,
        'callId': _incomingCall!.callId,
        'accepted': true,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Try to encrypt
      try {
        final encrypted = _encryption.encryptJson(payload);
        final transmitPayload = {
          'type': 'call_answer',
          'from': currentUserId,
          'callerName': currentName ?? currentUserId,
          'to': _incomingCall!.callerId,
          'callId': _incomingCall!.callId,
          'accepted': true,
          'iv': encrypted['iv'],
          'ciphertext': encrypted['ciphertext'],
          'timestamp': DateTime.now().toIso8601String(),
        };
        ConnectionService.instance.sendMessage(transmitPayload);
      } catch (e) {
        debugPrint('⚠️ Encryption failed, sending unencrypted: $e');
        ConnectionService.instance.sendMessage(payload);
      }

      // Set as active call
      _activeCall = ActiveCall(
        callId: _incomingCall!.callId,
        otherUserId: _incomingCall!.callerId,
        otherUserName: _incomingCall!.callerName,
        startTime: DateTime.now(),
      );

      _incomingCall = null;
      print('✅ Call accepted');
      notifyListeners();
    } catch (e) {
      debugPrint('Error accepting call: $e');
    }
  }

  /// Reject an incoming call
  Future<void> rejectCall() async {
    try {
      if (_incomingCall == null) return;

      final currentUserId = ConnectionService.instance.currentUserId;

      final payload = {
        'type': 'call_reject',
        'from': currentUserId,
        'to': _incomingCall!.callerId,
        'callId': _incomingCall!.callId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      ConnectionService.instance.sendMessage(payload);

      _incomingCall = null;
      print('❌ Call rejected');
      notifyListeners();
    } catch (e) {
      debugPrint('Error rejecting call: $e');
    }
  }

  /// End an active call
  Future<void> endCall() async {
    try {
      if (_activeCall == null) return;

      final currentUserId = ConnectionService.instance.currentUserId;

      final payload = {
        'type': 'call_end',
        'from': currentUserId,
        'to': _activeCall!.otherUserId,
        'callId': _activeCall!.callId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      ConnectionService.instance.sendMessage(payload);

      _activeCall = null;
      _incomingCall = null;
      print('📞 Call ended');
      notifyListeners();
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  /// Check if there's an active call
  bool get hasActiveCall => _activeCall != null;

  /// Check if there's an incoming call
  bool get hasIncomingCall => _incomingCall != null;
}
