// Tests for the fun-facts generation throttle guard.
//
// `funFactsGenerationDue` is a @visibleForTesting top-level function in
// game_coordinator_provider.dart that decides whether the generate-fun-facts
// edge function should be triggered this session.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:earth_nova/core/state/game_coordinator_provider.dart';

void main() {
  group('funFactsGenerationDue', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns true when never triggered (no stored timestamp)', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(funFactsGenerationDue(prefs), isTrue);
    });

    test('returns false when triggered less than 6 hours ago', () async {
      final prefs = await SharedPreferences.getInstance();
      // Set timestamp to 1 hour ago.
      final oneHourAgo = DateTime.now().millisecondsSinceEpoch -
          const Duration(hours: 1).inMilliseconds;
      await prefs.setInt('fun_facts_last_generated', oneHourAgo);

      expect(funFactsGenerationDue(prefs), isFalse);
    });

    test('returns false when triggered exactly 5 hours ago', () async {
      final prefs = await SharedPreferences.getInstance();
      final fiveHoursAgo = DateTime.now().millisecondsSinceEpoch -
          const Duration(hours: 5).inMilliseconds;
      await prefs.setInt('fun_facts_last_generated', fiveHoursAgo);

      expect(funFactsGenerationDue(prefs), isFalse);
    });

    test('returns true when triggered exactly 6 hours ago', () async {
      final prefs = await SharedPreferences.getInstance();
      final sixHoursAgo = DateTime.now().millisecondsSinceEpoch -
          const Duration(hours: 6).inMilliseconds;
      await prefs.setInt('fun_facts_last_generated', sixHoursAgo);

      expect(funFactsGenerationDue(prefs), isTrue);
    });

    test('returns true when triggered more than 6 hours ago', () async {
      final prefs = await SharedPreferences.getInstance();
      final twentyHoursAgo = DateTime.now().millisecondsSinceEpoch -
          const Duration(hours: 20).inMilliseconds;
      await prefs.setInt('fun_facts_last_generated', twentyHoursAgo);

      expect(funFactsGenerationDue(prefs), isTrue);
    });
  });
}
