import 'package:go_router/go_router.dart';
import '../screens/dashboard/farmer_dashboard.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/onboarding/splash_screen.dart';
import '../screens/common/home_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/farmer-dashboard',
        builder: (context, state) => const FarmerDashboard(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboard(),
      ),
    ],
  );
}
