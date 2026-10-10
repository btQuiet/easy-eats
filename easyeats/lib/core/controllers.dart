import 'package:flutter/foundation.dart';
import 'models.dart';
import 'platform_client.dart';
import 'repository.dart';

class LoadController<T> extends ChangeNotifier {
  T? data;
  ApiException? error;
  bool loading = false;
  bool _disposed = false;
  int _request = 0;
  Future<void> load(Future<T> Function() fetch) async {
    if (_disposed) {
      return;
    }
    final request = ++_request;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await fetch();
      if (!_disposed && request == _request) data = result;
    } on ApiException catch (e) {
      if (!_disposed && request == _request) error = e;
    }
    if (!_disposed && request == _request) {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class SessionController extends ChangeNotifier {
  SessionController(
    this.repository, {
    Future<String?> Function(String)? readConfiguration,
    Future<void> Function(String, String?)? writeConfiguration,
  }) : _readConfiguration = readConfiguration ?? readSetting,
       _writeConfiguration = writeConfiguration ?? writeSetting {
    repository.api.onUnauthorized = expire;
  }
  final AppRepository repository;
  final Future<String?> Function(String) _readConfiguration;
  final Future<void> Function(String, String?) _writeConfiguration;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (repository.api.onUnauthorized == expire) {
      repository.api.onUnauthorized = null;
    }
    super.dispose();
  }

  Json? session;
  Json? capabilities;
  ApiException? error;
  bool restoring = true;
  bool busy = false;
  String get role => (session?['user'] as Json?)?['role'] as String? ?? '';
  bool get completed => session?['onboarding_completed'] == true;
  bool get signedIn => session != null;

  Future<void> restore() async {
    restoring = true;
    error = null;
    notifyListeners();
    try {
      await repository.api.configure();
      if (repository.api.baseUrl.isEmpty) {
        restoring = false;
        notifyListeners();
        return;
      }
      capabilities = await repository.get('/system/capabilities');
      if (await _readConfiguration('session_closed') != 'true') {
        try {
          session = await repository.get('/auth/session');
          repository.api.csrf = session!['csrf_token'] as String?;
        } on ApiException catch (e) {
          if (e.code != 'AUTH_REQUIRED') rethrow;
        }
      } else {
        session = null;
        repository.api.csrf = null;
        repository.api.token = null;
      }
    } on ApiException catch (e) {
      error = e;
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> authenticate(
    String alias,
    String password,
    bool register,
  ) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      session = await repository.write(
        'POST',
        register ? '/auth/register' : '/auth/login',
        {
          'alias': alias,
          'password': password,
          'transport': kIsWeb ? 'cookie' : 'bearer',
        },
      );
      repository.api.csrf = session!['csrf_token'] as String?;
      repository.api.token = session!['access_token'] as String?;
      if (!kIsWeb) await _writeConfiguration('token', repository.api.token);
      await _writeConfiguration('session_closed', null);
      capabilities = await repository.get('/system/capabilities');
    } on ApiException catch (e) {
      error = e;
    }
    busy = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    session = await repository.get('/auth/session');
    repository.api.csrf = session!['csrf_token'] as String?;
    notifyListeners();
  }

  void expire() {
    session = null;
    repository.api.token = null;
    repository.api.csrf = null;
    repository.api.clearOperations();
    _writeConfiguration('token', null);
    notifyListeners();
  }

  Future<void> logout() async {
    // HttpOnly cookies cannot be removed locally when the server is offline.
    // This flag prevents restoring that cookie after an explicit local logout.
    await _writeConfiguration('session_closed', 'true');
    try {
      await repository.api.request('POST', '/auth/logout');
    } on ApiException {
      // Always close the local session when LAN is unavailable.
    }
    expire();
  }

  Future<void> changeServer(String url) async {
    repository.api.validateServer(url);
    await logout();
    await repository.api.setServer(url);
    await restore();
  }
}
