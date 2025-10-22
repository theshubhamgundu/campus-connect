import 'dart:io';
import 'dart:async';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

Future<void> main() async {
  print('Generating launcher icons...');
  
  // Create output directories if they don't exist
  await Directory('android/app/src/main/res').create(recursive: true);
  await Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset').create(recursive: true);
  
  // Define icon sizes for different platforms
  final androidIcons = [
    {'size': 48, 'dir': 'mipmap-mdpi'},
    {'size': 72, 'dir': 'mipmap-hdpi'},
    {'size': 96, 'dir': 'mipmap-xhdpi'},
    {'size': 144, 'dir': 'mipmap-xxhdpi'},
    {'size': 192, 'dir': 'mipmap-xxxhdpi'},
  ];
  
  final iosIcons = [
    {'size': 20, 'scale': 2, 'filename': 'Icon-App-40x40@2x.png'},
    {'size': 20, 'scale': 3, 'filename': 'Icon-App-60x60@3x.png'},
    {'size': 29, 'scale': 2, 'filename': 'Icon-Small@2x.png'},
    {'size': 29, 'scale': 3, 'filename': 'Icon-Small@3x.png'},
    {'size': 40, 'scale': 2, 'filename': 'Icon-40@2x.png'},
    {'size': 40, 'scale': 3, 'filename': 'Icon-60@3x.png'},
    {'size': 60, 'scale': 2, 'filename': 'Icon-60@2x.png'},
    {'size': 76, 'scale': 1, 'filename': 'Icon-76.png'},
    {'size': 76, 'scale': 2, 'filename': 'Icon-76@2x.png'},
    {'size': 83.5, 'scale': 2, 'filename': 'Icon-83.5@2x.png'},
    {'size': 1024, 'scale': 1, 'filename': 'iTunesArtwork@2x.png'},
  ];
  
  // Process the source image
  final sourceImage = File('assets/images/app_logo.png');
  if (!await sourceImage.exists()) {
    print('Error: Source image not found at ${sourceImage.path}');
    return;
  }
  
  final image = img.decodeImage(await sourceImage.readAsBytes());
  if (image == null) {
    print('Error: Could not decode the source image');
    return;
  }
  
  // Generate Android icons
  for (var icon in androidIcons) {
    final dir = 'android/app/src/main/res/${icon['dir']}';
    await Directory(dir).create(recursive: true);
    
    final resized = img.copyResize(
      image!,
      width: icon['size'] as int,
      height: icon['size'] as int,
    );
    
    final outputFile = File('$dir/ic_launcher.png');
    await outputFile.writeAsBytes(img.encodePng(resized));
    print('Generated: ${outputFile.path}');
  }
  
  // Generate iOS icons
  for (var icon in iosIcons) {
    final size = (icon['size'] as double) * (icon['scale'] as int);
    final resized = img.copyResize(
      image!,
      width: size.toInt(),
      height: size.toInt(),
    );
    
    final outputFile = File('ios/Runner/Assets.xcassets/AppIcon.appiconset/${icon['filename']}');
    await outputFile.writeAsBytes(img.encodePng(resized));
    print('Generated: ${outputFile.path}');
  }
  
  // Create iOS Contents.json
  final contentsJson = '''
  {
    "images" : [
      {
        "size" : "20x20",
        "idiom" : "iphone",
        "filename" : "Icon-App-40x40@2x.png",
        "scale" : "2x"
      },
      {
        "size" : "20x20",
        "idiom" : "iphone",
        "filename" : "Icon-60@3x.png",
        "scale" : "3x"
      },
      {
        "size" : "29x29",
        "idiom" : "iphone",
        "filename" : "Icon-Small@2x.png",
        "scale" : "2x"
      },
      {
        "size" : "29x29",
        "idiom" : "iphone",
        "filename" : "Icon-Small@3x.png",
        "scale" : "3x"
      },
      {
        "size" : "40x40",
        "idiom" : "iphone",
        "filename" : "Icon-40@2x.png",
        "scale" : "2x"
      },
      {
        "size" : "40x40",
        "idiom" : "iphone",
        "filename" : "Icon-60@3x.png",
        "scale" : "3x"
      },
      {
        "size" : "60x60",
        "idiom" : "iphone",
        "filename" : "Icon-60@2x.png",
        "scale" : "2x"
      },
      {
        "size" : "60x60",
        "idiom" : "iphone",
        "filename" : "Icon-60@3x.png",
        "scale" : "3x"
      },
      {
        "size" : "20x20",
        "idiom" : "ipad",
        "filename" : "Icon-40@2x.png",
        "scale" : "1x"
      },
      {
        "size" : "20x20",
        "idiom" : "ipad",
        "filename" : "Icon-40@2x.png",
        "scale" : "2x"
      },
      {
        "size" : "29x29",
        "idiom" : "ipad",
        "filename" : "Icon-Small@2x.png",
        "scale" : "1x"
      },
      {
        "size" : "29x29",
        "idiom" : "ipad",
        "filename" : "Icon-Small@2x.png",
        "scale" : "2x"
      },
      {
        "size" : "40x40",
        "idiom" : "ipad",
        "filename" : "Icon-40@2x.png",
        "scale" : "1x"
      },
      {
        "size" : "40x40",
        "idiom" : "ipad",
        "filename" : "Icon-40@2x.png",
        "scale" : "2x"
      },
      {
        "size" : "76x76",
        "idiom" : "ipad",
        "filename" : "Icon-76.png",
        "scale" : "1x"
      },
      {
        "size" : "76x76",
        "idiom" : "ipad",
        "filename" : "Icon-76@2x.png",
        "scale" : "2x"
      },
      {
        "size" : "83.5x83.5",
        "idiom" : "ipad",
        "filename" : "Icon-83.5@2x.png",
        "scale" : "2x"
      },
      {
        "size" : "1024x1024",
        "idiom" : "ios-marketing",
        "filename" : "iTunesArtwork@2x.png",
        "scale" : "1x"
      }
    ],
    "info" : {
      "version" : 1,
      "author" : "xcode"
    }
  }
  ''';
  
  final contentsFile = File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json');
  await contentsFile.writeAsString(contentsJson);
  
  print('Launcher icons generated successfully!');
}
