import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Core
import 'core/services/firebase_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';

// Providers
import 'features/auth/provider/auth_provider.dart';
import 'features/friends/provider/friends_provider.dart';
import 'features/settings/provider/settings_provider.dart';
import 'features/tracking/provider/tracking_provider.dart';

// Screens
import 'features/auth/view/login_screen.dart';
import 'features/home/view/home_screen.dart';
import 'features/tracking/view/tracking_map_screen.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await FirebaseService.initialize();

  // Initialize Storage Service
  await StorageService.instance.initialize();

  runApp(const TrackMateApp());
}

/// Main application widget
class TrackMateApp extends StatelessWidget {
  const TrackMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth Provider
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Friends Provider
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
        // Tracking Provider
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
        // Settings Provider
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        title: 'TrackMate',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
        onGenerateRoute: _generateRoute,
      ),
    );
  }

  /// Generate routes for navigation
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/tracking-map':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => TrackingMapScreen(
            trackedUserId: args['trackedUserId'],
            trackedUsername: args['trackedUsername'],
          ),
        );
      default:
        return null;
    }
  }
}

/// Wrapper to handle authentication state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize auth state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading while checking auth state
        if (!authProvider.isInitialized) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 64,
                    color: AppTheme.primaryColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'TrackMate',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

        // Show login or home based on auth state
        if (authProvider.isLoggedIn) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
