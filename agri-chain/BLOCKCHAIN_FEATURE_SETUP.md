# Blockchain Feature Setup Guide

## Quick Start

### Prerequisites
- Flutter SDK 3.0+
- Dart 3.0+
- Git
- A running blockchain backend (API should be at `http://localhost:3000`)

### Step 1: Install Dependencies
```bash
cd agri-chain
flutter pub get
```

### Step 2: Configure Blockchain Backend
Edit `lib/features/blockchain/config/blockchain_config.dart`:
```dart
static const String apiBaseUrl = 'http://YOUR_BACKEND_URL:3000/api';
```

### Step 3: Run the App
```bash
flutter run

# Or for specific device
flutter run -d chrome          # Web
flutter run -d <device-id>     # Physical device
```

### Step 4: Navigate to Yield Features
1. Launch the app
2. Tap the **"Yield"** tab in bottom navigation
3. Observe portfolio summary and asset list
4. Pull to refresh to sync with backend

---

## File Changes Summary

### Files Created (13 new files)
```
✨ NEW FILES CREATED:
├── lib/features/blockchain/config/blockchain_config.dart
├── lib/features/blockchain/models/yield_asset.dart
├── lib/features/blockchain/providers/blockchain_provider.dart
├── lib/features/blockchain/services/blockchain_api_service.dart
├── lib/features/blockchain/services/web3_service.dart
├── lib/features/blockchain/screens/blockchain_tab.dart
├── lib/features/blockchain/screens/yield_details_screen.dart
├── lib/features/blockchain/widgets/asset_card.dart
├── lib/features/blockchain/widgets/asset_details_card.dart
├── lib/features/blockchain/widgets/portfolio_summary.dart
├── lib/features/blockchain/widgets/status_badge.dart
├── BLOCKCHAIN_INTEGRATION_GUIDE.md
└── BLOCKCHAIN_FEATURE_SETUP.md
```

### Files Modified (3 updated files)
```
✏️ UPDATED FILES:
├── lib/main.dart
│   └── Added BlockchainProvider import and registration
├── lib/app_shell.dart
│   └── Added BlockchainTab (Yield tab #4)
└── pubspec.yaml
    └── Added dependencies: google_fonts, fl_chart, intl
```

---

## Key Features

### Tab #4: Yield Asset Management
- **Portfolio Overview**: Total value, asset count, average confidence
- **Asset List**: Scrollable list with asset cards, pull-to-refresh
- **Asset Details**: Full details view with metrics grid
- **Status Tracking**: PENDING, PREDICTED, VERIFIED, TRADEABLE, SETTLED, ARCHIVED
- **Error Handling**: Graceful error messages and retry logic

### Screens
1. **BlockchainTab** - Main yield asset browser
   - Location: `lib/features/blockchain/screens/blockchain_tab.dart`
   - Features: List view, portfolio summary, pull-to-refresh

2. **YieldDetailsScreen** - Individual asset details
   - Location: `lib/features/blockchain/screens/yield_details_screen.dart`
   - Features: Metrics grid, asset info, action buttons

### Widgets
- **AssetCard** - Compact asset display for list
- **PortfolioSummary** - Summary metrics card
- **StatusBadge** - Color-coded status indicator
- **AssetDetailsCard** - Detailed info table

---

## API Integration

### Expected API Endpoints
Your blockchain backend should provide these endpoints:

```bash
# Get all assets for a farmer
GET /api/assets?farmerId=FARMER_001
Response: [ { YieldAsset }, ... ]

# Get single asset
GET /api/assets/ASSET_ID
Response: { YieldAsset }

# Create new asset
POST /api/assets
Body: { YieldAsset }
Response: { YieldAsset with ID }

# Update asset
PUT /api/assets/ASSET_ID
Body: { YieldAsset }
Response: { YieldAsset }

# Delete asset
DELETE /api/assets/ASSET_ID
Response: 204 No Content

# Get portfolio summary
GET /api/portfolio/FARMER_001/summary
Response: { totalValue, assetCount, avgConfidence, ... }

# Execute trade
POST /api/trades
Body: { assetId, amount, tradeType }
Response: { transactionId, status, ... }

# Get market data
GET /api/market/crop/Wheat
Response: { price, volume, trend, ... }
```

### Response Format Example
```json
{
  "assetId": "ASSET_2024_WHEAT_001",
  "tokenId": "AYW-2024-WHEAT-001",
  "farmerId": "FARMER_001",
  "cropType": "Wheat",
  "season": 2024,
  "predictedYield": 5000,
  "confidence": 0.85,
  "tokenAmount": 5000,
  "currentValue": 25000,
  "status": "PREDICTED",
  "createdAt": "2024-02-01T10:00:00Z",
  "updatedAt": "2024-02-06T15:30:00Z"
}
```

---

## Provider Usage

