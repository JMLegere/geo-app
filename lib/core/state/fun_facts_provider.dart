import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pre-loaded fun facts from SharedPreferences cache.
/// Overridden in ProviderScope with cached facts from previous session.
/// Empty list = no cached facts available (use hardcoded fallback).
final cachedFunFactsProvider = Provider<List<String>>((ref) => const []);
