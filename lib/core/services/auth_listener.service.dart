import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feature/auth/presentation/pages/reset_password.page.dart';

class AuthListenerService {
  AuthListenerService({
    required this.navigatorKey,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  StreamSubscription<AuthState>? _subscription;

  void start() {
    _subscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
          final event = data.event;

          if (event == AuthChangeEvent.passwordRecovery) {
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const ResetPasswordPage(),
              ),
                  (_) => false,
            );
          }
        });
  }

  void dispose() {
    _subscription?.cancel();
  }
}