# CampusNet Implementation Guide

## ✅ Completed Components

### 1. **Authentication & Local Persistence** 
- ✅ Role-based signup (Student/Faculty) in `auth_provider.dart`
- ✅ Local storage with SharedPreferences (`_saveAuthState()`, `_loadSavedUser()`)
- ✅ Auto-login support (`canAutoLogin()`, `clearAuthData()`)
- ✅ Device session tracking

**Usage:**
```dart
final authProvider = Provider.of<AuthProvider>(context);
await authProvider.signUp(
  userId: 'STU001',
  name: 'John Doe',
  email: 'john@campus.edu',
  password: 'securepass',
  role: UserRole.student,
  department: 'CS',
);
```

### 2. **Server Discovery Service**
- ✅ UDP broadcast discovery for local server detection
- ✅ Fallback to configured server IP (e.g., 192.168.137.167:8083)
- ✅ TCP connection verification
- ✅ Auto-discovery polling with configurable intervals

**File:** `lib/services/server_discovery_service.dart`

**Usage:**
```dart
final discoveryService = ServerDiscoveryService();
final serverUrl = await discoveryService.discoverServer(
  configuredServerIp: '192.168.137.167',
  configuredServerPort: 8083,
  timeout: Duration(seconds: 5),
);
// Returns: 'ws://192.168.137.167:8083' or null if not found
```

### 3. **Online Users List Screen**
- ✅ Display online users with name, ID, role, department
- ✅ Online status indicator (green dot)
- ✅ Friend request functionality
- ✅ Role badges (Student/Faculty)
- ✅ Pull-to-refresh and error handling

**File:** `lib/screens/online_users/online_users_screen.dart`

**Usage:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => OnlineUsersScreen()),
);
```

---

## 🔄 User Flow Implementation

### Flow 1: Role Selection → Signup → Auto-Connect

```
1. OnboardingScreen
   └─> User selects role (Student/Faculty)

2. SignupScreen
   └─> Role selection passed to auth_provider.signUp()
   └─> User data + role saved to SharedPreferences

3. Auto-Login (Next app launch)
   └─> SplashScreen checks canAutoLogin()
   └─> If true: Load saved user & role
   └─> Initialize WebSocket connection
   └─> Discover server via ServerDiscoveryService
```

**Implementation in main.dart / splash_screen.dart:**
```dart
Future<void> _initializeApp() async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  
  // Check if can auto-login
  final canAutoLogin = await authProvider.canAutoLogin();
  
  if (canAutoLogin) {
    await authProvider.initialize();
    // Server discovery and WebSocket connection happen in initialize()
  }
}
```

### Flow 2: Online Users → Search → Add Friend → Chat

```
1. OnlineUsersScreen
   └─> Display list of online users [{id, name, role, status, ip}]
   └─> "Add Friend" button sends friend request

2. Friend Request Flow
   └─> NetworkService.sendFriendRequest(user)
   └─> Server routes request to recipient
   └─> Recipient sees FriendRequestsScreen

3. On Accept
   └─> Both users added to Contacts
   └─> Chat screen available between them

4. Chat Interface
   └─> Send messages via WebSocket
   └─> Messages saved locally + server cache
   └─> File attachment support (TBD)
