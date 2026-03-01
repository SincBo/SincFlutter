import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      debugPrint('AuthStateChange event: $event');

      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint('Password recovery mode detected');
        // Navegar a ResetPasswordPage
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
    final authState = ref.watch(authNotifierProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Sincbo Flutter',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      home: authState.when(
        data: (user) {
          if (user == null) return const LoginPage();
          return const HomePage();
        },
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, st) => Scaffold(body: Center(child: Text('Error: ${e.toString()}'))),
      ),
    );
  }
}
