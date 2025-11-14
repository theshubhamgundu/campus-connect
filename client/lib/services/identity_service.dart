import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';

class IdentityService {
  static const String profileBoxName = 'profile';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(profileBoxName)) {
      await Hive.openBox(profileBoxName);
    }
  }

  static Box get _box => Hive.box(profileBoxName);

  static String? get displayName => _box.get('displayName') as String?;
  static Future<void> setDisplayName(String name) async => _box.put('displayName', name);

  static String? get avatarPath => _box.get('avatarPath') as String?;
  static Future<void> setAvatarPath(String path) async => _box.put('avatarPath', path);

  static Map<String, dynamic> identityPayload({required String userId}) {
    final name = displayName ?? userId;
    final avatar = avatarPath;
    return {
      'userId': userId,
      'displayName': name,
      if (avatar != null && avatar.isNotEmpty) 'avatarPath': avatar,
    };
  }
}
