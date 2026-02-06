# Flutter App Architecture

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Flutter Application                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │              User Interface Layer (Screens)             │  │
│  ├─────────────────────────────────────────────────────────┤  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │
│  │  │   Farmer     │  │   Admin      │  │   Common     │  │  │
│  │  │  Dashboard   │  │  Dashboard   │  │   Screens    │  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │  │
│  │    (Main UI)       (Management)      (Home, Splash)    │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓↑                                     │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │           State Management Layer (Provider)            │  │
│  ├─────────────────────────────────────────────────────────┤  │
│  │         ┌──────────────────────────────────┐            │  │
│  │         │   AppStateProvider               │            │  │
│  │         │  - User state                    │            │  │
│  │         │  - App theme                     │            │  │
│  │         │  - Connection state              │            │  │
│  │         └──────────────────────────────────┘            │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓↑                                     │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │            Business Logic Layer (Services)             │  │
│  ├─────────────────────────────────────────────────────────┤  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │
│  │  │   ApiService │  │Web3Service   │  │StorageService│  │  │
│  │  │              │  │              │  │              │  │  │
│  │  │ CRUD ops     │  │Contract calls│  │Local storage │  │  │
│  │  │ HTTP calls   │  │Wallet mgmt   │  │Preferences   │  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓↑                                     │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │              Data Layer (Models)                        │  │
│  ├─────────────────────────────────────────────────────────┤  │
│  │  ┌──────────────────────────────────────────┐           │  │
│  │  │   YieldAsset                             │           │  │
│  │  │   - assetId, tokenId                     │           │  │
│  │  │   - cropType, season                     │           │  │
│  │  │   - predictedYield, confidence           │           │  │
│  │  │   - tokenAmount, currentValue            │           │  │
│  │  └──────────────────────────────────────────┘           │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓↑                                     │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │              External Integrations                      │  │
│  ├─────────────────────────────────────────────────────────┤  │
│  │  ┌────────────────┐    ┌───────────────────┐            │  │
│  │  │ Backend API    │    │ Blockchain/Web3   │            │  │
│  │  │ (REST)         │    │ (Smart Contracts) │            │  │
│  │  └────────────────┘    └───────────────────┘            │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
User Interaction (Tap Button)
            ↓
    Screen Widget
            ↓
  Event/Action Handler
            ↓
  Service Method (API/Web3)
            ↓
  Provider State Update
            ↓
  Screen Rebuild (FutureBuilder/BlocBuilder)
            ↓
  Display Updated UI
```

## Directory Tree with Responsibilities

```
lib/
├── main.dart
│   └── App initialization, theme, provider setup
│
├── config/
│   └── theme.dart
│       └── Material Design 3 theme configuration
│
├── models/
│   └── yield_asset.dart
│       └── Data models with JSON serialization
│
├── providers/
│   └── app_state.dart
│       └── App-wide state management (Provider)
│
├── routes/
│   └── app_router.dart
│       └── Navigation routes and configuration
│
├── services/
│   ├── api_service.dart
│   │   └── Backend API communication (CRUD)
│   ├── web3_service.dart
│   │   └── Blockchain/Web3 integration
│   └── storage_service.dart (future)
│       └── Local data persistence
│
├── screens/
│   ├── admin/
│   │   └── admin_dashboard.dart
│   │       └── Admin portal screens
│   ├── dashboard/
│   │   └── farmer_dashboard.dart
│   │       └── Main farmer portal screen
│   ├── onboarding/
│   │   └── splash_screen.dart
│   │       └── App initialization screen
│   └── common/
│       └── home_screen.dart
│           └── Portal selection screen
│
├── widgets/ (future)
│   ├── stat_card.dart
│   ├── asset_card.dart
│   └── shared components...
│
└── utils/
    ├── constants.dart
    │   └── App configuration and constants
    ├── formatters.dart
    │   └── Date, currency, number formatting
    └── error_handler.dart (future)
        └── Error handling utilities
```

## Component Hierarchy

```
MaterialApp
├── AppTheme
│   ├── Light Theme
│   │   ├── Colors
│   │   ├── Typography
│   │   └── Component Styles
│   └── Dark Theme
│       ├── Colors
│       ├── Typography
│       └── Component Styles
│
├── MultiProvider
│   └── AppStateProvider
│
└── GoRouter
    ├── SplashScreen (/)
    │   └── HomeScreen
    │       ├── FarmerDashboard (/farmer-dashboard)
    │       └── AdminDashboard (/admin-dashboard)
    │
    └── Home Selection UI
```

## State Management Flow

```
User Action
    ↓
Widget calls Provider method
    ↓
Provider calls Service
    ↓
Service makes API/Web3 call
    ↓
Provider updates internal state
    ↓
Provider notifyListeners()
    ↓
Widgets listening to Provider rebuild
    ↓
Updated UI displayed
```

## API Communication Pattern

```
┌─────────────┐
│   Widget    │
└──────┬──────┘
       │ Calls ApiService method
       ↓
┌──────────────────┐
│   ApiService     │
│  - Builds URL    │
│  - Sets headers  │
│  - Sends request │
└──────┬───────────┘
       │
       ↓
┌──────────────────┐
│   Backend API    │
│   (REST)         │
└──────┬───────────┘
       │
       ↓
