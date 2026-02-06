# Flutter Development Patterns & Best Practices

## API Integration Pattern

### Service Layer Pattern

```dart
// lib/services/base_service.dart
abstract class BaseService {
  static const Duration timeout = Duration(seconds: 30);
  
  Future<T> handleRequest<T>(Future<dynamic> request) async {
    try {
      final response = await request.timeout(timeout);
      return response as T;
    } on TimeoutException catch (_) {
      throw Exception('Request timeout. Please try again.');
    } catch (e) {
      throw Exception('Failed to complete request: $e');
    }
  }
}

// lib/services/api_service.dart
class ApiService extends BaseService {
  static const String baseUrl = 'http://localhost:3000/api';
  
  Future<List<YieldAsset>> getAssets(String farmerId) async {
    return handleRequest(
      http.get(Uri.parse('$baseUrl/assets/$farmerId'))
        .then((response) {
          if (response.statusCode == 200) {
            List<dynamic> data = jsonDecode(response.body);
            return data.map((asset) => YieldAsset.fromJson(asset)).toList();
          } else {
            throw Exception('Failed to load assets');
          }
        }),
    );
  }
}
```

## State Management Pattern

### Using Provider

```dart
// lib/providers/yield_provider.dart
class YieldProvider with ChangeNotifier {
  List<YieldAsset> _assets = [];
  bool _isLoading = false;
  String? _error;

  List<YieldAsset> get assets => _assets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAssets(String farmerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _assets = await ApiService().getAssets(farmerId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearAssets() {
    _assets = [];
    notifyListeners();
  }
}

// Usage in Widget
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yieldProvider = Provider.of<YieldProvider>(context);

    return FutureBuilder(
      future: yieldProvider.loadAssets('farmer_id'),
      builder: (context, snapshot) {
        if (yieldProvider.isLoading) {
          return const CircularProgressIndicator();
        }
        if (yieldProvider.error != null) {
          return Text('Error: ${yieldProvider.error}');
        }
        return ListView(
          children: yieldProvider.assets
            .map((asset) => AssetCard(asset: asset))
            .toList(),
        );
      },
    );
  }
}
```

## Navigation Pattern

### GoRouter Configuration

```dart
// lib/routes/app_router.dart
final GoRouter router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isLoggedIn = _checkIfLoggedIn();
    if (!isLoggedIn && state.location != '/login') {
      return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'farmer-dashboard',
          builder: (context, state) => const FarmerDashboard(),
          routes: [
            GoRoute(
              path: 'asset/:id',
              builder: (context, state) => AssetDetailScreen(
                assetId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

// Usage in Navigation
context.go('/farmer-dashboard');
context.go('/farmer-dashboard/asset/123');
```

## Widget Composition Pattern

### Reusable Components

```dart
// lib/widgets/stat_card.dart
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            Text(subtitle, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}

// Usage
StatCard(
  title: 'Total Tokens',
  value: '5000',
  subtitle: 'AYT',
  icon: Icons.agriculture,
  color: AppTheme.primaryGreen,
)
```

## Error Handling Pattern

```dart
// lib/utils/error_handler.dart
class ErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else if (error is SocketException) {
      return 'No internet connection.';
    } else if (error is FormatException) {
      return 'Invalid response format.';
    } else {
      return error.toString();
    }
  }

  static void showErrorSnackbar(BuildContext context, dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(getErrorMessage(error)),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Usage
try {
  await ApiService().getAssets('farmerId');
} catch (e) {
  ErrorHandler.showErrorSnackbar(context, e);
}
```

## Async Loading Pattern

```dart
// lib/screens/async_screen.dart
class AssetListScreen extends StatelessWidget {
  final Future<List<YieldAsset>> assetsFuture;

  const AssetListScreen({
    Key? key,
    required this.assetsFuture,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<YieldAsset>>(
      future: assetsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() => {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No assets found'));
        }

        return ListView(
          children: snapshot.data!
            .map((asset) => AssetCard(asset: asset))
            .toList(),
        );
      },
    );
  }
}
```

## Form Handling Pattern

```dart
// lib/screens/forms/asset_form.dart
class AssetForm extends StatefulWidget {
  const AssetForm({Key? key}) : super(key: key);

  @override
  State<AssetForm> createState() => _AssetFormState();
}

class _AssetFormState extends State<AssetForm> {
  final _formKey = GlobalKey<FormState>();
  final _cropController = TextEditingController();
  final _yieldController = TextEditingController();

  @override
  void dispose() {
    _cropController.dispose();
    _yieldController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final asset = YieldAsset(
        cropType: _cropController.text,
        predictedYield: double.parse(_yieldController.text),
        // ... other fields
      );
      ApiService().createYieldAsset(asset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _cropController,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter crop type';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _yieldController,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter yield';
              }
              if (double.tryParse(value!) == null) {
                return 'Please enter a valid number';
              }
              return null;
            },
          ),
          ElevatedButton(
            onPressed: _submitForm,
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
```

