# CampusNet - Quick Start Guide

## 🚀 Get Started in 5 Minutes

### 1. **Understand the Current State**
Read these files in order:
1. `SESSION_SUMMARY.md` - What's been done
2. `CAMPUSNET_IMPLEMENTATION.md` - Complete feature guide
3. This file - How to continue

### 2. **Run the App**
```bash
cd client
flutter pub get
flutter run -d chrome
```
✅ App will launch on Chrome with zero compilation errors

### 3. **Key Files to Know**

| File | Purpose | Status |
|------|---------|--------|
| `lib/providers/auth_provider.dart` | Authentication & state | ✅ Enhanced |
| `lib/services/server_discovery_service.dart` | Server detection | ✅ NEW |
| `lib/screens/online_users/online_users_screen.dart` | Online users UI | ✅ NEW |
| `lib/screens/auth/signup_screen.dart` | Signup with role | ✅ Existing |
| `lib/models/user.dart` | User model with role | ✅ Has UserRole enum |

---

## 🎯 What Works Right Now

✅ **Authentication**
- Role selection (Student/Faculty)
- Signup with local persistence
- Auto-login detection

✅ **Server Discovery**
- UDP broadcast detection
- Static IP fallback (192.168.137.167:8083)
- Connection verification

✅ **Online Users**
- Screen with user list
- Friend request buttons
- Role badges and status

---

## ⚙️ Configuration

Edit these for your setup:

### Server IP (if using static configuration)
**File:** `lib/services/server_discovery_service.dart`
```dart
// Change this line to your server IP
final result = await _verifyServerConnection(
  '192.168.137.167',  // ← Your server IP here
  8083,               // ← Your server port
  timeout: timeout,
);
```

### Auto-login on App Restart
Already implemented in `auth_provider.dart`:
```dart
Future<bool> canAutoLogin() async {
  // Checks if token and user data exist in SharedPreferences
}
```

---

## 📋 What to Implement Next (In Order)

### 1️⃣ **Connection Status Indicator** (30 min)
Add this to `lib/screens/home_screen.dart` AppBar:
```dart
AppBar(
  actions: [
    Padding(
      padding: EdgeInsets.all(16),
      child: Consumer<WebSocketService>(
        builder: (_, wsService, __) => Chip(
          label: Text(wsService.isConnected ? 'Connected' : 'Disconnected'),
          backgroundColor: wsService.isConnected ? Colors.green : Colors.red,
        ),
      ),
    ),
  ],
)
```

### 2️⃣ **User Search Screen** (1 hour)
Create `lib/screens/users/search_users_screen.dart`:
- TextField for search query
- Search by ID/name/department
- Display results as cards
- "Add Friend" button for each

### 3️⃣ **Friend Requests Screen** (1 hour)
Create `lib/screens/social/friend_requests_screen.dart`:
- List pending requests
- Accept/Reject buttons
- Auto-add to contacts on accept

### 4️⃣ **Offline Handling** (1 hour)
Update `lib/services/websocket_service.dart`:
- Detect connection loss
- Show "Disconnected" dialog
- Auto-reconnect with backoff
- Queue pending messages

---

## 🔌 Backend Integration Checklist

Your backend server needs these endpoints:

### WebSocket Events (Real-time)
```javascript
// Server sends:
{
  type: 'online_users',
  data: [
    { id: 'STU001', name: 'Alice', role: 'student', ip: '192.168.1.10' },
    { id: 'FAC001', name: 'Dr. Smith', role: 'faculty', ip: '192.168.1.11' },
  ]
}

// Client sends:
{
  type: 'friend_request',
  fromUserId: 'STU001',
  toUserId: 'STU002',
  message: 'Let\'s connect!'
}
```

### HTTP REST Endpoints
```
GET /users/online
  Response: [{id, name, role, ip, status}]

GET /search/users?q=query
  Response: [{id, name, role, department, email}]

POST /friend-request/send
  Body: {toUserId, message}
  Response: {success, requestId}

POST /friend-request/accept
  Body: {requestId}
  Response: {success}
```

---

## 🧪 Testing Without Backend

Use mock data to test UI:
- `online_users_screen.dart` has mock data in `_fetchOnlineUsers()`
- Modify as needed for testing different scenarios
- Replace mock with real API call when backend ready

---

## 📱 Architecture Overview