┌──────────────────────┐
│   Response Handler   │
│  - Check status code │
│  - Parse JSON        │
│  - Create models     │
└──────┬───────────────┘
       │
       ↓
┌──────────────────┐
│   Provider       │
│   Update state   │
│   Notify UI      │
└──────┬───────────┘
       │
       ↓
┌──────────────────┐
│   Widget rebuild │
│   Display data   │
└──────────────────┘
```

## Blockchain Integration Pattern

```
┌─────────────────┐
│   User Action   │ (E.g., Transfer Token)
└────────┬────────┘
         │
         ↓
┌─────────────────────┐
│   Screen Widget     │
└────────┬────────────┘
         │
         ↓
┌─────────────────────────────────┐
│   Web3Service                   │
│  - Load contract ABI            │
│  - Create contract instance     │
│  - Prepare transaction params   │
└────────┬────────────────────────┘
         │
         ↓
┌─────────────────────────────────┐
│   Web3Client                    │
│  - Sign transaction             │
│  - Send to blockchain           │
│  - Get transaction receipt      │
└────────┬────────────────────────┘
         │
         ↓
┌─────────────────────────────────┐
│   Blockchain Network            │
│  - Validate transaction         │
│  - Execute contract function    │
│  - Update state                 │
│  - Emit events                  │
└────────┬────────────────────────┘
         │
         ↓
┌─────────────────────────────────┐
│   Provider Updates State        │
│  - Stores transaction hash      │
│  - Updates UI                   │
│  - Notifies user of success     │
└────────┬────────────────────────┘
         │
         ↓
┌─────────────────────────────────┐
│   Widget Displays Result        │
│  - Shows confirmation           │
│  - Updates asset values         │
│  - Logs transaction             │
└─────────────────────────────────┘
```

## Error Handling Flow

```
┌──────────────────┐
│   API/Web3 Call  │
└────────┬─────────┘
         │
    ┌────┴────┐
    │          │
   YES        NO
    │          │
    │      ┌──────────────┐
    │      │   Error      │
    │      │   Occurred   │
    │      └──────┬───────┘
    │             │
    │      ┌──────▼──────────────┐
    │      │ Error Handler       │
    │      │ - Parse error       │
    │      │ - Get user message  │
    │      │ - Log error         │
    │      └──────┬──────────────┘
    │             │
    │      ┌──────▼──────────────┐
    │      │ Provider Updates    │
    │      │ - Sets error state  │
    │      │ - Notifies listeners│
    │      └──────┬──────────────┘
    │             │
    │      ┌──────▼──────────────┐
    │      │ Widget Shows        │
    │      │ - Error message     │
    │      │ - Retry button      │
    │      │ - Back navigation   │
    │      └─────────────────────┘
    │
    └─────────────────────────┐
                              │
                   ┌──────────▼────────┐
                   │ Provider Success  │
                   │ - Updates models  │
                   │ - Clears errors   │
                   │ - Notifies UI     │
                   └──────────┬────────┘
                              │
                   ┌──────────▼────────┐
                   │ Widget Updates    │
                   │ - Shows data      │
                   │ - Hides errors    │
                   │ - Enables actions │
                   └───────────────────┘
```

## Platform Support Matrix

```
                 Web    Android   iOS    Windows  macOS  Linux
UI Framework     ✅       ✅      ✅       ✅      ✅     ✅
API Integration  ✅       ✅      ✅       ✅      ✅     ✅
Blockchain       ✅       ✅      ✅       ✅      ✅     ✅
Local Storage    ✅       ✅      ✅       ✅      ✅     ✅
File Access      ✅       ✅      ✅       ✅      ✅     ✅
Native Calls     -        ✅      ✅       ✅      ✅     ✅
Notifications    -        ✅      ✅       ✅      ✅     ✅
```

## Deployment Pipeline

```
┌───────────────────────────────┐
│   Development                 │
│   - flutter run               │
│   - Hot reload enabled        │
│   - Local testing             │
└───────────────┬───────────────┘
                │
┌───────────────▼───────────────┐
│   Testing                     │
│   - Unit tests                │
│   - Widget tests              │
│   - Integration tests         │
│   - Manual QA                 │
└───────────────┬───────────────┘
                │
┌───────────────▼───────────────────────────────────┐
│   Build & Release                                 │
├──────────────────────────────────────────────────┤
│  Android          │ iOS          │ Web           │
│  build apk        │ build ios    │ build web     │
│  build appbundle  │              │               │
└───┬──────────────┬┘────────────┬─┴──────────────┘
    │              │             │
┌───▼──────────────▼────────────▼────────┐
│   Store Submission                    │
│   - Google Play Store                 │
│   - Apple App Store                   │
│   - Firebase Hosting / CDN            │
└───┬─────────────────────────────────────┘
    │
┌───▼─────────────────────────┐
│   Production                │
│   - Monitor crashes         │
│   - Track analytics         │
│   - User feedback           │
└─────────────────────────────┘
```

---

This architecture is designed to be:
- **Scalable**: Easy to add new screens and features
- **Maintainable**: Clear separation of concerns
- **Testable**: Mockable services and providers
- **Type-safe**: Dart's strong type system
- **Cross-platform**: Single codebase for all platforms