## Local Storage Pattern

```dart
// lib/services/storage_service.dart
class StorageService {
  static final StorageService _instance = StorageService._internal();
  late SharedPreferences _prefs;

  factory StorageService() {
    return _instance;
  }

  StorageService._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // String operations
  Future<bool> setString(String key, String value) {
    return _prefs.setString(key, value);
  }

  String? getString(String key) {
    return _prefs.getString(key);
  }

  // List operations
  Future<bool> setStringList(String key, List<String> value) {
    return _prefs.setStringList(key, value);
  }

  List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }

  // Cleanup
  Future<bool> remove(String key) {
    return _prefs.remove(key);
  }

  Future<bool> clear() {
    return _prefs.clear();
  }
}

// Usage
final storage = StorageService();
await storage.init();
await storage.setString('userId', '123');
final userId = storage.getString('userId');
```

## Responsive Design Pattern

```dart
// lib/utils/responsive.dart
class Responsive {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width < 1200 &&
        MediaQuery.of(context).size.width >= 600;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  static double getWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
}

// Usage
class ResponsiveScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Responsive.isMobile(context)
        ? const MobileLayout()
        : const DesktopLayout();
  }
}
```

## Constants & Configuration

```dart
// lib/config/constants.dart
class Config {
  // API Configuration
  static const String apiBaseUrl = 'https://api.agriyield.com';
  static const Duration apiTimeout = Duration(seconds: 30);

  // Blockchain Configuration
  static const String rpcUrl = 'https://rpc.ethereum.org';
  static const String chainId = '1';

  // App Configuration
  static const String appName = 'AgriYield';
  static const String appVersion = '1.0.0';
}
```

## Testing Patterns

```dart
// test/services/api_service_test.dart
void main() {
  group('ApiService', () {
    late MockHttpClient mockHttpClient;
    late ApiService apiService;

    setUp(() {
      mockHttpClient = MockHttpClient();
      apiService = ApiService(httpClient: mockHttpClient);
    });

    test('getAssets returns list of yield assets', () async {
      final mockResponse = '''
        [
          {
            "assetId": "123",
            "tokenId": "AYT-001",
            "cropType": "Wheat"
          }
        ]
      ''';

      when(mockHttpClient.get(any))
          .thenAnswer((_) async => http.Response(mockResponse, 200));

      final assets = await apiService.getAssets('farmer_1');

      expect(assets.length, 1);
      expect(assets[0].cropType, 'Wheat');
    });
  });
}
```

## Bloc Pattern (Alternative to Provider)

```dart
// lib/blocs/asset_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

// Events
abstract class AssetEvent {}
class LoadAssets extends AssetEvent {
  final String farmerId;
  LoadAssets(this.farmerId);
}

// States
abstract class AssetState {}
class AssetInitial extends AssetState {}
class AssetLoading extends AssetState {}
class AssetLoaded extends AssetState {
  final List<YieldAsset> assets;
  AssetLoaded(this.assets);
}
class AssetError extends AssetState {
  final String message;
  AssetError(this.message);
}

// Bloc
class AssetBloc extends Bloc<AssetEvent, AssetState> {
  final ApiService apiService;

  AssetBloc(this.apiService) : super(AssetInitial()) {
    on<LoadAssets>((event, emit) async {
      emit(AssetLoading());
      try {
        final assets = await apiService.getAssets(event.farmerId);
        emit(AssetLoaded(assets));
      } catch (e) {
        emit(AssetError(e.toString()));
      }
    });
  }
}

// Usage in Widget
class AssetListWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssetBloc, AssetState>(
      builder: (context, state) {
        if (state is AssetLoading) {
          return const CircularProgressIndicator();
        } else if (state is AssetLoaded) {
          return ListView(
            children: state.assets
                .map((asset) => AssetCard(asset: asset))
                .toList(),
          );
        } else if (state is AssetError) {
          return Text('Error: ${state.message}');
        }
        return const SizedBox.shrink();
      },
    );
  }
}
```

---

These patterns represent Flutter best practices and can be adapted to your specific needs. Choose patterns that fit your application architecture and team preferences.
