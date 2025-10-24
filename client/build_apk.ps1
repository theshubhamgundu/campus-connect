Write-Host "Cleaning project..."
flutter clean

Write-Host "Getting dependencies..."
flutter pub get

Write-Host "Building release APK..."
flutter build apk --release --no-shrink

Write-Host "Build completed. APK should be available in: build/app/outputs/flutter-apk/app-release.apk"
