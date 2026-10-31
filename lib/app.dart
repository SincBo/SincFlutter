import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/auth_notifier_provider.dart';
import 'core/theme/app_theme.dart';
import 'feature/auth/auth_gate.dart';
import 'feature/auth/presentation/pages/reset_password.page.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // Escuchamos el provider de recovery que AuthNotifier activa
    // cuando Supabase emite el evento passwordRecovery.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listen<bool>(passwordRecoveryProvider, (previous, isRecovery) {
        if (isRecovery) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
            (_) => false,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SincBo',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}