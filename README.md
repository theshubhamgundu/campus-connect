# 🛰️ CampusNet — Internet-Free Campus Communication Network

> **Stay Connected, Even When the Internet Isn’t.**  
> Built entirely with **Dart (Flutter + Socket)** using the **Vibe Coding** environment.

---

## 📘 Overview

**CampusNet** is a private **offline communication network** built for educational campuses where internet access is restricted due to network jammers or institutional policies.  
It enables **students and faculty** to connect, chat, share files, and broadcast announcements **without using the internet** — working entirely over a **local Wi-Fi network (LAN)**.

---

## 🎯 Objectives

- Create an **internet-independent network** for internal campus communication.
- Enable **real-time chat, file sharing, and announcements** via local Wi-Fi.
- Build a **secure and reliable** data exchange system that runs purely on LAN.
- Develop the entire project using **Dart language** inside the **Vibe Coding Tool**.

---

## 🧱 System Architecture

pgsql
Copy code
    ┌──────────────────────────────┐
    │   CampusNet Local Server     │
    │  (Dart Backend / WebSocket)  │
    └────────────┬─────────────────┘
                 │
         [ Local Wi-Fi Router ]
                 │
┌────────────┬────────────┬────────────┐
│ Student A │ Student B │ Faculty C │
│ (APK App) │ (APK App) │ (Admin App)│
└────────────┴────────────┴────────────┘

yaml
Copy code

All communication happens inside the **LAN**, not over the internet.

---

## ⚙️ Tech Stack

| Component | Technology | Purpose |
|------------|-------------|----------|
| **Frontend (Mobile)** | Flutter (Dart) | Android APK for users |
| **Backend Server** | Dart (`dart:io` + WebSocket) | Handles real-time data transfer |
| **Database** | Hive / SQLite (local) | Offline message and file storage |
| **Development Environment** | Vibe Coding Tool | Writing, testing, and debugging Dart code |
| **UI Framework** | Material Design (Flutter) | Simple and intuitive mobile interface |

---

## 🧩 Features

- 💬 **Offline Chat** — Send and receive messages through LAN.
- 📂 **File Sharing** — Share images, PDFs, and notes offline.
- 📢 **Announcements** — Faculty/admin broadcast updates to all users.
- 🧑‍💼 **Role-Based Access** — Separate dashboards for students and faculty.
- 🔔 **Notifications** — Real-time pop-ups within the local network.
- 🔒 **Secure & Private** — No external data transmission or internet use.

---

## 🧠 Working Mechanism

1. The **admin/server device** creates a local Wi-Fi hotspot and runs the Dart backend using **Vibe Coding**.  
2. All users connect to the same Wi-Fi network.  
3. The **CampusNet APK** (built in Flutter) automatically detects and connects to the local server via IP.  
4. Users can chat, share, or view announcements — **completely offline**.  

---

## 🗂️ Folder Structure

CampusNet/
│
├── server/
│ ├── server.dart
│ ├── pubspec.yaml
│ └── utils/
│
├── app/
│ ├── lib/
│ │ ├── main.dart
│ │ ├── screens/
│ │ ├── models/
│ │ └── services/
│ ├── pubspec.yaml
│ └── assets/
│
├── assets/
│ ├── icons/
│ ├── images/
│ └── docs/
│
└── README.md

yaml
Copy code

---

## 🚀 Setup Instructions

### 1️⃣ Requirements
- Vibe Coding Tool (or Dart SDK)
- Android Studio (for Flutter build)
- Local Wi-Fi hotspot or router
- At least one device to act as server (laptop or Raspberry Pi)

### 2️⃣ Installation Steps

#### Backend
```bash
git clone https://github.com/your-username/CampusNet.git
cd CampusNet/server
dart run server.dart
Client App
bash
Copy code
cd CampusNet/app
flutter pub get
flutter run
Connect the phone to the same Wi-Fi network as the server.

🧩 Example Workflow
Server starts → broadcasts “CampusNet” Wi-Fi.

Users join network → open CampusNet app.

Chat messages, files, and announcements travel only within LAN.

All devices remain connected even if internet is jammed.

📚 Future Enhancements
☁️ Cloud Sync: Optional upload when internet is restored.

🧠 Offline AI Assistant: For campus-related FAQs.

🏫 Class & Event Modules: Integrate timetable and event updates.

🔗 Cross-Campus Mesh Networking: Connect multiple CampusNets together.

🧰 Developer Info
Author: Shubham Gundu
Language: Dart
IDE: Vibe Coding Tool
Category: Computer Networks / Offline Communication Systems

🏆 Tagline
“A Smart Campus Network That Works — Even When the Internet Doesn’t.”

📜 License
This project is released under the MIT License.
You’re free to use, modify, and distribute it for educational or research purposes.
