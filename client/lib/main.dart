import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Conditional imports for mobile-only packages
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Hive is not web-compatible, so we'll conditionally import it
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/login_screen.dart';

// Screens
import 'screens/splash_screen.dart';

class _IncomingFile {
  final String fileId;
  final String name;
  final int size;
  final String mime;
  final List<Uint8List> buffer = <Uint8List>[];
  int received = 0;

  _IncomingFile({
    required this.fileId,
    required this.name,
    required this.size,
    required this.mime,
  });

  Uint8List allBytes() {
    final bb = BytesBuilder(copy: false);
    for (final chunk in buffer) {
      bb.add(chunk);
    }
    return bb.takeBytes();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  
  // Initialize platform-specific services
  try {
    // Only initialize Hive on mobile platforms
    if (!kIsWeb) {
      try {
        final appDocumentDir = await getApplicationDocumentsDirectory();
        await Hive.initFlutter(appDocumentDir.path);
        await Hive.openBox('messages');
      } catch (e) {
        debugPrint('Error initializing Hive: $e');
      }
    } else {
      debugPrint('Web platform detected - using web-compatible storage');
    }
    
    // Initialize notifications only on mobile
    if (!kIsWeb) {
      try {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
            
        final InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
        );
        
        final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();
            
        await flutterLocalNotificationsPlugin.initialize(initializationSettings);
      } catch (e) {
        debugPrint('Error initializing notifications: $e');
      }
    }
  } catch (e) {
    debugPrint('Error during initialization: $e');
  }
  
  // Define the purple theme
  final ThemeData purpleTheme = ThemeData(
    primaryColor: Colors.purple[700],
    primaryColorDark: Colors.purple[900],
    primaryColorLight: Colors.purple[100],
    colorScheme: ColorScheme.light(
      primary: Colors.purple[700]!,
      secondary: Colors.purple[500]!,
      onPrimary: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.purple[700],
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.purple[700],
      foregroundColor: Colors.white,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: Colors.purple[700],
      unselectedItemColor: Colors.grey[600],
      showUnselectedLabels: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.purple[700]!),
      ),
    ),
  );

  // Run the app with the purple theme
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: purpleTheme,
      home: const SplashScreen(),
    ),
  );
  // runApp(CampusNetApp(prefs: prefs));
}

class CampusNetApp extends StatelessWidget {
  final SharedPreferences prefs;
  
