import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../models/router_config.dart';
import 'secure_store.dart';

enum RouterErrorKind {
  unreachable,
  refused,
  authFailed,
  hostKeyMismatch,
  hostKeyRejected,
  sectionNotFound,
  invalidInput,
  uciFailure,
  commitFailure,
  reloadFailure,
  connectionLost,
}

/// Error carrying a message that is safe and understandable to show to the customer.
class RouterException implements Exception {
  const RouterException(this.kind, this.message);
  final RouterErrorKind kind;
  final String message;
  @override
  String toString() => message;
}

class SshResult {
  const SshResult(this.stdout, this.stderr, this.exitCode);
  final String stdout;
  final String stderr;
  final int exitCode;
}

/// Transport abstraction. Swap the implementation (mock, restricted account, ...) without touching UI or UCI logic.
abstract class SshService {
  Future<void> connect(RouterConfig config);
  Future<void> authenticate();
  Future<SshResult> run(String command);
  Future<void> close();
}

/// Asks the user whether to trust a host key seen for the first time.
typedef HostKeyConfirm = Future<bool> Function(String host, String fingerprint);

class DartSshService implements SshService {
  DartSshService(this._store, this._confirm);

  final SecureStore _store;
  final HostKeyConfirm _confirm;
  SSHClient? _client;
  late RouterConfig _cfg;
  bool _mismatch = false;
  bool _rejected = false;

  @override
  Future<void> connect(RouterConfig config) async {
    _cfg = config;
    try {
      final socket = await SSHSocket.connect(
        config.host,
        config.port,
        timeout: const Duration(seconds: 8),
      );
      _client = SSHClient(
        socket,
        username: config.username,
        onPasswordRequest: () => config.password,
        onVerifyHostKey: _verifyHostKey,
      );
    } on SocketException catch (e) {
      throw _mapSocket(e);
    } on TimeoutException {
      throw _unreachable();
    }
  }

  @override
  Future<void> authenticate() async {
    try {
      await _client!.authenticated;
    } catch (e) {
      if (_mismatch) {
        throw const RouterException(
          RouterErrorKind.hostKeyMismatch,
          'The router\'s security key has changed. This may be a different router or an '
          'attack. Use "Reset trusted key" only if you replaced the router.',
        );
      }
      if (_rejected) {
        throw const RouterException(RouterErrorKind.hostKeyRejected, 'Router was not trusted. Connection cancelled.');
      }
      if (e is SSHAuthError) {
        throw const RouterException(RouterErrorKind.authFailed, 'Incorrect SSH username or password.');
      }
      if (e is SocketException) throw _mapSocket(e);
      throw const RouterException(RouterErrorKind.connectionLost, 'Lost connection to the router during login.');
    }
  }

  // Trust-on-first-use: remember the key the first time (after user approval), then enforce it.
  Future<bool> _verifyHostKey(String type, Uint8List fingerprint) async {
    final fp = fingerprint.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
    final id = SecureStore.hostKeyId(_cfg.host, _cfg.port);
    final saved = await _store.read(id);
    if (saved == null) {
      final ok = await _confirm(_cfg.host, '$type $fp');
      if (ok) {
        await _store.write(id, '$type $fp');
      } else {
        _rejected = true;
      }
      return ok;
    }
    if (saved == '$type $fp') return true;
    _mismatch = true;
    return false;
  }

  @override
  Future<SshResult> run(String command) async {
    try {
      final session = await _client!.execute(command);
      final out = await Future.wait([
        utf8.decodeStream(session.stdout.cast<List<int>>()),
        utf8.decodeStream(session.stderr.cast<List<int>>()),
      ]).timeout(const Duration(seconds: 20));
      await session.done;
      return SshResult(out[0], out[1], session.exitCode ?? -1);
    } catch (_) {
      throw const RouterException(RouterErrorKind.connectionLost, 'Lost connection to the router.');
    }
  }

  @override
  Future<void> close() async => _client?.close();

  RouterException _unreachable() => const RouterException(
        RouterErrorKind.unreachable,
        'Cannot reach the router. Make sure your phone is connected to the router\'s '
        'management Wi-Fi and the IP address is correct.',
      );

  RouterException _mapSocket(SocketException e) => e.osError?.errorCode == 111
      ? const RouterException(
          RouterErrorKind.refused,
          'The router refused the SSH connection. Check the port and that SSH is enabled.')
      : _unreachable();
}
