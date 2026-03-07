import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'utils/app_theme.dart';
import 'screens/splash_onboarding.dart';
import 'screens/auth_screens.dart';
import 'screens/farmer_screens.dart';
import 'screens/owner_screens.dart';
import 'screens/admin_screen.dart';
import 'screens/unified_home.dart';
import 'models/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Initialize Supabase (replaces Firebase.initializeApp) ──────────────────
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const KisanYantraApp());
}

class KisanYantraApp extends StatelessWidget {
  const KisanYantraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        onGenerateRoute: _generateRoute,
      ),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return _fade(const SplashScreen());
      case '/onboarding':
        return _slide(const OnboardingScreen());
      case '/login':
        return _fade(const LoginScreen());
      case '/register':
        return _fade(const RegisterScreen());
      case '/forgot-password':
        return _slide(const ForgotPasswordScreen());
      case '/home':
        return _fade(const UnifiedHomeScreen());
      case '/farmer': // legacy path → unified experience
      case '/owner':
        return _fade(const UnifiedHomeScreen());
      case '/equipment-detail':
        return _slide(EquipmentDetailScreen(listing: settings.arguments as EquipmentListing));
      case '/booking-request':
        return _slide(BookingRequestScreen(listing: settings.arguments as EquipmentListing));
      case '/booking-detail':
        final args = settings.arguments as Map;
        return _slide(BookingDetailScreen(
          booking: args['booking'] as BookingModel,
          isOwner: args['isOwner'] as bool? ?? false,
        ));
      case '/owner':
        return _fade(const OwnerHomeScreen());
      case '/add-listing':
        return _slide(AddEditListingScreen(existing: settings.arguments as EquipmentListing?));
      case '/admin':
        return _fade(const AdminDashboardScreen());
      default:
        return _fade(const LoginScreen());
    }
  }

  PageRoute _fade(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 300));

  PageRoute _slide(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, c) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
          child: c),
      transitionDuration: const Duration(milliseconds: 300));
}