  const CampusNetApp({Key? key, required this.prefs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = prefs.getBool('darkMode') ?? false;
    final isFirstLaunch = prefs.getBool('onboarding_complete') ?? true;
    
    // WhatsApp color scheme
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF128C7E), // WhatsApp green
      primaryColorDark: const Color(0xFF075E54), // Darker green
      primaryColorLight: const Color(0xFF25D366), // Light green
      scaffoldBackgroundColor: const Color(0xFFE5E5E5), // Light gray background
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF128C7E),
        secondary: Color(0xFF25D366),
        surface: Colors.white,
        background: Color(0xFFE5E5E5),
        onBackground: Colors.black87,
        onSurface: Colors.black87,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF128C7E),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF25D366), // WhatsApp green
        foregroundColor: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.bold),
        displayMedium: const TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold),
        titleLarge: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
        bodyLarge: const TextStyle(color: Colors.black87, fontSize: 14),
        bodyMedium: const TextStyle(color: Colors.black54, fontSize: 14),
        bodySmall: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF075E54), // Darker green
      primaryColorDark: const Color(0xFF128C7E),
      primaryColorLight: const Color(0xFF25D366),
      scaffoldBackgroundColor: const Color(0xFF0F141A), // Dark background
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF075E54),
        secondary: Color(0xFF25D366),
        surface: Color(0xFF1F2C34),
        background: Color(0xFF0F141A),
        onBackground: Colors.white,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F2C34), // Dark header
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF25D366), // WhatsApp green
        foregroundColor: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
        displayMedium: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        titleLarge: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        bodyLarge: const TextStyle(color: Colors.white, fontSize: 14),
        bodyMedium: const TextStyle(color: Colors.white70, fontSize: 14),
        bodySmall: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1F2C34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    return MaterialApp(
      title: 'CampusNet',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: isFirstLaunch ? const OnboardingScreen() : const LoginScreen(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _serverIpCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connected = false;

  final List<Map<String, dynamic>> _feed = [];
  final _toCtrl = TextEditingController();
  final _textCtrl = TextEditingController();

  final _rand = Random();
  static const int _chunkSize = 48 * 1024; // 48 KB
  final Map<String, _IncomingFile> _incoming = {};
  late final FlutterLocalNotificationsPlugin _notifications;
  Box? _feedBox;
  bool _adminMode = false;
  final Map<String, String> _onlineUsers = {}; // userId -> displayName

  @override
  void initState() {
    super.initState();
    _notifications = FlutterLocalNotificationsPlugin();
    _loadFeedFromHive();
  }

  Future<void> _loadFeedFromHive() async {
    final box = Hive.box('feed');
    _feedBox = box;
    final items = box.values.cast<dynamic>().toList();
    final restored = <Map<String, dynamic>>[];
    for (final v in items) {
      if (v is Map) {
        restored.add(Map<String, dynamic>.from(v as Map));
      }
    }
    setState(() {
      _feed
        ..clear()
        ..addAll(restored.reversed); // latest last in box; show latest first in UI
    });
  }

  @override
  void dispose() {
    _serverIpCtrl.dispose();
    _userIdCtrl.dispose();
    _displayNameCtrl.dispose();
    _toCtrl.dispose();
    _textCtrl.dispose();
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  void _connect() {
    final ip = _serverIpCtrl.text.trim();
    if (ip.isEmpty) return;
    final url = Uri(scheme: 'ws', host: ip, port: 8083, path: '/ws').toString();
    final ch = WebSocketChannel.connect(Uri.parse(url));
    setState(() {
      _channel = ch;
      _connected = true;
      _feed.clear();
    });
    _sub = ch.stream.listen((event) {
      try {
        final msg = jsonDecode(event as String) as Map<String, dynamic>;
        _handleIncoming(msg);
      } catch (_) {
        // ignore malformed
      }
    }, onDone: () {
      setState(() {
        _connected = false;
      });
    }, onError: (_) {
      setState(() {
        _connected = false;
      });
    });
  }

  void _appendToFeed(Map<String, dynamic> msg) {
    setState(() {
      _feed.insert(0, msg);
    });
    _feedBox?.add(msg);
  }

  void _handleIncoming(Map<String, dynamic> msg) {
    final type = msg['type']?.toString() ?? '';
    switch (type) {
      case 'fileMeta':
        _onFileMeta(msg);
        break;
      case 'fileChunk':
        _onFileChunk(msg);
        break;
      case 'presence':
        _onPresence(msg);
        break;
      case 'who':
        _onWho(msg);
        break;
      default:
        _appendToFeed(msg);
        if (type == 'announcement') {
          _notify('Announcement', msg['text']?.toString() ?? '');
        }
    }
  }

  void _onPresence(Map<String, dynamic> msg) {
    final event = msg['event']?.toString();
    final userId = msg['userId']?.toString();
    final displayName = msg['displayName']?.toString();
    if (userId == null || userId.isEmpty) return;
    setState(() {
      if (event == 'online') {
        _onlineUsers[userId] = displayName ?? userId;
      } else if (event == 'offline') {
        _onlineUsers.remove(userId);
      }
    });
    _appendToFeed(msg);
  }

  void _onWho(Map<String, dynamic> msg) {
    final users = msg['users'];
    if (users is List) {
      setState(() {
        _onlineUsers.clear();
        for (final u in users) {
          if (u is Map) {
            final id = u['userId']?.toString() ?? '';
            final dn = u['displayName']?.toString() ?? id;
            if (id.isNotEmpty) _onlineUsers[id] = dn;
          }
        }
      });
    }
    _appendToFeed(msg);
  }

  Future<void> _notify(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'campusnet_channel',
      'CampusNet',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _notifications.show(_rand.nextInt(1 << 31), title, body, const NotificationDetails(android: androidDetails));
  }

  void _login() {
    final userId = _userIdCtrl.text.trim();
    final display = _displayNameCtrl.text.trim().isEmpty
        ? userId
        : _displayNameCtrl.text.trim();
    if (userId.isEmpty) return;
    _send({
      'type': 'login',
      'userId': userId,
      'displayName': display,
    });
  }

  void _sendMessage() {
    final to = _toCtrl.text.trim();
    final text = _textCtrl.text.trim();
    if (to.isEmpty || text.isEmpty) return;
    _send({'type': 'message', 'to': to, 'text': text});
    _textCtrl.clear();
  }

  void _sendAnnouncement() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _send({'type': 'announcement', 'text': text});
    _textCtrl.clear();
  }

  void _send(Map<String, dynamic> json) {
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(jsonEncode(json));
  }

  void _refreshUsers() {
    _send({'type': 'who'});
  }

  Future<void> _pickAndSendFile() async {
    if (!_connected) return;
    final to = _toCtrl.text.trim();
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final name = file.name;
    final bytes = file.bytes;
    final size = file.size;
    if (bytes == null) return;
    final fileId = '${DateTime.now().millisecondsSinceEpoch}_${_rand.nextInt(1 << 31)}';
    final mime = 'application/octet-stream';

    // announce meta
    _send({
      'type': 'fileMeta',
      'to': to,
      'fileId': fileId,
      'name': name,
      'size': size,
      'mime': mime,
    });

    // send chunks
    int offset = 0;
    int seq = 0;
    while (offset < bytes.length) {
      final end = (offset + _chunkSize).clamp(0, bytes.length);
      final chunk = bytes.sublist(offset, end);
      _send({
        'type': 'fileChunk',
        'to': to,
        'fileId': fileId,
        'seq': seq,
        'eof': end >= bytes.length,
        'dataBase64': base64Encode(chunk),
      });
      offset = end;
      seq++;
      await Future<void>.delayed(const Duration(milliseconds: 2)); // yield
    }
  }

  void _onFileMeta(Map<String, dynamic> msg) {
    final fileId = msg['fileId']?.toString() ?? '';
    if (fileId.isEmpty) return;
    _incoming[fileId] = _IncomingFile(
      fileId: fileId,
      name: msg['name']?.toString() ?? 'file',
      size: (msg['size'] is int) ? msg['size'] as int : int.tryParse('${msg['size']}') ?? 0,
      mime: msg['mime']?.toString() ?? 'application/octet-stream',
    );
    _appendToFeed(msg);
  }

  Future<void> _onFileChunk(Map<String, dynamic> msg) async {
    final fileId = msg['fileId']?.toString() ?? '';
    if (fileId.isEmpty) return;
    final inc = _incoming[fileId];
    if (inc == null) {
      // Meta might not have arrived yet; create placeholder
      _incoming[fileId] = _IncomingFile(fileId: fileId, name: 'file', size: 0, mime: 'application/octet-stream');
    }
    final dataB64 = msg['dataBase64']?.toString();
    if (dataB64 != null) {
      final bytes = base64Decode(dataB64);
      _incoming[fileId]!.buffer.add(bytes);
      _incoming[fileId]!.received += bytes.length;
    }
    final eof = msg['eof'] == true;
    if (eof) {
      final dir = await getApplicationDocumentsDirectory();
      final fname = _incoming[fileId]!.name;
      final path = '${dir.path}/$fname';
      final file = await File(path).writeAsBytes(_incoming[fileId]!.allBytes());
      final savedMsg = {
        'type': 'fileSaved',
        'fileId': fileId,
        'name': fname,
        'path': file.path,
        'size': _incoming[fileId]!.received,
        'ts': DateTime.now().toIso8601String(),
      };
      _appendToFeed(savedMsg);
      await _notify('File received', fname);
      _incoming.remove(fileId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CampusNet (LAN test)')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Admin mode'),
                Switch(
                  value: _adminMode,
                  onChanged: (v) => setState(() => _adminMode = v),
                ),
              ],
            ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _serverIpCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Server IP (Hotspot host)',
                    hintText: 'e.g. 192.168.43.1',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _connected ? null : _connect,
                child: const Text('Connect'),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _userIdCtrl,
                  decoration: const InputDecoration(labelText: 'Campus ID'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _displayNameCtrl,
                  decoration: const InputDecoration(labelText: 'Display name'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _connected ? _login : null,
                child: const Text('Login'),
              ),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Text('Demo:'),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  _userIdCtrl.text = 'C101';
                  _displayNameCtrl.text = 'Alice';
                },
                child: const Text('Alice (C101)'),
              ),
              TextButton(
                onPressed: () {
                  _userIdCtrl.text = 'C102';
                  _displayNameCtrl.text = 'Bob';
                },
                child: const Text('Bob (C102)'),
              ),
              TextButton(
                onPressed: () {
                  _userIdCtrl.text = 'F201';
                  _displayNameCtrl.text = 'Prof. Rao';
                },
                child: const Text('Faculty (F201)'),
              ),
            ]),
            const Divider(),
            if (_adminMode) ...[
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _connected ? _refreshUsers : null,
                    child: const Text('Refresh Users'),
                  ),
                  const SizedBox(width: 12),
                  Text('Online: ${_onlineUsers.length}')
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView(
                  children: _onlineUsers.entries
                      .map((e) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.person_outline),
                            title: Text(e.value),
                            subtitle: Text(e.key),
                            trailing: IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _connected
                                  ? () {
                                      _toCtrl.text = e.key;
                                    }
                                  : null,
                            ),
                          ))
                      .toList(),
                ),
              ),
              const Divider(),
            ],
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _toCtrl,
                  decoration: const InputDecoration(
                    labelText: 'To (userId or room:roomId)',
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  decoration: const InputDecoration(labelText: 'Text'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _connected ? _sendMessage : null,
                child: const Text('Send'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _connected ? _sendAnnouncement : null,
                child: const Text('Announce'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _connected ? _pickAndSendFile : null,
                child: const Text('Pick File'),
              ),
            ]),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Feed (latest first):'),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                reverse: false,
                itemCount: _feed.length,
                itemBuilder: (context, index) {
                  final m = _feed[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(const JsonEncoder.withIndent('  ').convert(m)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
