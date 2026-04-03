import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/providers/auth_provider.dart';
import 'package:earth_nova/screens/loading_screen.dart';
import 'package:earth_nova/screens/login_screen.dart';
import 'package:earth_nova/services/auth_service.dart';
import 'package:earth_nova/services/mock_auth_service.dart';
import 'package:earth_nova/services/observability_service.dart';
import 'package:earth_nova/services/supabase_auth_service.dart';
import 'package:earth_nova/services/supabase_bootstrap.dart';
import 'package:earth_nova/shared/app_theme.dart';
import 'package:earth_nova/widgets/tab_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sessionId = const Uuid().v4();

  final supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  SupabaseClient? supabaseClient;
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await SupabaseBootstrap.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      supabaseClient = Supabase.instance.client;
    } catch (e) {
      debugPrint('[Main] Supabase init failed: $e');
    }
  }

  final obs = ObservabilityService(
    sessionId: sessionId,
    client: supabaseClient,
  );
  obs.startPeriodicFlush();

  obs.log('app.cold_start', 'lifecycle', data: {
    'version': const String.fromEnvironment('APP_VERSION', defaultValue: 'dev'),
    'platform': 'web',
  });

  if (supabaseClient != null) {
    obs.log('supabase.init_success', 'infrastructure');
  } else {
    obs.log('supabase.init_failure', 'infrastructure',
        data: {'error': 'No SUPABASE_URL provided'});
  }

  final AuthService authService = supabaseClient != null
      ? SupabaseAuthService(client: supabaseClient, observability: obs)
      : MockAuthService();

  FlutterError.onError = (details) {
    obs.logError(details.exception, details.stack ?? StackTrace.current,
        event: 'app.crash.flutter');
  };

  runZonedGuarded(
    () => runApp(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          observabilityProvider.overrideWithValue(obs),
        ],
        child: const _EarthNovaApp(),
      ),
    ),
    (error, stack) {
      obs.logError(error, stack, event: 'app.crash.unhandled');
    },
  );
}

class _EarthNovaApp extends ConsumerStatefulWidget {
  const _EarthNovaApp();

  @override
  ConsumerState<_EarthNovaApp> createState() => _EarthNovaAppState();
}

class _EarthNovaAppState extends ConsumerState<_EarthNovaApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'EarthNova',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: authState.when(
        loading: () => const LoadingScreen(),
        unauthenticated: () => const LoginScreen(),
        authenticated: (_) => const TabShell(),
        error: (_) => const LoginScreen(),
      ),
    );
  }
}
