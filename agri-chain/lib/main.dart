import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/splash_screen.dart';
import 'package:agri_chain/services/tflite_service.dart';
import 'package:agri_chain/providers/scan_provider.dart';
import 'package:agri_chain/providers/alerts_provider.dart';
import 'package:agri_chain/providers/fields_provider.dart';
import 'package:agri_chain/features/blockchain/providers/blockchain_provider.dart';
import 'package:agri_chain/firebase_bootstrap.dart';
import 'package:agri_chain/rover/providers/rover_provider.dart';
import 'package:agri_chain/services/auth_service.dart';
import 'package:agri_chain/services/recommendation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FirebaseBootstrap.initialize();
    await RecommendationService.init();
  } catch (e) {
    // Continue without Firebase if not configured
  }

  // We explicitly DO NOT initialize heavy ML models (TFLite or MindSpore) here.
  // This prevents the black screen delay during app startup.
  // Models will be lazy-loaded when the Camera Screen is opened.
  final tfliteService = TFLiteService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider<TFLiteService>(create: (_) => tfliteService),
        ChangeNotifierProvider(create: (_) => ScanProvider()),
        ChangeNotifierProvider(create: (_) => FieldsProvider()),
        ChangeNotifierProvider(create: (_) => AlertsProvider()),
        ChangeNotifierProvider(create: (_) => BlockchainProvider()),
        ChangeNotifierProvider(create: (_) => RoverProvider()),
      ],
      child: const MaizeDetectorApp(),
    ),
  );
}

class MaizeDetectorApp extends StatelessWidget {
  const MaizeDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2E7D32);
    const primaryDark = Color(0xFF1B5E20);
    const background = Color(0xFFF6F8F7);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: const Color(0xFF8BC34A),
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'AgriChain',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: background,

        cardTheme: const CardThemeData(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(22)),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        fontFamily: 'Inter',
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: colorScheme.surface,
          selectedColor: colorScheme.primary.withOpacity(0.12),
          side: BorderSide(color: Colors.grey.shade300),
          labelStyle: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
          secondaryLabelStyle: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant,
          type: BottomNavigationBarType.fixed,
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 70,
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primary.withOpacity(0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w600,
              fontSize: 12,
              color: states.contains(WidgetState.selected)
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            );
          }),
        ),
        iconTheme: const IconThemeData(color: primaryDark),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
