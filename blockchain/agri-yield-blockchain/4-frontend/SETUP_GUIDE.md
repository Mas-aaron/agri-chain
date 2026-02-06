# Installation & Setup Guide

## Prerequisites

Before starting, ensure you have the following installed:

- **Flutter SDK**: 3.0.0 or higher
- **Dart SDK**: Included with Flutter
- **Git**: For version control
- **IDE**: VS Code, Android Studio, or IntelliJ IDEA
- **Android SDK** (for Android development)
- **Xcode** (for iOS development on macOS)

## Step 1: Verify Flutter Installation

```bash
# Check Flutter version and installation
flutter doctor

# You should see:
# Doctor summary (to see all details, run flutter doctor -v):
# [✓] Flutter (Channel stable, 3.16.0, ...)
# [✓] Android toolchain - develop for Android devices
# [✓] Xcode - develop for iOS and macOS
# [✓] VS Code (version 1.84.0)
```

## Step 2: Clone the Repository

```bash
# Navigate to your projects directory
cd ~/projects

# Clone the repository
git clone https://github.com/your-repo/agri-yield-blockchain.git

# Navigate to frontend
cd agri-yield-blockchain/4-frontend
```

## Step 3: Get Dependencies

```bash
# Get all Flutter dependencies
flutter pub get

# Upgrade packages to latest compatible versions (optional)
flutter pub upgrade
```

## Step 4: Project Structure Setup

Ensure the following directories exist (they should be created by Flutter):

```
4-frontend/
├── android/          # Android native code
├── ios/              # iOS native code
├── lib/              # Dart source code
├── test/             # Unit tests
├── web/              # Web build output
├── windows/          # Windows native code
├── macos/            # macOS native code
└── linux/            # Linux native code
```

If any are missing, regenerate them:

```bash
# For web support
flutter config --enable-web

# For desktop support (macOS/Windows/Linux)
flutter config --enable-macos
flutter config --enable-windows
flutter config --enable-linux
```

## Step 5: Configure IDE

### VS Code

1. Install Flutter extension by Dart Code
2. Install Dart extension
3. Open `4-frontend` folder in VS Code
4. Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart"
    }
  ]
}
```

### Android Studio / IntelliJ

1. Install Flutter plugin from marketplace
2. Install Dart plugin
3. Open `4-frontend` as a project
4. Let IDE install dependencies

## Step 6: Test Installation

```bash
# Check if everything is working
flutter run

# This will:
# 1. Check Flutter setup
# 2. Compile the app
# 3. Launch on connected device or emulator
```

## Step 7: Platform-Specific Setup

### Android Setup

```bash
# List connected devices
flutter devices

# Or use Android emulator
flutter emulators

# Start emulator
flutter emulators --launch emulator_name

# Run on Android device
flutter run -d android_device_id
```

### iOS Setup (macOS only)

```bash
# Navigate to iOS folder
cd ios

# Install pods
pod install

# Return to project root
cd ..

# Run on iOS
flutter run -d iphone
```

### Web Setup

```bash
# Enable web (if not already enabled)
flutter config --enable-web

# Run on Chrome
flutter run -d chrome

# Run on Firefox
flutter run -d firefox
```

## Step 8: Environment Configuration

Create a `.env` file in the project root:

```env
API_BASE_URL=http://localhost:3000/api
BLOCKCHAIN_RPC_URL=http://localhost:8545
CONTRACT_ADDRESS=0x0000000000000000000000000000000000000000
```

Update `lib/utils/constants.dart` with your configuration values.

## Step 9: Backend Services

Ensure backend services are running:

```bash
# In a separate terminal, start the backend
cd ../3-backend-services
docker-compose up

# Or run individual services
npm start  # for API gateway
python ml_service.py  # for ML integration
```

## Step 10: First Run

```bash
# From the 4-frontend directory
flutter run

# The app should:
# 1. Compile successfully
# 2. Launch on your device/emulator
# 3. Display the AgriYield Farmer Portal
```

## Troubleshooting

### Issue: Flutter not found

```bash
# Add Flutter to PATH
export PATH="$PATH:~/flutter/bin"

# Or on Windows, set system environment variable to:
# C:\path\to\flutter\bin
```

### Issue: Android SDK not found

```bash
# Set Android SDK path
flutter config --android-sdk /path/to/android/sdk

# Verify
flutter doctor
```

### Issue: Xcode issues (macOS)

```bash
# Update Xcode command line tools
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Accept Xcode license
sudo xcode-select --reset
```

### Issue: CocoaPods issues (iOS)

```bash
cd ios
pod repo update
pod install
cd ..
flutter clean
flutter run
```

### Issue: Build cache issues

```bash
# Clean everything
flutter clean

# Remove Flutter artifacts
rm -rf build/ .dart_tool/

# Get dependencies again
flutter pub get

# Rebuild
flutter run
```

## Useful Commands

```bash
# Get Flutter version
flutter --version

# Check setup
flutter doctor -v

# Create new Flutter project
flutter create my_app

# Get dependencies
flutter pub get

# Run app (hot reload enabled)
flutter run

# Run in release mode
flutter run --release

# Build APK
flutter build apk --release

# Build web
flutter build web --release

# Format code
dart format lib/

# Analyze code
flutter analyze

# Run tests
flutter test

# Profile app
flutter run --profile

# Clean build
flutter clean
```

## Next Steps

1. Read [FLUTTER_MIGRATION_GUIDE.md](FLUTTER_MIGRATION_GUIDE.md)
2. Check [README.md](README.md) for feature overview
3. Start the app: `flutter run`
4. Explore the code in `lib/` directory
5. Update API endpoints in `lib/utils/constants.dart`
6. Connect to your blockchain network

## Getting Help

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Documentation](https://dart.dev)
- [StackOverflow - Flutter Tag](https://stackoverflow.com/questions/tagged/flutter)
- [Flutter Community](https://flutter.dev/community)

## Additional Resources

### Learning
- [Flutter Codelab](https://flutter.dev/codelabs)
- [Dart Pad](https://dartpad.dev)
- [YouTube - Flutter Channel](https://www.youtube.com/flutterdev)

### Tools
- [Flutter DevTools](https://flutter.dev/docs/development/tools/devtools)
- [Android Studio Emulator](https://developer.android.com/studio/run/emulator)
- [Xcode Simulator](https://developer.apple.com/simulator/)

### Packages
- [pub.dev](https://pub.dev) - Dart package repository
- [flutter.dev/packages](https://flutter.dev/packages)
