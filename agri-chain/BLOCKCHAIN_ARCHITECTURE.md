# Blockchain Feature - Architecture & Design Decisions

## Overview

This document explains the architectural decisions and design patterns used to integrate the blockchain yield tokenization feature into the main AgriChain app.

---

## Design Principles

### 1. **Modularity**
The blockchain feature is completely self-contained in `lib/features/blockchain/` directory:
- Can be developed independently
- Easy to enable/disable
- Can be replaced without affecting other features
- Clear boundaries between feature and core app

### 2. **Feature-Driven Architecture**
```
lib/
├── core/              (Shared utilities, not in this version)
├── features/          (Feature modules)
│   └── blockchain/
│       ├── config/    (Configuration & constants)
│       ├── models/    (Data models)
│       ├── providers/ (State management)
│       ├── services/  (API & business logic)
│       ├── screens/   (UI screens)
│       └── widgets/   (Reusable components)
└── ...
```

### 3. **Clean Architecture**
```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│  (Widgets, Screens, ChangeNotifiers)   │
└──────────────────┬──────────────────────┘
                   │ (depends on)
┌──────────────────▼──────────────────────┐
│           Domain Layer                  │
│  (Models, Interfaces, Business Logic)  │
└──────────────────┬──────────────────────┘
                   │ (depends on)
┌──────────────────▼──────────────────────┐
│           Data Layer                    │
│  (Services, API, Storage)              │
└─────────────────────────────────────────┘
```

### 4. **Inversion of Control (IoC)**
- Dependencies injected via constructor
- Services accept `http.Client` for testing
- Providers accept `BlockchainApiService` for mocking

---

## Directory Structure & Responsibilities

### `config/`
**Purpose**: Configuration constants and enums  
**File**: `blockchain_config.dart`

**Contains**:
- API endpoints
- Blockchain parameters
- Feature flags
- Cache durations
- Crop types and status enums

**Why**: Centralized configuration for easy changes

```dart
// Example
class BlockchainConfig {
  static const String apiBaseUrl = 'http://localhost:3000/api';
  // Easy to change for different environments
}
```

### `models/`
**Purpose**: Data models with serialization  
**File**: `yield_asset.dart`

**Contains**:
- YieldAsset class
- JSON serialization (fromJson/toJson)
- Model methods (copyWith)

**Why**: Type-safe data handling, easy serialization

```dart
// Supports:
final asset = YieldAsset.fromJson(jsonResponse);
final json = asset.toJson();
final updated = asset.copyWith(status: 'VERIFIED');
```

### `services/`
**Purpose**: Business logic and external integrations  
**Files**:
- `blockchain_api_service.dart` - REST API client
- `web3_service.dart` - Blockchain interactions (future)

**Responsibilities**:
- HTTP communication
- Error handling
- Response parsing
- Request building

**Why**: Separation of concerns, testable, reusable

```dart
// Services are injectable
final apiService = BlockchainApiService(httpClient: mockClient);
```

### `providers/`
**Purpose**: State management  
**File**: `blockchain_provider.dart`

**Extends**: `ChangeNotifier`
**Manages**:
- Asset list state
- Loading state
- Error messages
- Portfolio data
- User selection

**Why**: Provider pattern for easy integration, testable state

```dart
// Reactive updates
Consumer<BlockchainProvider>(
  builder: (context, provider, _) {
    return Text('${provider.assets.length} assets');
  },
)
```

### `screens/`
**Purpose**: Main UI screens  
**Files**:
- `blockchain_tab.dart` - Yield assets list/browser
- `yield_details_screen.dart` - Individual asset details

**Features**:
- Pull-to-refresh
- Error handling
- Loading states
- Empty state
- Navigation

### `widgets/`
**Purpose**: Reusable UI components  
**Files**:
- `asset_card.dart` - Asset list item
- `portfolio_summary.dart` - Portfolio overview
- `status_badge.dart` - Status indicator
- `asset_details_card.dart` - Details table

**Design**:
- Stateless (where possible)
- Single responsibility
- Composable

---

## Data Flow

### Loading Assets from API

```
User navigates to Yield tab
        ↓
BlockchainTab.initState() called
        ↓
BlockchainProvider.initialize('FARMER_001')
        ↓
BlockchainApiService.getYieldAssets('FARMER_001')
        ↓
HTTP GET /api/assets?farmerId=FARMER_001
        ↓
API returns JSON array
        ↓
Parse to List<YieldAsset>
        ↓
Update BlockchainProvider state
        ↓
notifyListeners() called
        ↓
UI rebuilds via Consumer<BlockchainProvider>
        ↓
AssetCard widgets rendered
```

