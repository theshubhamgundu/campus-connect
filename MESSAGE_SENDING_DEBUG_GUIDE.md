# Message Sending Debug Guide

**Date:** November 15, 2025  
**APK Version:** 51.6 MB (with comprehensive logging)  
**Status:** Ready for Testing

---

## Overview

This document explains the complete message sending pipeline with color-coded logs for easy troubleshooting.

---

## Complete Message Send Flow with Expected Logs

### 1️⃣ **Send Button Tapped** (Direct Chat Screen)
**Color: 🔴 RED**

When user types message and taps send button:

```
🔴 [SendButton] ============================================
🔴 [SendButton] User tapped SEND button
🔴 [SendButton] Message: "hello world"
🔴 [SendButton] Recipient: HA1244
🔴 [SendButton] ============================================
🔴 [SendButton] Calling chatService.sendMessage()...
```

**What it means:** User interface recognized the send action and initiated the message sending process.

**If you DON'T see this:** Send button is not wired correctly or not clickable.

---

### 2️⃣ **ChatService Processing** (Chat Service V3)
**Color: 🟠 ORANGE**

Once ChatService.sendMessage() is called:

```
🟠 [ChatService] ============================================
🟠 [ChatService.sendMessage] CALLED
🟠 [ChatService] currentUserId=S123
🟠 [ChatService] toUserId=HA1244
🟠 [ChatService] Adding to memory...
🟠 [ChatService] ✅ Added to memory
🟠 [ChatService] Saving to Hive storage...
🟠 [ChatService] ✅ Saved to Hive
🟠 [ChatService] Payload prepared (plaintext):
🟠 [ChatService]   type: chat_message
🟠 [ChatService]   senderId: S123
🟠 [ChatService]   receiverId: HA1244
🟠 [ChatService]   message: hello world
🟠 [ChatService] Attempting encryption...
🟠 [ChatService] ✅ Encryption successful
🟠 [ChatService] About to call ConnectionService.sendMessage()...
🟠 [ChatService]   Payload keys: [type, senderId, receiverId, message, iv, ciphertext, timestamp]
🟠 [ChatService] ✅ ConnectionService.sendMessage() returned
🟠 [ChatService] ============================================
```

**What it means:**
- Message saved locally ✅
- Message saved to Hive ✅
- Encryption succeeded ✅
- About to send over WebSocket ✅

**If you see this instead:**
```
🟠 [ChatService] ⚠️ Encryption failed: ...
🟠 [ChatService] Falling back to unencrypted transmission
```
**What it means:** Encryption failed, but message will still be sent unencrypted. This is acceptable for testing.

**If you DON'T see any 🟠 logs:** ChatService.sendMessage() was never called.

---

### 3️⃣ **ConnectionService Sending** (Connection Service)
**Color: 🔵 BLUE**

When ConnectionService.sendMessage() is invoked:

```
🔵 [ConnectionService.sendMessage] ============================================
🔵 [ConnectionService] CALLED with payload:
🔵 [ConnectionService]   Type: chat_message
🔵 [ConnectionService]   Keys: [type, senderId, receiverId, message, iv, ciphertext, timestamp]
🔵 [ConnectionService]   senderId: S123
🔵 [ConnectionService]   receiverId: HA1244
🔵 [ConnectionService]   message: hello world
🔵 [ConnectionService]   has iv: true
🔵 [ConnectionService]   has ciphertext: true
🔵 [ConnectionService] WebSocket state: _ws=connected
🔵 [ConnectionService] Connection status: connected
🔵 [ConnectionService] JSON encoded (487 bytes)
🔵 [ConnectionService] Calling _sendRaw()...
🔵 [ConnectionService] _sendRaw() returned
🔵 [ConnectionService] ============================================
```

**What it means:**
- WebSocket is connected ✅
- Connection status is 'connected' ✅
- Payload properly formatted ✅
- About to send raw JSON ✅

**Critical Check - WebSocket State:**
- If you see `_ws=connected` → Good, ready to send
- If you see `_ws=null` → WebSocket is not connected!
- If you see `Connection status: disconnected` → Not connected!

**If you DON'T see any 🔵 logs:** ConnectionService.sendMessage() was never called.

---

### 4️⃣ **WebSocket Raw Send** (_sendRaw)
**Color: 🟡 YELLOW**

The actual WebSocket transmission:

```
🟡 [_sendRaw] Called
🟡 [_sendRaw]   WebSocket: connected
🟡 [_sendRaw]   Status: connected
🟡 [_sendRaw]   JSON length: 487 bytes
🟡 [_sendRaw]   First 80 chars: {"type":"chat_message","senderId":"S123","receiverId":"HA1244",...
🟡 [_sendRaw] WebSocket is connected, calling add()...
🟡 [_sendRaw] ✅ WebSocket.add() succeeded - MESSAGE SENT!
```

**What it means:** Message successfully sent over WebSocket to server!

**Critical Line:** 
```
🟡 [_sendRaw] ✅ WebSocket.add() succeeded - MESSAGE SENT!
```
This is the moment when the message leaves the client device.

**If instead you see:**
```
🟡 [_sendRaw] ⚠️ WebSocket is null, queueing message
🟡 [_sendRaw]   Queue now has 1 messages
```
**What it means:** WebSocket is null! Message queued but not sent yet.

