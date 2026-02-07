# Blockchain Feature - Quick Reference Guide

## 🎯 Quick Navigation

| Need | Location | File |
|------|----------|------|
| Add new endpoint? | Service layer | `services/blockchain_api_service.dart` |
| Change API URL? | Configuration | `config/blockchain_config.dart` |
| Update UI design? | Screens/Widgets | `screens/`, `widgets/` |
| Modify state logic? | Provider | `providers/blockchain_provider.dart` |
| Add new model field? | Model | `models/yield_asset.dart` |

---

## 📁 File Quick Reference

### Configuration
```dart
// Update API endpoint
lib/features/blockchain/config/blockchain_config.dart
  └─ BlockchainConfig.apiBaseUrl = 'YOUR_URL'
```

### Data Models
```dart
// Yield asset model with JSON support
lib/features/blockchain/models/yield_asset.dart
  └─ YieldAsset.fromJson()
  └─ YieldAsset.toJson()
  └─ YieldAsset.copyWith()
```

### State Management
```dart
// Main provider for all blockchain state
lib/features/blockchain/providers/blockchain_provider.dart
  └─ BlockchainProvider extends ChangeNotifier
      ├─ assets: List<YieldAsset>
      ├─ isLoading: bool
      ├─ error: String?
      └─ Methods: initialize(), refresh(), createAsset(), etc.
```

### API Services
```dart
// REST API client
lib/features/blockchain/services/blockchain_api_service.dart
  └─ BlockchainApiService
      ├─ getYieldAssets(farmerId)
      ├─ createYieldAsset(asset)
      ├─ executeTrade(assetId, amount, type)
      └─ ... (8 methods total)

// Blockchain interactions (Web3)
lib/features/blockchain/services/web3_service.dart
  └─ Web3Service
      ├─ connectWallet()
      ├─ sendTransaction()
      └─ ... (stub implementations)
```

### Screens
```dart
// Main tab for yield assets
lib/features/blockchain/screens/blockchain_tab.dart
  └─ BlockchainTab() - List of assets with pull-to-refresh

// Asset details view
lib/features/blockchain/screens/yield_details_screen.dart
  └─ YieldDetailsScreen(asset) - Full details with actions
```

### Widgets
```dart
// Reusable components
lib/features/blockchain/widgets/

asset_card.dart
  └─ AssetCard(asset, onTap)       # List item

portfolio_summary.dart
  └─ PortfolioSummary(metrics)     # Overview card

status_badge.dart
  └─ StatusBadge(status)           # Status indicator

asset_details_card.dart
  └─ AssetDetailsCard(asset)       # Details table
```

---

## 💻 Code Examples

### Use Provider in Widget
```dart
// Reading state
Consumer<BlockchainProvider>(
  builder: (context, provider, _) {
    return Text('Assets: ${provider.assets.length}');
  },
)

// Non-reactive access
context.read<BlockchainProvider>().refresh()

// Reactive watch
final assets = context.watch<BlockchainProvider>().assets
```

### API Call Pattern
```dart
final service = BlockchainApiService();

// GET
final assets = await service.getYieldAssets('FARMER_001');

// POST
final newAsset = await service.createYieldAsset(asset);

// PUT
final updated = await service.updateYieldAsset(assetId, asset);

// DELETE
await service.deleteYieldAsset(assetId);
```

### Provider Methods
```dart
final provider = context.read<BlockchainProvider>();

// Initialize
await provider.initialize('FARMER_001');

// Refresh
await provider.refresh();

// CRUD
await provider.createAsset(asset);
await provider.updateAsset(asset);
await provider.deleteAsset(assetId);

// Actions
await provider.executeTrade(assetId, amount, 'BUY');

// Filtering
provider.getAssetsByStatus('PREDICTED')
provider.getAssetsByCropType('Wheat')
provider.getAssetsValueSorted()
```

---

## 🔌 API Integration

### Endpoints Summary
```
GET    /api/assets?farmerId=X           # List
GET    /api/assets/{id}                 # Get one
POST   /api/assets                      # Create
PUT    /api/assets/{id}                 # Update
DELETE /api/assets/{id}                 # Delete
GET    /api/portfolio/{id}/summary      # Summary
POST   /api/trades                      # Trade
GET    /api/market/crop/{type}          # Market data
```

### Configure Endpoint
```dart
// File: lib/features/blockchain/config/blockchain_config.dart

class BlockchainConfig {
  static const String apiBaseUrl = 'http://localhost:3000/api';
  static const Duration apiTimeout = Duration(seconds: 30);
}
```

### Add New Endpoint
```dart
// Add to BlockchainApiService
Future<List<MyData>> getMyData() async {
  try {
    final response = await _httpClient.get(
      Uri.parse('${BlockchainConfig.apiBaseUrl}/my-endpoint'),
    ).timeout(BlockchainConfig.apiTimeout);
    
    if (response.statusCode == 200) {
      return _parse(response.body);
    } else {
      throw _handleError(response);
    }
  } catch (e) {
    throw Exception('Failed: $e');
  }
}

// Add to BlockchainProvider
Future<void> fetchMyData() async {
  _isLoading = true;
  try {
    _myData = await _apiService.getMyData();
    _error = null;
  } catch (e) {
    _error = _parseError(e);
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

---

## 🎨 UI Customization

### Update Colors
```dart
// File: lib/main.dart
// The blockchain feature uses the main app theme
// Modify ColorScheme in MaizeDetectorApp

