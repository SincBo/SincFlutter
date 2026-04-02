import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sincboflutter/AuthGate.dart';
import 'package:sincboflutter/ui/pages/home/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'ui/pages/login_page.dart';
import 'ui/pages/reset_password_page.dart';
import 'ui/theme/app_theme.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Failed to load .env: $e');
  }

  await Supabase.initialize(
    url: 'https://hsbgqbyumyvcxczwuvqv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhzYmdxYnl1bXl2Y3hjend1dnF2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkwODE2OTcsImV4cCI6MjA2NDY1NzY5N30.aZJVU1x76CTI7wYhYBZ5WDYH_PAUibE_iG2zxZQTzK8',
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    // Solo manejar passwordRecovery aquí, lo demás lo maneja AuthGate
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint('AuthStateChange event: $event');

      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint('Password recovery mode detected');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
            (route) => false,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Sincbo Flutter',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}

/// Splash Screen con degradado radial verde a negro
class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              Color(0xFF00D9C0), // Verde centro
              Color(0xFF000000), // Negro esquinas
            ],
            stops: [0.3, 1.0],
          ),
        ),
        child: Center(
          child: Image.asset(
            'assets/images/sinc.png',
            width: 200,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.image_not_supported,
                size: 100,
                color: Colors.white,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Splash que transiciona automáticamente al Login
class SplashToLoginScreen extends StatefulWidget {
  const SplashToLoginScreen({Key? key}) : super(key: key);

  @override
  State<SplashToLoginScreen> createState() => _SplashToLoginScreenState();
}

class _SplashToLoginScreenState extends State<SplashToLoginScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

/// Splash que transiciona automáticamente al Home
class SplashToHomeScreen extends StatefulWidget {
  const SplashToHomeScreen({Key? key}) : super(key: key);

  @override
  State<SplashToHomeScreen> createState() => _SplashToHomeScreenState();
}

class _SplashToHomeScreenState extends State<SplashToHomeScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
