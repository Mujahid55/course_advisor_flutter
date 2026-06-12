import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/admin_dashboard_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/auth_service.dart';

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_isDesktop) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      minimumSize: Size(400, 600),
      size: Size(820, 720),
      center: true,
      title: 'CourseAdvisor',
    );
    await windowManager.waitUntilReadyToShow(options);
    await windowManager.show();
    await windowManager.focus();
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Determine initial screen based on stored auth state
  final auth = AuthService();
  final token = await auth.getToken();
  final role = await auth.getRole();

  Widget home;
  if (token == null || token.isEmpty) {
    home = const _LoginEntry();
  } else if (role == 'it_admin') {
    home = const _AdminEntry();
  } else {
    home = const _ChatEntry();
  }

  runApp(CourseAdvisorApp(home: home));
}

// ---------------------------------------------------------------------------
// Entry wrappers — hold navigation callbacks
// ---------------------------------------------------------------------------

class _LoginEntry extends StatelessWidget {
  const _LoginEntry();

  @override
  Widget build(BuildContext context) => LoginScreen(
        onLoginSuccess: (role) => _navigate(context, role),
      );

  static void _navigate(BuildContext context, String role) {
    Widget screen;
    if (role == 'it_admin') {
      screen = const _AdminEntry();
    } else {
      screen = const _ChatEntry();
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _RegisterEntry extends StatelessWidget {
  const _RegisterEntry();

  @override
  Widget build(BuildContext context) => RegisterScreen(
        onRegisterSuccess: (role) => _LoginEntry._navigate(context, role),
      );
}

class _ChatEntry extends StatelessWidget {
  const _ChatEntry();

  @override
  Widget build(BuildContext context) => ChatScreen(
        onLogout: () => _goLogin(context),
      );

  static void _goLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const _LoginEntry()),
      (_) => false,
    );
  }
}

class _AdminEntry extends StatelessWidget {
  const _AdminEntry();

  @override
  Widget build(BuildContext context) => AdminDashboardScreen(
        onLogout: () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const _LoginEntry()),
          (_) => false,
        ),
      );
}

// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------

class CourseAdvisorApp extends StatelessWidget {
  const CourseAdvisorApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CourseAdvisor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
        ),
        fontFamily: 'Inter',
      ),
      home: home,
      // Named routes for login/register cross-navigation
      routes: {
        '/login': (_) => const _LoginEntry(),
        '/register': (_) => const _RegisterEntry(),
      },
    );
  }
}
