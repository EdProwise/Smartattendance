import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/schools_screen.dart';
import 'screens/profile_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const SmartAttendanceApp());
}

final _router = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) async {
    final loc = state.matchedLocation;

    // Splash and home are always accessible (home shows guest view when not logged in)
    if (loc == '/splash' || loc == '/') return null;

    final user = await AuthService.getSession();
    final loggedIn = user != null;
    final onAuth = loc == '/login' ||
        loc == '/register' ||
        loc == '/forgot-password';

    // Functional screens require login
    if (!loggedIn && !onAuth) return '/login';
    // Already logged in — bounce away from auth pages back to home
    if (loggedIn && onAuth) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/scan', builder: (_, __) => const ScanScreen()),
    GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
    GoRoute(path: '/attendance', builder: (_, __) => const AttendanceScreen()),
    GoRoute(path: '/stats', builder: (_, __) => const StatsScreen()),
    GoRoute(path: '/schools', builder: (_, __) => const SchoolsScreen()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
  ],
);

class SmartAttendanceApp extends StatelessWidget {
  const SmartAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Smart Attendance',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF854CF4),
            secondary: const Color(0xFF04D3D3),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF854CF4),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF854CF4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF854CF4),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF854CF4), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            labelStyle: const TextStyle(color: Colors.black54),
            floatingLabelStyle: const TextStyle(color: Color(0xFF854CF4)),
          ),
        ),
      );
  }
}