const primary = Color(0xFF2E7D32);  // Change here
const primaryDark = Color(0xFF1B5E20);
```

### Update Typography
```dart
// Using TextTheme from context
Theme.of(context).textTheme.titleLarge
Theme.of(context).textTheme.bodyMedium
Theme.of(context).textTheme.labelSmall
```

### Add New Widget
```dart
// Create lib/features/blockchain/widgets/my_widget.dart
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text('My widget'),
    );
  }
}

// Use in screen
import 'package:agri_chain/features/blockchain/widgets/my_widget.dart';

// In build()
MyWidget()
```

---

## 🧪 Testing Quick Start

### Unit Test Template
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:agri_chain/features/blockchain/providers/blockchain_provider.dart';

void main() {
  group('BlockchainProvider', () {
    test('loads assets correctly', () async {
      // Arrange
      final provider = BlockchainProvider();
      
      // Act
      await provider.initialize('FARMER_001');
      
      // Assert
      expect(provider.assets.isNotEmpty, true);
      expect(provider.isLoading, false);
    });
  });
}
```

### Widget Test Template
```dart
void main() {
  testWidgets('BlockchainTab displays assets', (tester) async {
    // Arrange & Act
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => BlockchainProvider(),
          child: const BlockchainTab(),
        ),
      ),
    );
    
    await tester.pumpAndSettle();
    
    // Assert
    expect(find.byType(AssetCard), findsWidgets);
  });
}
```

---

## 🐛 Debugging Tips

### View Provider State
```dart
// Print provider state
final provider = context.read<BlockchainProvider>();
print('Assets: ${provider.assets.length}');
print('Error: ${provider.error}');
print('Loading: ${provider.isLoading}');
```

### Check API Response
```dart
// Add logging to BlockchainApiService
print('Request: $url');
print('Status: ${response.statusCode}');
print('Body: ${response.body}');
```

### Widget Debug
```dart
// Enable debug output
debugPrintBeginFrameBanner = true;
debugPrintEndFrameBanner = true;

// Find widgets
expect(find.byType(AssetCard), findsWidgets);
expect(find.byKey(Key('assetList')), findsOneWidget);
```

---

## 📦 Dependencies

### Required by Blockchain Feature
```yaml
provider: ^6.1.3           # State management
http: ^1.1.2              # HTTP client
shared_preferences: ^2.2.2 # Storage
google_fonts: ^6.1.0      # Theming
fl_chart: ^0.65.0         # Charts
intl: ^0.19.0             # Formatting
```

### Already in Main App
All these are already included in the main app's pubspec.yaml.

---

## 🚀 Deployment Checklist

- [ ] Backend API deployed and accessible
- [ ] API endpoint configured in BlockchainConfig
- [ ] Authentication integrated with provider.initialize()
- [ ] Error messages user-friendly
- [ ] API timeout appropriate for production
- [ ] Cache strategy implemented
- [ ] Rate limiting handled
- [ ] Logging enabled
- [ ] Monitoring set up
- [ ] Tested on all platforms (Android, iOS, Web)

---

## 📞 Common Tasks

### Add New Asset Status
```dart
// 1. Add to BlockchainConfig
class AssetStatus {
  static const String myStatus = 'MY_STATUS';
}

// 2. Add color in StatusBadge
Color _getStatusColor() {
  switch (status) {
    case 'MY_STATUS':
      return Colors.blue;
    // ...
  }
}

// 3. Use in filtering
provider.getAssetsByStatus('MY_STATUS')
```

### Add New Crop Type
```dart
// File: lib/features/blockchain/config/blockchain_config.dart

class CropTypes {
  static const String myCrop = 'MyCrop';
  static const List<String> all = [
    wheat, corn, rice, soybean, barley, myCrop  // Add here
  ];
}
```

### Handle New Error Type
```dart
// In BlockchainProvider._parseError()
String _parseError(Object error) {
  if (error is MyCustomException) {
    return 'Custom error message';
  }
  // ... other error types
}
```

### Add Loading Indicator
```dart
// In widget build()
if (provider.isLoading) {
  return const Center(child: CircularProgressIndicator());
}
```

---

## 🔗 Documentation Links

| Document | Purpose |
|----------|---------|
| [BLOCKCHAIN_INTEGRATION_GUIDE.md](BLOCKCHAIN_INTEGRATION_GUIDE.md) | Technical architecture & overview |
| [BLOCKCHAIN_FEATURE_SETUP.md](BLOCKCHAIN_FEATURE_SETUP.md) | Setup guide & troubleshooting |
| [BLOCKCHAIN_ARCHITECTURE.md](BLOCKCHAIN_ARCHITECTURE.md) | Design patterns & decisions |
| [REFACTORING_COMPLETE.md](REFACTORING_COMPLETE.md) | Migration summary & status |

---

## ⚡ Performance Tips

1. **Minimize Rebuilds**: Use Consumer only for needed parts
2. **Cache Results**: Implement 5-minute cache for API responses
3. **Lazy Load**: Assets load on-demand, not all at once
4. **Pagination**: Add pagination for large lists
5. **Debounce**: Prevent rapid repeated API calls
6. **Use const**: Make widgets const where possible

---

## 🤝 Contributing

### Code Style
- Use const constructors
- Naming: `camelCase` for vars, `UPPER_CASE` for constants
- Comments for complex logic
- Type annotations everywhere
- Single responsibility per class/method

### File Organization
- Models in `models/`
- Services in `services/`
- Providers in `providers/`
- Screens in `screens/`
- Widgets in `widgets/`
- Config in `config/`

---

**Last Updated**: February 6, 2026  
**Version**: 1.0
