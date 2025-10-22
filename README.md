# 🛰️ CampusNet — Internet-Free Campus Communication Network

> **Stay Connected, Even When the Internet Isn't.**  
> Built entirely with **Dart (Flutter + Socket)** using the **Vibe Coding** environment.

---

## 📘 Overview

**CampusNet** is a private **offline communication network** built for educational campuses where internet access is restricted due to network jammers or institutional policies.

It enables **students and faculty** to connect, chat, share files, and broadcast announcements **without using the internet** — working entirely over a **local Wi-Fi network (LAN)**.

### 🎯 Problem Statement

Many educational institutions deploy internet jammers during exams or restrict internet access for security reasons. This creates communication gaps between students, faculty, and administration. CampusNet solves this by creating a **completely offline, LAN-based network** that functions independently.

---

## ✨ Features

### Core Features
- 💬 **Offline Chat** — Real-time messaging through local Wi-Fi network
- 📂 **File Sharing** — Share images, PDFs, documents, and notes offline
- 📢 **Announcements** — Faculty/admin broadcast updates to all connected users
- 🔔 **Push Notifications** — Real-time alerts within the local network
- 👥 **User Management** — Registration and authentication without internet

### Advanced Features
- 🧑💼 **Role-Based Access Control** — Separate dashboards for students, faculty, and admin
- 💾 **Offline Storage** — Messages and files cached locally using Hive database
- 🔒 **End-to-End Security** — No external data transmission, fully private
- 📊 **Network Statistics** — Monitor active users and network health
- 🔍 **Search & Filter** — Find messages and files quickly
- 🎨 **Clean UI** — Intuitive Material Design interface

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   LOCAL Wi-Fi NETWORK                        │
│                                                              │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │ Server Host  │◄────────┤   Wi-Fi      │                 │
│  │ (Dart)       │         │   Router/    │                 │
│  │ Port: 8080   │         │   Hotspot    │                 │
│  └──────┬───────┘         └──────┬───────┘                 │
│         │                        │                          │
│         │   WebSocket Protocol   │                          │
│         │   (ws://192.168.x.x)   │                          │
│         │                        │                          │
│    ┌────▼────┐  ┌────────┐  ┌───▼─────┐  ┌─────────┐     │
│    │ Student │  │ Student│  │ Faculty │  │  Admin  │     │
│    │  App    │  │  App   │  │   App   │  │   App   │     │
│    └─────────┘  └────────┘  └─────────┘  └─────────┘     │
└─────────────────────────────────────────────────────────────┘
```

---

## ⚙️ Tech Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Frontend (Mobile)** | Flutter (Dart) | Cross-platform Android/iOS app |
| **Backend Server** | Dart (`dart:io` + WebSocket) | Handles real-time data transfer |
| **Database** | Hive (offline NoSQL) | Local message and file storage |
| **Networking** | WebSocket Protocol | Real-time bidirectional communication |
| **Development** | Vibe Coding Tool | Writing, testing, and debugging |
| **UI Framework** | Material Design 3 | Modern, intuitive interface |

---

## 🚀 Getting Started

### Prerequisites

- **Dart SDK** 3.0+ ([Install](https://dart.dev/get-dart))
- **Flutter SDK** 3.16+ ([Install](https://flutter.dev/docs/get-started/install))
- **Android Studio** (for APK builds)
- **Local Wi-Fi Network** (router or mobile hotspot)
- **Vibe Coding Tool** (optional, for development)

### Installation

#### 1️⃣ Clone the Repository

```bash
git clone https://github.com/shubhamgundu/CampusNet.git
cd CampusNet
```

#### 2️⃣ Setup Server

```bash
cd server
dart pub get
dart run bin/server.dart
```

**Expected Output:**
```
🛰️  CampusNet Server Started
📡 Listening on: 192.168.1.100:8080
🔗 Network: LOCAL Wi-Fi ONLY
──────────────────────────────────────────────────
```

#### 3️⃣ Setup Client App

```bash
cd ../app
flutter pub get
flutter run
```

Or build APK:
```bash
flutter build apk --release
```

The APK will be generated at: `app/build/app/outputs/flutter-apk/app-release.apk`

---

## 📱 Usage Guide

### For Server Administrator

1. **Start the Server**
   - Connect laptop/PC to Wi-Fi router
   - Run `dart run bin/server.dart`
   - Note the IP address displayed (e.g., 192.168.1.100)

2. **Configure Network**
   - Ensure all devices connect to the same Wi-Fi network
   - Share the server IP with users

### For Users (Students/Faculty)

1. **Install CampusNet APK** on your Android device
2. **Connect to Campus Wi-Fi** network
3. **Open CampusNet App**
4. **Enter Server IP** (e.g., 192.168.1.100:8080)
5. **Register/Login** with credentials
6. **Start Chatting** and sharing files!

---

## 🧩 Project Structure

```
CampusNet/
├── server/                     # Backend Dart server
│   ├── bin/
│   │   └── server.dart        # Main server entry point
│   ├── lib/
│   │   ├── models/            # Data models
│   │   │   ├── message.dart
│   │   │   ├── user.dart
│   │   │   └── announcement.dart
│   │   ├── handlers/          # Request handlers
│   │   │   ├── chat_handler.dart
│   │   │   ├── file_handler.dart
│   │   │   └── auth_handler.dart
│   │   └── utils/             # Utilities
│   │       ├── logger.dart
│   │       └── crypto.dart
│   └── pubspec.yaml
│
└── app/                        # Flutter client app
    ├── lib/
    │   ├── main.dart          # App entry point
    │   ├── screens/           # UI screens
    │   │   ├── splash_screen.dart
    │   │   ├── login_screen.dart
    │   │   ├── chat_screen.dart
    │   │   ├── announcements_screen.dart
    │   │   └── file_share_screen.dart
    │   ├── services/          # Business logic
    │   │   ├── websocket_service.dart
    │   │   ├── storage_service.dart
    │   │   └── notification_service.dart
    │   ├── models/            # Shared data models
    │   └── widgets/           # Reusable UI components
    │       ├── chat_bubble.dart
    │       └── file_card.dart
    └── pubspec.yaml
```

---

## 🔧 Configuration

### Server Configuration (`server/config.dart`)

```dart
const String SERVER_HOST = '0.0.0.0';  // Listen on all interfaces
const int SERVER_PORT = 8080;
const int MAX_CLIENTS = 100;
const int MAX_FILE_SIZE = 10 * 1024 * 1024;  // 10MB
```

### Client Configuration (`app/lib/config.dart`)

```dart
const String DEFAULT_SERVER_IP = '192.168.1.100';
const int DEFAULT_SERVER_PORT = 8080;
const int RECONNECT_INTERVAL = 5;  // seconds
```

---

## 🧪 Testing

### Unit Tests

```bash
# Test server
cd server
dart test

# Test app
cd app
flutter test
```

### Integration Testing

1. Start server on one device
2. Connect multiple clients
3. Test chat, file sharing, and announcements
4. Verify offline functionality

---

## 🔒 Security Features

- **No Internet Dependency** — All data stays within LAN
- **Local Authentication** — User credentials stored locally
- **Encrypted Connections** — WebSocket Secure (WSS) optional
- **Role-Based Access** — Different permissions for users
- **Private Network** — No external data leakage

---

## 📈 Future Enhancements

- [ ] ☁️ **Cloud Sync** — Optional upload when internet restored
- [ ] 🧠 **Offline AI Assistant** — Campus FAQs and help
- [ ] 🏫 **Timetable Integration** — Class schedules and events
- [ ] 📊 **Analytics Dashboard** — Usage statistics for admin
- [ ] 🔗 **Mesh Networking** — Connect multiple CampusNets
- [ ] 🎥 **Video Calls** — WebRTC-based video chat
- [ ] 📍 **Location Sharing** — Find friends on campus map
- [ ] 🌐 **Web Interface** — Browser-based access

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines

- Follow Dart style guide
- Write unit tests for new features
- Update documentation
- Test on multiple devices

---

## 🐛 Troubleshooting

### Server Won't Start
- Check if port 8080 is already in use
- Verify Dart SDK installation: `dart --version`
- Check firewall settings

### Clients Can't Connect
- Ensure all devices on same Wi-Fi network
- Verify server IP address is correct
- Check if server is running: `curl http://192.168.1.100:8080/status`

### File Sharing Fails
- Check file size (must be < 10MB)
- Verify storage permissions on device
- Ensure stable Wi-Fi connection

---

## 📚 Documentation

- [API Documentation](docs/API.md)
- [User Guide](docs/USER_GUIDE.md)
- [Developer Guide](docs/DEVELOPER_GUIDE.md)
- [Architecture Overview](docs/ARCHITECTURE.md)

---

## 👨‍💻 Author

**Shubham Gundu**
- GitHub: [@shubhamgundu](https://github.com/theshubhamgundu)
- Email: shubsss29@gmail.com
- LinkedIn: [linkedin.com/in/shubhamgundu](https://linkedin.com/in/shubhamgundu)

---

## 📜 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

You're free to use, modify, and distribute it for educational or research purposes.

---

## 🙏 Acknowledgments

- Built with ❤️ using Dart and Flutter
- Inspired by offline communication needs in educational institutions
- Thanks to the Dart and Flutter communities

---

## 🏆 Tagline

**"A Smart Campus Network That Works — Even When the Internet Doesn't."**

---

---

## 🌟 Star History

If you find this project useful, please consider giving it a ⭐ on GitHub!

---

**Made with 💻 and ☕ for better campus communication**
