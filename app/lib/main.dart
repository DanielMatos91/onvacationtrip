
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// Import generated Firebase options
import '../../firebase_options.dart';

// Import services and providers
import 'services/auth_service.dart';

// Import screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/invite_screen.dart';
import 'screens/home/rides_list_screen.dart';
import 'screens/home/ride_detail_screen.dart';
import 'screens/home/support_screen.dart';
import 'screens/auth/pending_screen.dart';
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // Use the generated options for the current platform
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const AppWithRouter(),
    );
  }
}

class AppWithRouter extends StatelessWidget {
  const AppWithRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    final router = GoRouter(
      refreshListenable: authService,
      initialLocation: '/', // Start at the AuthGate to determine route
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const AuthGate(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignUpScreen(),
        ),
        GoRoute(
          path: '/invite',
          builder: (context, state) => const InviteScreen(),
        ),
         GoRoute(
          path: '/pending',
          builder: (context, state) => const PendingScreen(),
        ),
        GoRoute(
          path: '/rides',
          builder: (context, state) => const RidesListScreen(),
        ),
        GoRoute(
          path: '/ride/:rideId',
          builder: (context, state) => RideDetailScreen(rideId: state.pathParameters['rideId']!),
        ),
        GoRoute(
          path: '/support',
          builder: (context, state) => const SupportScreen(),
        ),
      ],
      redirect: (BuildContext context, GoRouterState state) {
        final isAuthenticated = authService.currentUser != null;
        final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

        // If user is not authenticated and not on an auth route, redirect to login
        if (!isAuthenticated && !isAuthRoute) {
          return '/login';
        }

        // If user is authenticated and tries to access an auth route, redirect to home ('/')
        if (isAuthenticated && isAuthRoute) {
          return '/'; 
        }

        return null; // No redirect needed
      },
    );

    return MaterialApp.router(
      title: 'Driver App',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final baseTheme = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorSchemeSeed: Colors.deepPurple,
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.robotoTextTheme(baseTheme.textTheme),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
