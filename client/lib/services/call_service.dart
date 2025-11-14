import 'package:flutter/foundation.dart';
import 'connection_service.dart';

/// Represents an incoming call
class IncomingCall {
  final String callerId;
  final String callerName;
  final DateTime timestamp;

  IncomingCall({
    required this.callerId,
    required this.callerName,
    required this.timestamp,
  });
}

/// Represents an active call
class ActiveCall {
  final String otherUserId;
  final String otherUserName;
  final DateTime startTime;
  bool isOngoing;

  ActiveCall({
    required this.otherUserId,
    required this.otherUserName,
    required this.startTime,
    this.isOngoing = true,
  });

  Duration get duration => DateTime.now().difference(startTime);
}

/// Service for handling voice/video calls over LAN
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

  /// Initialize and set up WebSocket listener for call events
  Future<void> initialize() async {
    ConnectionService.instance.incomingMessages.listen((msg) {
      final type = msg['type']?.toString() ?? '';
      
      if (type == 'call_request') {
        _handleCallRequest(msg);
      } else if (type == 'call_answer') {
        _handleCallAnswer(msg);
      } else if (type == 'call_end') {
        _handleCallEnd(msg);
      }
    });
  }

  /// Handle incoming call request
  void _handleCallRequest(Map<String, dynamic> msg) {
    try {
      final from = msg['from']?.toString() ?? '';
      final callerName = msg['callerName']?.toString() ?? from;

      if (from.isEmpty) return;

      _incomingCall = IncomingCall(
        callerId: from,
        callerName: callerName,
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

      print('${accepted ? '✅' : '❌'} Call ${ accepted ? 'accepted' : 'rejected'} by $from');

      if (accepted) {
        // Call was accepted by the other side
        final currentUserId = ConnectionService.instance.currentUserId;
        final otherName = msg['callerName']?.toString() ?? from;
        
        _activeCall = ActiveCall(
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

      final payload = {
        'type': 'call_request',
        'from': currentUserId,
        'callerName': currentName ?? currentUserId,
        'to': toUserId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      ConnectionService.instance.sendMessage(payload);
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
        'accepted': true,
        'timestamp': DateTime.now().toIso8601String(),
      };

      ConnectionService.instance.sendMessage(payload);

      // Set as active call
      _activeCall = ActiveCall(
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
        'type': 'call_answer',
        'from': currentUserId,
        'to': _incomingCall!.callerId,
        'accepted': false,
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