```
┌─────────────────────────────────────┐
│       CampusNet App                 │
├─────────────────────────────────────┤
│  UI Layer (Screens & Widgets)       │
│  ├─ OnlineUsersScreen              │
│  ├─ ChatsScreen                    │
│  ├─ GroupChatScreen                │
│  └─ SettingsScreen                 │
├─────────────────────────────────────┤
│  State Management (Providers)       │
│  ├─ AuthProvider                   │
│  ├─ WebSocketService               │
│  └─ GroupService                   │
├─────────────────────────────────────┤
│  Services (Business Logic)          │
│  ├─ ServerDiscoveryService         │
│  ├─ NetworkService                 │
│  └─ WebSocketService               │
├─────────────────────────────────────┤
│  Local Storage                      │
│  ├─ SharedPreferences (token, user)│
│  └─ Files (future: SQLite)         │
├─────────────────────────────────────┤
│  Server Connection                  │
│  ├─ WebSocket (real-time)          │
│  ├─ HTTP (files, search)           │
│  └─ UDP (discovery)                │
└─────────────────────────────────────┘
```

---

## 🐛 Common Issues & Solutions

### Issue: "No online users shown"
**Solution:** Check mock data in `online_users_screen.dart` → `_fetchOnlineUsers()`

### Issue: "Server not discovered"
**Solution:** Verify server IP in `server_discovery_service.dart`

### Issue: "Auto-login not working"
**Solution:** Check SharedPreferences keys in `auth_provider.dart` constants

### Issue: "Friend request button disabled"
**Solution:** Check if `NetworkService` is initialized

---

## 💡 Code Examples

### Send Friend Request
```dart
final networkService = NetworkService();
await networkService.sendFriendRequest(
  user,  // User object
  'Let\'s connect!',  // Message
);
```

### Discover Server
```dart
final discoveryService = ServerDiscoveryService();
final serverUrl = await discoveryService.discoverServer(
  configuredServerIp: '192.168.137.167',
  configuredServerPort: 8083,
);
```

### Auto-Login Check
```dart
final authProvider = Provider.of<AuthProvider>(context, listen: false);
final canAutoLogin = await authProvider.canAutoLogin();
```

---

## 📖 Documentation Files

| File | Contains |
|------|----------|
| `SESSION_SUMMARY.md` | What was completed this session |
| `CAMPUSNET_IMPLEMENTATION.md` | Complete feature documentation |
| `README.md` | Project overview |
| This file | Quick start guide |

---

## ⚡ Performance Tips

1. **Use mock data for testing** - Don't hammer your server during development
2. **Enable hot reload** - Press 'r' in terminal for faster iteration
3. **Use Flutter DevTools** - Click DevTools link in terminal output
4. **Profile performance** - Use DevTools Performance tab

---

## 🤝 Communication

### When Implementing Features
1. Reference the spec in `CAMPUSNET_IMPLEMENTATION.md`
2. Check existing code patterns in similar screens
3. Use Material Design 3 components
4. Add error handling for all API calls

### Code Style
- Use `const` constructors where possible
- Null-safe code throughout
- Meaningful variable names
- Add comments for complex logic

---

## 🎓 Next Developer Checklist

- [ ] Read SESSION_SUMMARY.md
- [ ] Read CAMPUSNET_IMPLEMENTATION.md
- [ ] Run the app on Chrome
- [ ] Review ServerDiscoveryService
- [ ] Review OnlineUsersScreen
- [ ] Review auth_provider.dart
- [ ] Understand the flow diagram
- [ ] Implement connection status indicator
- [ ] Create user search screen
- [ ] Connect to backend server

---

## 📞 Quick Reference

**Main Files:**
- Authentication: `lib/providers/auth_provider.dart`
- Server Discovery: `lib/services/server_discovery_service.dart`
- Online Users: `lib/screens/online_users/online_users_screen.dart`
- WebSocket: `lib/services/websocket_service.dart`

**Run Commands:**
```bash
flutter run -d chrome              # Run on Chrome
flutter pub get                    # Get dependencies
flutter analyze                    # Check code
flutter format lib/                # Format code
```

**Key Enums:**
- `UserRole`: `student`, `faculty`, `admin`
- `MessageType`: `text`, `image`, `video`, etc.
- `MessageStatus`: `sending`, `sent`, `delivered`, `read`

---

**Ready to build? Start with the Connection Status Indicator - it's the easiest first feature! 🚀**