### User Interaction Flow

```
User taps on asset card
        ↓
onTap(){
  Navigator.push(
    YieldDetailsScreen(asset: asset)
  )
}
        ↓
YieldDetailsScreen renders with asset data
        ↓
User taps "Trade Tokens"
        ↓
BlockchainProvider.executeTrade(...)
        ↓
Call BlockchainApiService
        ↓
API processes trade
        ↓
BlockchainProvider.refresh()
        ↓
UI updates with new data
```

---

## State Management Strategy

### Provider as ChangeNotifier
```dart
class BlockchainProvider extends ChangeNotifier {
  // 1. Private state variables
  List<YieldAsset> _assets = [];
  bool _isLoading = false;
  String? _error;
  
  // 2. Public getters (read-only)
  List<YieldAsset> get assets => _assets;
  bool get isLoading => _isLoading;
  
  // 3. Public methods for mutation
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners(); // Trigger rebuild
    
    try {
      _assets = await _apiService.getYieldAssets(...);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners(); // Final rebuild
    }
  }
}
```

**Benefits**:
- ✅ Simple and predictable
- ✅ Easy to debug
- ✅ Minimal boilerplate
- ✅ Good performance
- ✅ Works well with Consumer/watch

### Global Provider Registration
```dart
// In main.dart
MultiProvider(
  providers: [
    // ... other providers ...
    ChangeNotifierProvider(create: (_) => BlockchainProvider()),
  ],
  child: const MaizeDetectorApp(),
)

// Use everywhere
Consumer<BlockchainProvider>(builder: (context, provider, _) {...})
context.read<BlockchainProvider>().refresh()
context.watch<BlockchainProvider>().assets
```

---

## Error Handling Strategy

### 3-Tier Error Handling

#### 1. Service Level
```dart
// BlockchainApiService throws exceptions
try {
  final response = await _httpClient.get(url).timeout(duration);
  if (response.statusCode == 200) {
    return parse(response.body);
  } else {
    throw _handleError(response);
  }
} catch (e) {
  throw Exception('Failed to load: $e');
}
```

#### 2. Provider Level
```dart
// BlockchainProvider catches and stores errors
try {
  _assets = await _apiService.getYieldAssets(...);
  _error = null;
} catch (e) {
  _error = _parseError(e); // Human-readable message
}
```

#### 3. UI Level
```dart
// Widget displays error to user
if (provider.error != null) {
  // Show error message
  _ErrorSnackBar(message: provider.error!)
}
```

### Error Types
```dart
// Network errors
'Unable to connect to blockchain service. Please check your connection.'

// Server errors
'API Error (500): Internal Server Error'

// Validation errors
'API Error (400): Invalid asset data'

// Timeout errors
'Request timeout. Please try again.'
```

---

## Testing Strategy

### Unit Test Example
```dart
test('BlockchainProvider loads assets correctly', () async {
  // Arrange
  final mockService = MockBlockchainApiService();
  when(mockService.getYieldAssets('FARMER_001'))
    .thenAnswer((_) async => [mockAsset]);
  
  final provider = BlockchainProvider(apiService: mockService);
  
  // Act
  await provider.initialize('FARMER_001');
  
  // Assert
  expect(provider.assets.length, 1);
  expect(provider.isLoading, false);
  expect(provider.error, isNull);
});
```

### Widget Test Example
```dart
testWidgets('BlockchainTab displays assets', (tester) async {
  // Arrange
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => BlockchainProvider(),
        child: const BlockchainTab(),
      ),
    ),
  );
  
  // Act
  await tester.pumpAndSettle();
  
  // Assert
  expect(find.byType(AssetCard), findsWidgets);
});
```

---

## Performance Considerations

### Loading Optimization
1. **Lazy Initialize**: Provider loads data on first access
2. **Pagination**: Implement for large asset lists (future)
3. **Caching**: 5-minute cache between API calls
4. **Debouncing**: Prevent duplicate rapid requests

### Memory Optimization
1. **Stateless Widgets**: Use for UI components (no state)
2. **const Constructors**: Optimize widget rebuilds
3. **Provider Scoping**: Global provider (not per-widget)

### Network Optimization
1. **HTTP Timeout**: 30 seconds (configurable)
2. **Request Batching**: Single API call for assets + portfolio
3. **Response Compression**: Server should gzip responses

---

## Future Extension Points

