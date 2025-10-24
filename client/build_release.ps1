Write-Host "Cleaning project..."
flutter clean

Write-Host "Getting dependencies..."
flutter pub get

Write-Host "Building release APK..."
flutter build apk --release

Write-Host "Build completed. Check the output above for any errors."
