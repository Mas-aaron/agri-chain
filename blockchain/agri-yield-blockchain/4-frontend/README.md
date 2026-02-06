# 4-frontend - AgriYield Flutter Frontend

This directory contains the Flutter-based frontend for the AgriYield blockchain platform, featuring a Farmer Portal, Admin Dashboard, and Mobile App.

## Features

- 🌾 **Farmer Portal**: Tokenize yield predictions, manage assets, and track portfolio value
- 👨‍💼 **Admin Dashboard**: System monitoring and user management
- 📱 **Cross-Platform**: Works on iOS, Android, Web, Windows, and macOS
- 🔗 **Blockchain Integration**: Web3 integration for smart contract interaction
- 📊 **Data Visualization**: Charts and analytics for yield insights
- 🎨 **Beautiful UI**: Material Design 3 with responsive layouts

## Prerequisites

- Flutter 3.0.0 or higher
- Dart 3.0.0 or higher
- Android Studio / Xcode (for iOS) / Visual Studio Code
- Git

## Quick Start

```bash
# Navigate to the frontend directory
cd 4-frontend

# Get dependencies
flutter pub get

# Run the app
flutter run

# Or run on web
flutter run -d chrome

# Or run on Android/iOS
flutter run -d <device-id>
```

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── config/
│   └── theme.dart                 # Theme & styling
├── models/
│   └── yield_asset.dart           # Data models
├── providers/
│   └── app_state.dart             # State management (Provider)
├── routes/
│   └── app_router.dart            # Navigation (GoRouter)
└── screens/
    ├── dashboard/
    │   └── farmer_dashboard.dart   # Farmer portal main screen
    ├── admin/
    │   └── admin_dashboard.dart    # Admin dashboard
    ├── onboarding/
    │   └── splash_screen.dart      # Loading screen
    └── common/
        └── home_screen.dart        # Portal selection screen
```

## Building

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
flutter run -d chrome
```

### Windows
```bash
flutter build windows --release
```

### macOS
```bash
flutter build macos --release
```

## Key Dependencies

- **provider**: State management
- **go_router**: Navigation routing
- **web3dart**: Blockchain integration
- **fl_chart**: Data visualization
- **http/dio**: API communication
- **shared_preferences**: Local storage

See `pubspec.yaml` for complete list.

## API Integration

Update API endpoints in service classes. The app is pre-configured to communicate with backend services for:
- Asset management
- Yield prediction
- Token transactions
- User authentication

## Blockchain Integration

The app uses `web3dart` for smart contract interaction:
- Connect to Ethereum-compatible networks
- Call smart contract functions
- Manage wallet transactions
- Listen to blockchain events

## Testing

```bash
flutter test
```

## Troubleshooting

```bash
# Clean build
flutter clean

# Rebuild dependencies
flutter pub get

# Generate code
flutter pub run build_runner build --delete-conflicting-outputs

# Check Flutter setup
flutter doctor
```

## Documentation

- See [Flutter Docs](https://flutter.dev/docs) for comprehensive guides
- Check [Dart Docs](https://dart.dev/guides) for language reference
- Review `pubspec.yaml` for dependency documentation