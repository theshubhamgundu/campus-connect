# Quick Reference - Message Sending Test

**APK:** 51.65 MB | **Built:** Nov 15, 2025 02:09:38 | **Status:** Ready

---

## One-Minute Test Procedure

### Setup
```
1. Both devices connected to hotspot (10.100.7.10)
2. Both users logged in (S123, HA1244)
3. Server running: "CampusNet Server is READY"
```

### Test Send Message
```
Device 1 (S123)
└─ Tap user in "Nearby Users" → HA1244
└─ Type: "test message"
└─ Tap Send button

Expected Result:
✅ Message appears in chat UI (sent by me, blue)
✅ Console shows: 🔴🟠🔵🟡 logs
✅ Console shows: "✅ MESSAGE SENT!"

Server Console:
✅ Shows: "💬 Chat: S123 → HA1244: \"test message\""

Device 2 (HA1244)
✅ Message appears in chat (from S123, gray)
```

---

## What to Look For in Console

### ✅ SUCCESS Sequence
```
🔴 [SendButton] ============================================
🔴 [SendButton] User tapped SEND button
🔴 [SendButton] Message: "test message"
🔴 [SendButton] Recipient: HA1244
🔴 [SendButton] ============================================
🔴 [SendButton] Calling chatService.sendMessage()...

🟠 [ChatService] ============================================
🟠 [ChatService.sendMessage] CALLED
🟠 [ChatService] currentUserId=S123
🟠 [ChatService] toUserId=HA1244
🟠 [ChatService] Adding to memory...
🟠 [ChatService] ✅ Added to memory
🟠 [ChatService] ... (saving to Hive, encrypting)
🟠 [ChatService] ✅ ConnectionService.sendMessage() returned
🟠 [ChatService] ============================================

🔵 [ConnectionService.sendMessage] ============================================
🔵 [ConnectionService] CALLED with payload:
🔵 [ConnectionService]   Type: chat_message
🔵 [ConnectionService] WebSocket state: _ws=connected
🔵 [ConnectionService] Connection status: connected
🔵 [ConnectionService] ... (JSON encoding)
🔵 [ConnectionService] Calling _sendRaw()...
🔵 [ConnectionService] _sendRaw() returned
🔵 [ConnectionService] ============================================

🟡 [_sendRaw] Called
🟡 [_sendRaw]   WebSocket: connected
🟡 [_sendRaw]   Status: connected
🟡 [_sendRaw] WebSocket is connected, calling add()...
🟡 [_sendRaw] ✅ WebSocket.add() succeeded - MESSAGE SENT!

✅ Message sent successfully
```

### ❌ FAILURE - See 🔴 but NO 🟠
**Problem:** ChatService not called  
**Action:** Check if message text empty or provider error

### ❌ FAILURE - See 🔴🟠 but NO 🔵
**Problem:** ChatService error  
**Action:** Look for ❌ error after 🟠 section

### ❌ FAILURE - See 🔴🟠🔵 but NO 🟡
**Problem:** ConnectionService error  
**Action:** Look for exception after 🔵 section

### ❌ FAILURE - See all logs but `_ws=null`
**Problem:** WebSocket not connected  
**Action:** Check server is running; wait for reconnect

---

## Server Console Verification

### ✅ Good Logs
```
💬 Chat: S123 → HA1244: "test message"
```

### ❌ Bad - No chat logs
```
📨 Responded to get_online_users (count: 2)
📨 Responded to get_online_users (count: 2)
📨 Responded to get_online_users (count: 2)
(no chat logs!)
```

### ❌ Bad - Parse errors
```
❌ Failed to parse chat_message
❌ Unknown field: 'from' (expected 'senderId')
```

---

## Device 2 Verification

### ✅ Good - Message Received
Device 2 chat screen should show:
```
(earlier messages above)

[Gray bubble] HA1244 | today 14:30
"test message"

(my messages below)
```

### ❌ Bad - Nothing appears
Device 2 chat still empty or old messages only