**If you DON'T see any 🟡 logs:** _sendRaw() was never called.

---

## Complete Flow Sequence

**Expected sequence when sending message "hello":**

```
🔴 [SendButton] ============================================
🔴 [SendButton] User tapped SEND button
🔴 [SendButton] Message: "hello"
🔴 [SendButton] Recipient: HA1244
🔴 [SendButton] ============================================
🔴 [SendButton] Calling chatService.sendMessage()...

🟠 [ChatService] ============================================
🟠 [ChatService.sendMessage] CALLED
🟠 [ChatService] currentUserId=S123
🟠 [ChatService] toUserId=HA1244
🟠 [ChatService] ... (adding, saving, encrypting)
🟠 [ChatService] About to call ConnectionService.sendMessage()...
🟠 [ChatService] ✅ ConnectionService.sendMessage() returned
🟠 [ChatService] ============================================

🔵 [ConnectionService.sendMessage] ============================================
🔵 [ConnectionService] CALLED with payload:
🔵 [ConnectionService] WebSocket state: _ws=connected
🔵 [ConnectionService] Connection status: connected
🔵 [ConnectionService] ... (JSON encoding)
🔵 [ConnectionService] Calling _sendRaw()...
🔵 [ConnectionService] _sendRaw() returned
🔵 [ConnectionService] ============================================

🟡 [_sendRaw] Called
🟡 [_sendRaw]   WebSocket: connected
🟡 [_sendRaw] WebSocket is connected, calling add()...
🟡 [_sendRaw] ✅ WebSocket.add() succeeded - MESSAGE SENT!

✅ Message sent successfully
```

**Total expected flow: ~15-20 log lines from 4 different services**

---

## Troubleshooting Guide

### ❌ Problem: Only see 🔴 logs, no 🟠 logs

**Diagnosis:** ChatService.sendMessage() was not called  
**Possible Causes:**
1. Provider not set up correctly
2. ChatService instance is null
3. Exception thrown before ChatService call

**Fix:** Check if there's an exception between 🔴 and 🟠 logs

---

### ❌ Problem: See 🔴 and 🟠, but no 🔵 logs

**Diagnosis:** ConnectionService.sendMessage() was not called  
**Possible Causes:**
1. Exception in ChatService (after logging but before call)
2. Check if there's an error message after 🟠 section

**Fix:** Look for ❌ error logs after 🟠 section

---

### ❌ Problem: See 🔴, 🟠, 🔵 but no 🟡 logs

**Diagnosis:** _sendRaw() was not called  
**Possible Causes:**
1. Exception in ConnectionService.sendMessage()
2. JSON encoding failed

**Fix:** Look for exception after 🔵 section

---

### ❌ Problem: See all logs but `🟡 [_sendRaw]   WebSocket: null`

**Diagnosis:** WebSocket is not connected  
**Expected:** Message will be queued  
**Solution:** WebSocket should auto-reconnect; wait a moment and retry send

---

### ❌ Problem: Server doesn't receive message even after "MESSAGE SENT!" log

**Diagnosis:** 
1. Payload format doesn't match server expectation
2. Server not listening on port 8083
3. Network connectivity issue

**Check:**
- Server console shows `WebSocket listening on 8083` ✅
- Server console shows both users connected ✅
- Payload has correct field names: `senderId`, `receiverId` ✅
- Network is functioning (both devices can ping each other)

---

## What Happens After "MESSAGE SENT!" on Server

If client successfully sends message, server should:

1. Receive WebSocket message
2. Parse JSON
3. Log: `💬 Chat: S123 → HA1244: "hello"`
4. Save to message log
5. Send to recipient if online
6. Or queue if recipient offline

**If you see "MESSAGE SENT!" on client but server has no corresponding log:**
- Problem is in server handling, not client sending
- Check server WebSocket message handler

---

## How to View Logs

### On Android Device

```bash
# Connect device with adb
adb logcat | grep -E "\[SendButton\]|\[ChatService\]|\[ConnectionService\]|\[_sendRaw\]|\[ReceiveMessage\]|Chat:|File received:"
```

### In Flutter Console

Logs should appear in Flutter's built-in console / debug output when running `flutter run`

### In Emulator

Android Studio's Logcat window will show all print statements

---

## Expected Server Response

When server receives your message successfully, it should log:

```
💬 Chat: S123 → HA1244: "hello"
```

If you see this on server console → **Message delivery successful!**

---

## Testing Checklist

- [ ] Both devices logged in (server shows 2 users online)
- [ ] Tapped other user in nearby list → chat screen opened
- [ ] Typed message and tapped send
- [ ] See 🔴 logs on client (send button)
- [ ] See 🟠 logs on client (chat service)
- [ ] See 🔵 logs on client (connection service)
- [ ] See 🟡 logs on client (websocket)
- [ ] See "MESSAGE SENT!" confirmation on client
- [ ] See `💬 Chat: S123 → HA1244: "message"` on server
- [ ] Recipient device shows message in chat

✅ **All 10 checks pass = End-to-end messaging works!**

---

**Date Created:** 2025-11-15  
**Last Updated:** 2025-11-15