### Access BlockchainProvider in widgets
```dart
import 'package:provider/provider.dart';
import 'package:agri_chain/features/blockchain/providers/blockchain_provider.dart';

// Listen to provider
Consumer<BlockchainProvider>(
  builder: (context, blockchainProvider, _) {
    return Text('Total Value: \$${blockchainProvider.totalPortfolioValue}');
  },
)

// Read provider (non-reactive)
final provider = context.read<BlockchainProvider>();
await provider.refresh();

// Watch provider (reactive)
final provider = context.watch<BlockchainProvider>();
if (provider.isLoading) {
  return const CircularProgressIndicator();
}
```

### Common Methods
```dart
// Initialize with farmer ID
await provider.initialize('FARMER_001');

// Refresh data
await provider.refresh();

// Get filtered assets
final wheatAssets = provider.getAssetsByCropType('Wheat');
final activeAssets = provider.getAssetsByStatus('PREDICTED');
final sortedAssets = provider.getAssetsValueSorted();

// CRUD operations
await provider.createAsset(newAsset);
await provider.updateAsset(updatedAsset);
await provider.deleteAsset(assetId);

// Trading
await provider.executeTrade('ASSET_ID', 100.0, 'BUY');

// Clear everything
provider.clear();
```

---

## Theming

The blockchain feature uses the main app's Material Design 3 theme:
- **Primary Green**: `Color(0xFF2E7D32)`
- **Secondary Green**: `Color(0xFF8BC34A)`
- **Consistent typography** and spacing

All components follow the app's design system defined in `main.dart`.

---

## State Management Flow

```
┌─────────────────┐
│  Blockchain API │
│  (Backend)      │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐
│  BlockchainApiService       │
│  (HTTP Client)              │
└────────┬────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│  BlockchainProvider              │
│  (State Management)              │
│  - assets: List<YieldAsset>     │
│  - isLoading: bool              │
│  - error: String?               │
└────────┬───────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│  UI Widgets                      │
│  - BlockchainTab                │
│  - YieldDetailsScreen           │
│  - AssetCard, etc.              │
└──────────────────────────────────┘
```

---

## Troubleshooting

### Issue: "Connection refused" error
**Cause**: Blockchain backend not running
**Solution**:
1. Check if backend is running: `docker ps` or `npm start`
2. Verify URL in `BlockchainConfig.apiBaseUrl`
3. Check network connectivity

### Issue: Assets show as "Loading..." indefinitely
**Cause**: API not responding
**Solution**:
1. Check backend logs for errors
2. Verify `/api/assets?farmerId=FARMER_001` endpoint exists
3. Increase timeout in `BlockchainConfig.apiTimeout`

### Issue: Can't see Yield tab
**Cause**: Dependencies not installed
**Solution**:
```bash
flutter clean
flutter pub get
flutter run
```

### Issue: Build failures
**Cause**: Dart version mismatch
**Solution**:
```bash
flutter upgrade
flutter pub get
```

---

## Testing in Development

### Mock Data (for testing without backend)
Replace data loading in `blockchain_tab.dart`:
```dart
// Instead of real API call:
// _assets = await _apiService.getYieldAssets(_selectedFarmerId!);

// Use mock data:
_assets = [
  YieldAsset(
    assetId: 'ASSET_2024_WHEAT_001',
    tokenId: 'AYW-2024-WHEAT-001',
    farmerId: 'FARMER_001',
    cropType: 'Wheat',
    season: 2024,
    predictedYield: 5000,
    confidence: 0.85,
    tokenAmount: 5000,
    currentValue: 25000,
    status: 'PREDICTED',
    createdAt: DateTime.now(),
  ),
];
```

### Development Server
To test with a local development server:
```bash
# Terminal 1: Start blockchain backend
npm start                          # or your backend start command

# Terminal 2: Run Flutter app
cd agri-chain
flutter run
```

---

## Performance Optimization

### Caching
- Implement caching in `BlockchainApiService`
- Cache duration: 5 minutes (configurable in `BlockchainConfig`)

### Pagination
- Add pagination for large asset lists
- Default page size: 20 (configurable in `BlockchainConfig`)

### Lazy Loading
- Assets load on-demand when scrolling
- Portfolio summary loaded separately

---

## Next Steps

1. **Test Integration**: Launch app and verify Yield tab works
2. **Deploy Backend**: Set up blockchain API at configured URL
3. **Authentication**: Integrate farmer authentication for proper farmer IDs
4. **Phase 2 Features**: Implement trading, loans, and advanced features

---

## Support

For issues or questions:
1. Check logs: `flutter logs`
2. Review [BLOCKCHAIN_INTEGRATION_GUIDE.md](./BLOCKCHAIN_INTEGRATION_GUIDE.md)
3. Verify backend API is responding: `curl http://localhost:3000/api/assets`
4. Check Flutter channel: `flutter channel`

---

**Version**: 1.0  
**Last Updated**: February 6, 2026  
**Maintainer**: AgriChain Development Team
