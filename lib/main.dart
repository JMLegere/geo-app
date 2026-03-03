import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/features/auth/screens/login_screen.dart';
import 'package:fog_of_world/features/map/map_screen.dart';

void main() {
  runApp(const ProviderScope(child: FogOfWorldApp()));
}

/// Root widget — routes to [MapScreen] when the user is authenticated or in
/// guest mode, and to [LoginScreen] when there is no session.
///
/// The initial auth state is [AuthStatus.loading] (checking for a saved
/// session), which maps to [MapScreen] to avoid a jarring flash of the login
/// screen on cold start. Once the session check completes, the state
/// transitions to either [AuthStatus.authenticated] or
/// [AuthStatus.unauthenticated].
class FogOfWorldApp extends ConsumerWidget {
  const FogOfWorldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Fog of World',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1A73E8),
        brightness: Brightness.light,
      ),
      home: switch (authState.status) {
        AuthStatus.authenticated ||
        AuthStatus.guest ||
        AuthStatus.loading =>
          const MapScreen(),
        _ => const LoginScreen(),
      },
    );
  }
}
