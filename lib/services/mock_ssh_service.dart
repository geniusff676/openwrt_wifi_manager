import '../models/router_config.dart';
import 'ssh_service.dart';

/// In-memory fake router for testing without hardware. Enable with `--dart-define=MOCK=true`.
/// Use host 0.0.0.0 to simulate "unreachable" and password "wrong" to simulate bad credentials.
class MockSshService implements SshService {
  MockSshService({this.delay = const Duration(milliseconds: 500)});

  final Duration delay;
  final _live = <String, String>{
    'ssid': 'Old_Internal_WiFi',
    'key': 'OldPassword123',
    'mode': 'ap',
    'encryption': 'psk2',
  };
  final _pending = <String, String>{};
  late RouterConfig _cfg;

  String? liveValue(String option) => _live[option];

  @override
  Future<void> connect(RouterConfig config) async {
    _cfg = config;
    await Future<void>.delayed(delay);
    if (config.host == '0.0.0.0') {
      throw const RouterException(RouterErrorKind.unreachable, 'Cannot reach the router (mock).');
    }
  }

  @override
  Future<void> authenticate() async {
    await Future<void>.delayed(delay);
    if (_cfg.password == 'wrong') {
      throw const RouterException(RouterErrorKind.authFailed, 'Incorrect SSH username or password.');
    }
  }

  @override
  Future<SshResult> run(String cmd) async {
    await Future<void>.delayed(delay);
    const ok = SshResult('', '', 0);

    final get = RegExp(r'^uci -q get wireless\.(\w+)(?:\.(\w+))?$').firstMatch(cmd);
    if (get != null) {
      if (get[1] != 'internal_wifi') return const SshResult('', '', 1);
      if (get[2] == null) return const SshResult('wifi-iface\n', '', 0);
      final v = _pending[get[2]] ?? _live[get[2]];
      return v == null ? const SshResult('', '', 1) : SshResult('$v\n', '', 0);
    }

    final set = RegExp(r"^uci set wireless\.internal_wifi\.(\w+)='((?:[^']|'\\'')*)'$").firstMatch(cmd);
    if (set != null) {
      _pending[set[1]!] = set[2]!.replaceAll(r"'\''", "'");
      return ok;
    }

    switch (cmd) {
      case 'uci commit wireless':
        _live.addAll(_pending);
        _pending.clear();
        return ok;
      case 'uci revert wireless':
        _pending.clear();
        return ok;
      case 'wifi reload':
        return ok;
    }
    return SshResult('', 'sh: unknown command', 127);
  }

  @override
  Future<void> close() async {}
}
