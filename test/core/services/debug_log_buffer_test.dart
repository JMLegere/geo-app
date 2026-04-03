import 'package:earth_nova/core/services/debug_log_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogLevel.classify', () {
    test('classifies [CRASH] as error', () {
      expect(LogLevel.classify('[CRASH] process died'), LogLevel.error);
    });

    test('classifies "failed" as error', () {
      expect(LogLevel.classify('sync failed after 3 attempts'), LogLevel.error);
    });

    test('classifies "error:" as error', () {
      expect(LogLevel.classify('error: connection refused'), LogLevel.error);
    });

    test('classifies "corrupt" as error', () {
      expect(LogLevel.classify('database corrupt on read'), LogLevel.error);
    });

    test('classifies "timeout" as warning', () {
      expect(LogLevel.classify('request timeout after 30s'), LogLevel.warning);
    });

    test('classifies "rejected" as warning', () {
      expect(LogLevel.classify('write rejected by server'), LogLevel.warning);
    });

    test('classifies "retry" as warning', () {
      expect(LogLevel.classify('retry attempt 2'), LogLevel.warning);
    });

    test('classifies "stale" as warning', () {
      expect(LogLevel.classify('seed is stale, pausing'), LogLevel.warning);
    });

    test('classifies [AUTH] as info', () {
      expect(LogLevel.classify('[AUTH] signed in anonymously'), LogLevel.info);
    });

    test('classifies [NAV] as info', () {
      expect(LogLevel.classify('[NAV] navigating to map'), LogLevel.info);
    });

    test('classifies [RENDER-STALL] as info', () {
      expect(
          LogLevel.classify('[RENDER-STALL] frame took 80ms'), LogLevel.info);
    });

    test('classifies ordinary text as debug', () {
      expect(LogLevel.classify('loading cell v_10_20'), LogLevel.debug);
    });

    test('classifies [JS-ERROR] as error', () {
      expect(LogLevel.classify('[JS-ERROR] TypeError: cannot read property'),
          LogLevel.error);
    });

    test('classifies [JS-REJECTION] as error', () {
      expect(LogLevel.classify('[JS-REJECTION] unhandled promise rejection'),
          LogLevel.error);
    });
  });

  group('DebugLogBuffer', () {
    setUp(() {
      final buf = DebugLogBuffer.instance;
      buf.clear();
      buf.drainPending();
      buf.minLevel = LogLevel.debug;
      buf.onCrash = null;
      buf.onAuthEvent = null;
    });

    test('adds line with timestamp prefix', () {
      final buf = DebugLogBuffer.instance;
      buf.add('hello world');
      expect(buf.lines.last, contains('hello world'));
    });

    test('evicts oldest when at maxLines capacity', () {
      final buf = DebugLogBuffer.instance;
      for (var i = 0; i < DebugLogBuffer.maxLines + 1; i++) {
        buf.add('line $i');
      }
      expect(buf.length, DebugLogBuffer.maxLines);
      // The very first line ('line 0') should have been evicted
      expect(buf.lines.first, isNot(contains('line 0')));
      expect(buf.lines.first, contains('line 1'));
    });

    test('fires onCrash callback on [CRASH] line', () {
      final buf = DebugLogBuffer.instance;
      var fired = false;
      buf.onCrash = () => fired = true;
      buf.add('[CRASH] fatal error occurred');
      expect(fired, isTrue);
    });

    test('fires onAuthEvent callback on [AUTH] line', () {
      final buf = DebugLogBuffer.instance;
      var fired = false;
      buf.onAuthEvent = () => fired = true;
      buf.add('[AUTH] user signed in');
      expect(fired, isTrue);
    });

    test('fires onAuthEvent callback on [NAV] line', () {
      final buf = DebugLogBuffer.instance;
      var fired = false;
      buf.onAuthEvent = () => fired = true;
      buf.add('[NAV] tab changed');
      expect(fired, isTrue);
    });

    test('crash callback fires even when line is at error level', () {
      final buf = DebugLogBuffer.instance;
      buf.minLevel = LogLevel.error;
      var fired = false;
      buf.onCrash = () => fired = true;
      buf.add('[CRASH] fatal');
      expect(fired, isTrue);
    });

    test('filters lines below minLevel', () {
      final buf = DebugLogBuffer.instance;
      buf.minLevel = LogLevel.warning;
      buf.add('loading species data'); // debug level
      expect(buf.lines, isEmpty);
    });

    test('keeps lines at or above minLevel', () {
      final buf = DebugLogBuffer.instance;
      buf.minLevel = LogLevel.warning;
      buf.add('retry attempt 1'); // warning level
      expect(buf.lines.length, 1);
    });

    test('[API] lines bypass minLevel filter', () {
      final buf = DebugLogBuffer.instance;
      buf.minLevel = LogLevel.error; // strictest filter
      buf.add('[API] → POST upsert profiles');
      buf.add('[API] ← 200 upsert profiles 45ms');
      expect(buf.lines.length, 2);
    });

    test('drainPending returns accumulated lines and clears pending', () {
      final buf = DebugLogBuffer.instance;
      buf.add('retry 1');
      buf.add('retry 2');
      buf.add('retry 3');
      final drained = buf.drainPending();
      expect(drained.length, 3);
      final second = buf.drainPending();
      expect(second, isEmpty);
    });

    test('notifies listeners on add', () {
      final buf = DebugLogBuffer.instance;
      var callCount = 0;
      void listener() => callCount++;
      buf.addListener(listener);
      addTearDown(() => buf.removeListener(listener));
      buf.add('retry something');
      expect(callCount, 1);
    });

    test('removeListener stops notifications', () {
      final buf = DebugLogBuffer.instance;
      var callCount = 0;
      void listener() => callCount++;
      buf.addListener(listener);
      buf.removeListener(listener);
      buf.add('retry something');
      expect(callCount, 0);
    });

    test('clear empties buffer', () {
      final buf = DebugLogBuffer.instance;
      buf.add('retry a');
      buf.add('retry b');
      buf.clear();
      expect(buf.lines, isEmpty);
    });

    test('[JS-ERROR] triggers onCrash callback', () {
      final buffer = DebugLogBuffer.instance;
      buffer.minLevel = LogLevel.debug;
      var crashFired = false;
      buffer.onCrash = () => crashFired = true;
      buffer.add('[JS-ERROR] WebGL context lost');
      expect(crashFired, isTrue);
      buffer.onCrash = null;
    });

    test('[JS-REJECTION] triggers onCrash callback', () {
      final buffer = DebugLogBuffer.instance;
      buffer.minLevel = LogLevel.debug;
      var crashFired = false;
      buffer.onCrash = () => crashFired = true;
      buffer.add('[JS-REJECTION] unhandled promise rejection');
      expect(crashFired, isTrue);
      buffer.onCrash = null;
    });

    test('[JS-ERROR] always passes severity filter', () {
      final buffer = DebugLogBuffer.instance;
      final before = buffer.lines.length;
      buffer.minLevel =
          LogLevel.warning; // JS-ERROR is error so it passes anyway
      buffer.add('[JS-ERROR] something broke');
      expect(buffer.lines.length, greaterThan(before));
    });
  });
}