---

## Quick Diagnostic

| What You See | Meaning | Next Action |
|---|---|---|
| 🔴 logs, no 🟠 | Send button works, Chat not called | Check provider |
| 🔴+🟠 logs, no 🔵 | Chat service works, Connection not called | Look for error after 🟠 |
| 🔴+🟠+🔵 logs, no 🟡 | Connection works, _sendRaw not called | Check exception |
| All 4 + NO server log | WebSocket sent, server didn't receive | Check network/firewall |
| Server log ✅ + Device 2 nothing | Server got it, recipient not listening | Check receiver's app |
| Everything works! 🎉 | All fixed | DONE! ✅ |

---

## Common Problems & Fixes

### Problem: "WebSocket null" in logs

**Cause:** Server disconnected or not connected yet  
**Fix:** 
- Check server is running
- Ensure device can reach server IP (10.100.7.10)
- App will auto-reconnect, wait 5 seconds and retry send

### Problem: Send button appears disabled

**Cause:** Connection not established  
**Fix:**
- Ensure both devices on same network
- Check server is accepting connections
- Toggle app off/on to retry connection

### Problem: Message sent but server logs don't show chat

**Cause:** Payload format wrong OR encryption issue  
**Fix:**
- Check client logs show all 4 stages
- Verify server console for encryption errors
- Try again with fresh APK

### Problem: Recipient doesn't see message

**Cause:** Recipient's app not listening OR message never arrived  
**Fix:**
- Check recipient app is open and on chat screen
- Check server logs show message was received
- Check server logs show message was forwarded

---

## Test Matrix

```
┌────────────────────────────────────────────────────────────┐
│                      TEST CHECKLIST                        │
├────────────────────────────────────────────────────────────┤
│ Setup:                                                     │
│  [ ] Server running (both users online)                   │
│  [ ] Both devices on network                              │
│  [ ] APK v51.65 MB deployed                               │
│                                                            │
│ Device 1 (S123) Actions:                                  │
│  [ ] Tap HA1244 in nearby users                           │
│  [ ] Chat screen opens                                     │
│  [ ] Type "hello"                                          │
│  [ ] Tap Send                                              │
│  [ ] Message appears as blue bubble                       │
│  [ ] See 🔴🟠🔵🟡 logs                                    │
│  [ ] See "MESSAGE SENT!" log                              │
│                                                            │
│ Server Console:                                           │
│  [ ] See "💬 Chat: S123 → HA1244: \"hello\""             │
│                                                            │
│ Device 2 (HA1244):                                        │
│  [ ] Message appears as gray bubble                       │
│  [ ] Timestamp shows                                       │
│  [ ] Can reply and send                                    │
│                                                            │
│ Persistence:                                              │
│  [ ] Close Device 1 app                                   │
│  [ ] Reopen app                                            │
│  [ ] Go to HA1244 chat                                    │
│  [ ] Old messages still visible                           │
│                                                            │
│ Summary:                                                  │
│  [ ] All 11 checkboxes checked = SUCCESS ✅              │
└────────────────────────────────────────────────────────────┘
```

---

## Files Location

```
APK:
  client/build/app/outputs/flutter-apk/app-release.apk

Documentation:
  MESSAGE_SENDING_DEBUG_GUIDE.md
  FIXES_APPLIED.md
  PAYLOAD_FORMAT_REFERENCE.md
  SESSION_SUMMARY.md
  THIS FILE: QUICK_REFERENCE.md

Server:
  Still running on port 8083 (in separate terminal)
```

---

## Success = "It Just Works"

When everything is fixed:
- Type message → Tap Send → Message appears instantly ✅
- Server logs it ✅
- Other person sees it ✅
- Reply works ✅
- History persists ✅

**That's it. No errors, no weird behavior, just working messaging.**

---

**Created:** Nov 15, 2025  
**For:** CampusNet Flutter Chat  
**Status:** Ready to test ✅
