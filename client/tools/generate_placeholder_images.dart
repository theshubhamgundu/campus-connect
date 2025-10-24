import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

void main() async {
  // Create a temporary directory for the generated images
  final Directory assetsDir = Directory('assets/images');
  if (!await assetsDir.exists()) {
    await assetsDir.create(recursive: true);
  }

  // Create a list of image configurations
  final List<Map<String, dynamic>> images = [
    {
      'name': 'app_logo.png',
      'text': 'App Logo',
      'color': Colors.blue,
      'size': Size(512, 512),
    },
    {
      'name': 'google_logo.png',
      'text': 'G',
      'color': Colors.red,
      'size': Size(256, 256),
    },
    {
      'name': 'avatar1.png',
      'text': 'A1',
      'color': Colors.green,
      'size': Size(200, 200),
    },
    {
      'name': 'avatar2.png',
      'text': 'A2',
      'color': Colors.purple,
      'size': Size(200, 200),
    },
  ];

  // Generate each image
  for (final image in images) {
    await generatePlaceholderImage(
      path.join(assetsDir.path, image['name']),
      image['text'],
      image['color'],
      image['size'],
    );
    print('Generated: ${image['name']}');
  }

  print('\nAll placeholder images have been generated in: ${assetsDir.path}');
  print('\nMake sure to add these assets to your pubspec.yaml file:');
  print('''
  # In pubspec.yaml, add:
  flutter:
    assets:
      - assets/images/
  ''');
}

Future<void> generatePlaceholderImage(
  String filePath,
  String text,
  Color color,
  Size size,
) async {
  final PictureRecorder recorder = PictureRecorder();
  final Canvas canvas = Canvas(
    recorder,
    Rect.fromPoints(Offset.zero, Offset(size.width, size.height)),
  );

  // Draw background
  final Paint backgroundPaint = Paint()..color = color.withOpacity(0.2);
  canvas.drawRect(
    Rect.fromPoints(Offset.zero, Offset(size.width, size.height)),
    backgroundPaint,
  );

  // Draw border
  final Paint borderPaint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0;
  canvas.drawRect(
    Rect.fromPoints(
      Offset(2, 2),
      Offset(size.width - 2, size.height - 2),
    ),
    borderPaint,
  );

  // Draw text
  final textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size.shortestSide * 0.3,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  textPainter.layout(
    minWidth: 0,
    maxWidth: size.width,
  );

  final offset = Offset(
    (size.width - textPainter.width) / 2,
    (size.height - textPainter.height) / 2,
  );

  textPainter.paint(canvas, offset);

  // Convert to image and save
  final picture = recorder.endRecording();
  final img = await picture.toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final buffer = byteData!.buffer.asUint8List();
  await File(filePath).writeAsBytes(buffer);
}