```

---

## 🚀 Next Steps (In Priority Order)

### 1. **Connection Status UI** (High Priority)
Add visual indicator in home_screen.dart showing:
- "Connected ✓" (green)
- "Connecting..." (yellow)
- "Disconnected" (red) with reconnect button

**Implementation:**
```dart
// In home_screen.dart
AppBar(
  title: Text('CampusNet'),
  actions: [
    Padding(
      padding: EdgeInsets.all(16),
      child: Consumer<WebSocketService>(
        builder: (ctx, wsService, _) => Chip(
          label: Text(wsService.isConnected ? 'Connected' : 'Disconnected'),
          backgroundColor: wsService.isConnected ? Colors.green : Colors.red,
        ),
      ),
    ),
  ],
)
```

### 2. **User Search** (Medium Priority)
Add search by ID, name, or department:
- Create SearchUsersScreen
- Add search endpoint to NetworkService
- Show profile cards with "Add" button

### 3. **Friend Requests** (Medium Priority)
Create FriendRequestsScreen:
- List pending friend requests
- Accept/Reject buttons
- Auto-add to contacts on accept

### 4. **File Sharing** (Medium Priority)
Add file upload/download:
- File picker integration
- Upload via WebSocket or HTTP
- Download with progress indicator

### 5. **Call Feature (WebRTC)** (Low Priority)
Implement audio calls:
- Call initiation via WebSocket
- WebRTC P2P setup or server relay
- In-call UI with mute/speaker controls

### 6. **Offline & Reconnect** (High Priority)
Robust offline handling:
- Detect connection loss
- Show "Offline" popup with auto-reconnect
- Sync pending messages on reconnect

### 7. **Logout & Session** (Low Priority)
Session management:
- Logout clears SharedPreferences
- Mark session offline on server
- Redirect to login screen

---

## 📁 File Structure

```
lib/
├── screens/
│   ├── onboarding/
│   │   └── onboarding_screen.dart          ✅ Role selection
│   ├── auth/
│   │   └── signup_screen.dart              ✅ Signup with role
│   ├── online_users/
│   │   └── online_users_screen.dart        ✅ NEW
│   ├── chats/
│   │   └── chats_screen.dart               (Chat list)
│   ├── groups/
│   │   └── group_chat_screen.dart          (Chat interface)
│   ├── settings/
│   │   └── settings_screen.dart            (Logout)
│   └── home_screen.dart                    (Tab navigation)
├── services/
│   ├── auth_provider.dart                  ✅ Enhanced
│   ├── websocket_service.dart              (WebSocket)
│   ├── network_service.dart                (API calls)
│   ├── server_discovery_service.dart       ✅ NEW
│   └── ...
├── models/
│   ├── user.dart                           ✅ With role
│   └── ...
└── ...
```

---

## 🔧 Configuration

### Server Discovery Settings
Edit `lib/main.dart` or create `config.dart`:

```dart
class ServerConfig {
  static const String defaultServerIp = '192.168.137.167';
  static const int defaultServerPort = 8083;
  static const bool enableAutodiscovery = true;
  static const Duration autodiscoveryInterval = Duration(minutes: 1);
}
```

### User Roles
Already implemented in `models/user.dart`:
```dart
enum UserRole { student, faculty, admin }
```

---

## 📱 Integration Checklist

- [ ] Update `main.dart` to initialize ServerDiscoveryService
- [ ] Add OnlineUsersScreen to bottom navigation or drawer
- [ ] Update WebSocketService to handle server discovery
- [ ] Add connection status indicator to AppBar
- [ ] Integrate SearchUsersScreen
- [ ] Implement FriendRequestsScreen
- [ ] Add offline handling with popup/notification
- [ ] Test auto-login flow on app restart
- [ ] Test friend request flow
- [ ] Test message sync on reconnect

---

## 🧪 Testing

### Manual Test Cases

1. **Auto-Login Test:**
   - Sign up as student
   - Close app
   - Reopen app → should auto-login

2. **Server Discovery Test:**
   - Configure IP: 192.168.137.167:8083
   - Check if discovered and connected
   - Stop server → should show "Disconnected"
   - Restart server → should auto-reconnect

3. **Friend Request Test:**
   - Open OnlineUsersScreen
   - Click "Add" on another user
   - Check if request appears on recipient
   - Accept and verify in Contacts

4. **Offline Sync Test:**
   - Send message while offline
   - Reconnect → message should sync

---

## 🚨 Known Issues & TODOs

- [ ] Implement actual server endpoints (currently mock data)
- [ ] Add file transfer implementation
- [ ] Setup WebRTC for calls
- [ ] Add database (SQLite/Hive) for local caching
- [ ] Implement message encryption
- [ ] Add call recording (if needed)
- [ ] Implement presence/typing indicators
- [ ] Add group call support

---

## 📞 API Endpoints Expected

The server should implement these WebSocket/HTTP endpoints:

```
WebSocket Events:
- server_discovery_response: {address, port}
- online_users: [{id, name, role, status, ip}]
- friend_request: {fromUserId, message}
- friend_request_accepted: {fromUserId}
- new_message: {fromUserId, content, timestamp}
- file_transfer_request: {fromUserId, fileName, fileSize}

HTTP Endpoints:
POST /search/users?q=query
GET /online-users
POST /friend-request/send
POST /friend-request/accept
POST /file/upload
GET /file/download/:fileId
```

---

## 🎯 Success Criteria

✅ **Core Features Ready:**
- Role-based authentication with local persistence
- Server auto-discovery
- Online users list display
- Friend request system (UI ready, needs integration)

✅ **Next Milestone:**
- Connection status indicator
- User search functionality
- Offline/reconnect handling

---

Generated on: 2025-11-13
Status: Core infrastructure complete, ready for feature integration
