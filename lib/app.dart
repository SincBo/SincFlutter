import 'package:flutter/material.dart';

import 'core/services/auth_listener.service.dart';
import 'core/theme/app_theme.dart';
import 'feature/auth/AuthGate.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final navigatorKey = GlobalKey<NavigatorState>();

  late final AuthListenerService _authListener;

  @override
  void initState() {
    super.initState();

    _authListener = AuthListenerService(
      navigatorKey: navigatorKey,
    );

    _authListener.start();
  }

  @override
  void dispose() {
    _authListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Sincbo Flutter',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}