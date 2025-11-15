# Message Payload Format - Client ↔ Server Contract

**Date:** November 15, 2025  
**Status:** Updated to match server expectations

---

## Text Message Payload

### Client Sends (Encrypted)

```json
{
  "type": "chat_message",
  "senderId": "S123",
  "receiverId": "HA1244",
  "message": "hello world",
  "iv": "<base64_initialization_vector>",
  "ciphertext": "<base64_encrypted_data>",
  "timestamp": "2025-11-15T14:30:45.123456"
}
```

### Client Sends (Fallback - Unencrypted)

```json
{
  "type": "chat_message",
  "senderId": "S123",
  "receiverId": "HA1244",
  "message": "hello world",
  "timestamp": "2025-11-15T14:30:45.123456"
}
```

### Server Receives & Logs

```
💬 Chat: S123 → HA1244: "hello world"
```

---

## File Message Payload

### Client Sends (Encrypted)

```json
{
  "type": "file_message",
  "senderId": "S123",
  "receiverId": "HA1244",
  "fileName": "notes.pdf",
  "fileType": "document",
  "iv": "<base64_iv>",
  "ciphertext": "<base64_encrypted_file_data>",
  "timestamp": "2025-11-15T14:30:45.123456"
}
```

### Server Receives & Logs

```
📁 File received: notes.pdf from S123
```

---

## Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | ✅ | Must be `"chat_message"` or `"file_message"` |
| `senderId` | string | ✅ | User ID of sender (e.g., "S123") |
| `receiverId` | string | ✅ | User ID of recipient (e.g., "HA1244") |
| `message` | string | ✅ (text only) | Text content of message |
| `fileName` | string | ✅ (files only) | Name of file being sent |
| `fileType` | string | ⚠️ (files only) | Type: "image", "document", "audio" |
| `iv` | string | ⚠️ (encrypted only) | Base64-encoded initialization vector |
| `ciphertext` | string | ⚠️ (encrypted only) | Base64-encoded encrypted data |
| `timestamp` | string | ✅ | ISO8601 timestamp (e.g., "2025-11-15T14:30:45.123456") |

---

## Payload Size Examples

### Small Text Message
```json
{
  "type": "chat_message",
  "senderId": "S123",
  "receiverId": "HA1244",
  "message": "hi",
  "timestamp": "2025-11-15T14:30:45.123456"
}
```
**Size:** ~120 bytes

### Small Text Message (Encrypted)
```json
{
  "type": "chat_message",
  "senderId": "S123",
  "receiverId": "HA1244",
  "message": "hi",
  "iv": "BQKc1234567890abc=",
  "ciphertext": "lkjhgfdsazxcvbnm1234567890abcdefghijklmnop=",
  "timestamp": "2025-11-15T14:30:45.123456"
}
```
**Size:** ~260 bytes

---

## Critical Changes from Previous Version

| Aspect | Old Format ❌ | New Format ✅ |
|--------|---|---|
| Sender field | `"from": "S123"` | `"senderId": "S123"` |
| Receiver field | `"to": "HA1244"` | `"receiverId": "HA1244"` |
| Message field | `"text": "..."` | `"message": "..."` |
| Encryption | (no fallback) | (unencrypted fallback if encryption fails) |

---

## Client Sending Implementation

### In ChatServiceV3.sendMessage()

```dart
// Prepare plaintext payload
final payload = {
  'type': 'chat_message',
  'senderId': currentUserId,      // ✅ Correct
  'receiverId': toUserId,         // ✅ Correct
  'message': messageText,
  'timestamp': timestamp.toIso8601String(),
};

// Try to encrypt
Map<String, dynamic> transmitPayload = payload;
try {
  final encrypted = _encryption.encryptJson(payload);
  transmitPayload = {
    'type': 'chat_message',
    'senderId': currentUserId,
    'receiverId': toUserId,
    'message': messageText,
    'iv': encrypted['iv'],
    'ciphertext': encrypted['ciphertext'],
    'timestamp': timestamp.toIso8601String(),
  };
  print('🟠 [ChatService] ✅ Encryption successful');
} catch (encryptError) {
  print('🟠 [ChatService] ⚠️ Encryption failed, sending unencrypted');
  // Falls back to plaintext payload
}

// Send to server
ConnectionService.instance.sendMessage(transmitPayload);
```

---

## Server Receiving Implementation (Expected)

### Server should handle:

```dart
// Receive encrypted message
final msg = jsonDecode(rawMessage);
if (msg['type'] == 'chat_message') {
  final senderId = msg['senderId'];      // ✅ Correct field
  final receiverId = msg['receiverId'];  // ✅ Correct field
  final messageText = msg['message'];    // ✅ Correct field
  
  // Decrypt if encrypted
  String decrypted = messageText;
  if (msg.containsKey('ciphertext')) {
    decrypted = await encryption.decrypt(
      iv: msg['iv'],
      ciphertext: msg['ciphertext'],
    );
  }
  
  // Log
  print('💬 Chat: $senderId → $receiverId: "$decrypted"');
  
  // Save and forward to recipient
}
```

---

## Testing Payload Manually

### Using netcat/telnet

```bash
# Connect to server
nc 10.100.7.10 8083

# Send test message (JSON, then press Enter twice)
{"type":"chat_message","senderId":"S123","receiverId":"HA1244","message":"test","timestamp":"2025-11-15T14:30:45Z"}

# Expected server log:
# 💬 Chat: S123 → HA1244: "test"
```

---

## Common Payload Errors

### ❌ Error: Missing `senderId` field

```json
{
  "type": "chat_message",
  "from": "S123",          // ❌ WRONG - should be "senderId"
  "receiverId": "HA1244",
  "message": "hello"
}
```

**Server logs:** 
```
❌ Chat message missing senderId field
```

**Fix:** Change `"from"` to `"senderId"`

---

### ❌ Error: Wrong message field name

```json
{
  "type": "chat_message",
  "senderId": "S123",
  "receiverId": "HA1244",
  "text": "hello"           // ❌ WRONG - should be "message"
}
```

**Server logs:**
```
❌ Chat message missing message field
```

**Fix:** Change `"text"` to `"message"`

---

### ❌ Error: Mismatched encryption

```json
{
  "type": "chat_message",
  "senderId": "S123",
  "receiverId": "HA1244",
  "message": "hello",
  "iv": "wrongBase64!",    // ❌ Invalid base64
  "ciphertext": "alsoBadBase64!"
}
```

**Server logs:**
```
❌ Failed to decrypt message: Invalid base64
```

**Fix:** Ensure iv and ciphertext are valid base64

---

### ✅ Correct Payload (Text)

```json
{
  "type": "chat_message",
  "senderId": "S123",
  "receiverId": "HA1244",
  "message": "hello world",
  "timestamp": "2025-11-15T14:30:45.123456Z"
}
```

**Server logs:**
```
💬 Chat: S123 → HA1244: "hello world"
```

---

### ✅ Correct Payload (Encrypted)

```json
{
  "type": "chat_message",
  "senderId": "S123",
  "receiverId": "HA1244",
  "message": "hello world",
  "iv": "BQKc1234567890abcdef",
  "ciphertext": "abc123xyz/+====",
  "timestamp": "2025-11-15T14:30:45.123456Z"
}
```

**Server logs:**
```
💬 Chat: S123 → HA1244: "hello world"
```

---

## Payload Validation Checklist

When testing, verify:

- [ ] `"type"` is exactly `"chat_message"` or `"file_message"`
- [ ] `"senderId"` contains valid user ID (e.g., "S123")
- [ ] `"receiverId"` contains valid user ID (e.g., "HA1244")
- [ ] `"message"` contains non-empty text (for text messages)
- [ ] `"timestamp"` is valid ISO8601 format
- [ ] If encrypted:
  - [ ] `"iv"` is present and valid base64
  - [ ] `"ciphertext"` is present and valid base64
  - [ ] `"message"` field still contains plaintext OR empty
- [ ] JSON is valid (no syntax errors)
- [ ] All string values are quoted

---

## Debugging: What to Print

### On Client (before sending):

```dart
print('📝 Payload keys: ${payload.keys.toList()}');
print('📝 Payload: ${jsonEncode(payload)}');
```

**Expected output:**
```
📝 Payload keys: [type, senderId, receiverId, message, timestamp]
📝 Payload: {"type":"chat_message","senderId":"S123",...}
```

### On Server (after receiving):

```dart
print('📝 Received keys: ${msg.keys.toList()}');
print('📝 Received: $msg');
```

**Expected output:**
```
📝 Received keys: [type, senderId, receiverId, message, timestamp, iv, ciphertext]
📝 Received: {type: chat_message, senderId: S123, ...}
```

---

**Document Status:** ✅ Current and accurate  
**Last Updated:** 2025-11-15  
**Applies To:** Client v51.6 MB (November 15, 2025)
