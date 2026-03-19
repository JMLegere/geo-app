import 'package:http/http.dart';

import 'package:earth_nova/core/services/observability_buffer.dart';

/// HTTP client decorator that emits [api_request] and [api_response]
/// observability events for every Supabase network call.
///
/// Injected into [Supabase.initialize(httpClient:)] so all REST,
/// Edge Function, and Auth calls are automatically instrumented
/// without per-site boilerplate.
class ObservableHttpClient extends BaseClient {
  ObservableHttpClient([Client? inner]) : _inner = inner ?? Client();

  final Client _inner;

  /// Paths that should NOT be logged to avoid circular logging
  /// (the observability buffer itself writes to app_events).
  static const _skipPaths = {'/rest/v1/app_events', '/rest/v1/app_logs'};

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final path = request.url.path;
    if (_skipPaths.any(path.endsWith)) {
      return _inner.send(request);
    }

    final operation = _parseOperation(request);
    final target = _parseTarget(request);

    ObservabilityBuffer.instance?.event('api_request', {
      'method': request.method,
      'operation': operation,
      'target': target,
    });

    final sw = Stopwatch()..start();
    try {
      final response = await _inner.send(request);
      sw.stop();

      ObservabilityBuffer.instance?.event('api_response', {
        'method': request.method,
        'operation': operation,
        'target': target,
        'status_code': response.statusCode,
        'duration_ms': sw.elapsedMilliseconds,
        'status': response.statusCode < 400 ? 'ok' : 'error',
      });

      return response;
    } catch (e) {
      sw.stop();

      ObservabilityBuffer.instance?.event('api_response', {
        'method': request.method,
        'operation': operation,
        'target': target,
        'duration_ms': sw.elapsedMilliseconds,
        'status': 'error',
        'error': '$e',
      });

      rethrow;
    }
  }

  /// Derive a human-readable operation from method + path.
  ///
  /// REST:   POST /rest/v1/profiles      → "upsert"
  /// RPC:    POST /rest/v1/rpc/func_name → "rpc:func_name"
  /// Edge:   POST /functions/v1/fn_name  → "edge:fn_name"
  /// Auth:   POST /auth/v1/token         → "auth:token"
  String _parseOperation(BaseRequest request) {
    final path = request.url.path;

    if (path.contains('/functions/v1/')) {
      final fn = path.split('/functions/v1/').last.split('?').first;
      return 'edge:$fn';
    }

    if (path.contains('/rpc/')) {
      final fn = path.split('/rpc/').last.split('?').first;
      return 'rpc:$fn';
    }

    if (path.contains('/auth/v1/')) {
      final segment = path.split('/auth/v1/').last.split('?').first;
      return 'auth:$segment';
    }

    // REST: map HTTP method to semantic operation
    return switch (request.method) {
      'GET' => 'select',
      'POST' => 'upsert',
      'PATCH' => 'update',
      'PUT' => 'upsert',
      'DELETE' => 'delete',
      _ => request.method.toLowerCase(),
    };
  }

  /// Extract the target resource (table name, function name, auth endpoint).
  String _parseTarget(BaseRequest request) {
    final path = request.url.path;

    if (path.contains('/functions/v1/')) {
      return path.split('/functions/v1/').last.split('?').first;
    }

    if (path.contains('/rpc/')) {
      return path.split('/rpc/').last.split('?').first;
    }

    if (path.contains('/auth/v1/')) {
      return 'auth';
    }

    if (path.contains('/rest/v1/')) {
      return path.split('/rest/v1/').last.split('?').first;
    }

    // Storage or unknown
    return path.split('/').last.split('?').first;
  }
}