### 1. Authentication Integration
```dart
// Add auth service
class BlockchainProvider extends ChangeNotifier {
  final AuthService _authService;
  
  Future<void> initialize() async {
    final farmerId = await _authService.getCurrentFarmerId();
    // ... load assets for authenticated farmer
  }
}
```

### 2. Web3 Integration
```dart
// Add blockchain interaction
class Web3Service {
  Future<bool> connectWallet() async {
    // Use web3dart package
  }
  
  Future<String> sendTransaction(TransactionData txData) async {
    // Send via Ethereum RPC
  }
}
```

### 3. Advanced Features
```dart
// Add to BlockchainProvider
Future<List<Trade>> getTrades(String assetId) async {...}
Future<List<Loan>> getLoans(String farmerId) async {...}
Future<MarketData> getMarketTrend(String cropType) async {...}
```

### 4. Notifications
```dart
// Add push notifications
class NotificationService {
  Future<void> notifyPriceAlert(Asset asset, double price) async {...}
  Future<void> notifyLoanDue(Loan loan) async {...}
}
```

---

## Naming Conventions

### Files
- **Models**: `<entity>.dart` (e.g., `yield_asset.dart`)
- **Services**: `<name>_service.dart` (e.g., `blockchain_api_service.dart`)
- **Providers**: `<feature>_provider.dart` (e.g., `blockchain_provider.dart`)
- **Screens**: `<name>_screen.dart` (e.g., `yield_details_screen.dart`)
- **Widgets**: `<name>_widget.dart` or just `<name>.dart` (e.g., `asset_card.dart`)

### Classes
- **Models**: PascalCase (e.g., `YieldAsset`)
- **Providers**: `<Feature>Provider` (e.g., `BlockchainProvider`)
- **Services**: `<Feature>Service` (e.g., `BlockchainApiService`)
- **Screens**: `<Name>Screen` (e.g., `YieldDetailsScreen`)
- **Widgets**: `<Name>` or `<Name>Widget` (e.g., `AssetCard`)

### Variables
- **Constants**: UPPER_SNAKE_CASE (e.g., `API_TIMEOUT`)
- **Private**: `_camelCase` (e.g., `_isLoading`)
- **Public**: `camelCase` (e.g., `isLoading`)

---

## Dependency Injection Pattern

### Service Injection
```dart
// Production
final apiService = BlockchainApiService();
final provider = BlockchainProvider(apiService: apiService);

// Testing
final mockService = MockBlockchainApiService();
final provider = BlockchainProvider(apiService: mockService);
```

### HTTP Client Injection
```dart
// For testing with mock HTTP responses
final mockClient = MockHttpClient();
final apiService = BlockchainApiService(httpClient: mockClient);
```

---

## Migration from Standalone App to Module

### What Changed
1. **Removed**: Standalone `main.dart` and routing
2. **Added**: Feature module structure
3. **Updated**: Import paths to use feature modules
4. **Integrated**: Provider in main app's MultiProvider

### Why This Works
- ✅ Feature is now a reusable module
- ✅ Can be imported anywhere in the app
- ✅ Shares state management infrastructure
- ✅ Uses main app's theme
- ✅ Follows same navigation patterns

---

## Best Practices Applied

### ✅ SOLID Principles
- **S**ingle Responsibility: Each class has one job
- **O**pen/Closed: Easy to extend without modifying
- **L**iskov Substitution: Services can be swapped
- **I**nterface Segregation: Minimal dependencies
- **D**ependency Inversion: Depend on abstractions

### ✅ Design Patterns
- **Provider Pattern**: State management
- **Dependency Injection**: Testability
- **Strategy Pattern**: Swappable services
- **Builder Pattern**: Complex object construction
- **Observer Pattern**: UI reactivity

### ✅ Code Quality
- Null safety enabled
- Const constructors where possible
- Named parameters for clarity
- Comprehensive error handling
- Type annotations throughout

---

## Conclusion

The blockchain feature architecture provides:

1. **Clarity**: Clear separation of concerns
2. **Testability**: Easy to mock and test
3. **Maintainability**: Easy to modify and extend
4. **Scalability**: Ready for future features
5. **Reusability**: Components can be used elsewhere
6. **Performance**: Optimized loading and state management

This design makes it easy to:
- Add new screens and features
- Integrate with authentication systems
- Connect to different backend APIs
- Test individual components
- Collaborate across development teams

---

**Version**: 1.0  
**Created**: February 6, 2026  
**Framework**: Flutter + Provider Pattern
