import '../models/router_config.dart';
import '../utils/validators.dart';
import 'ssh_service.dart';

/// Progress steps, in order. `index` maps directly onto the status screen rows.
enum ApplyStep { connecting, authenticating, ssid, password, commit, reload, done }

/// UCI logic for changing the internal Wi-Fi. Knows nothing about UI or the SSH library.
class OpenWrtService {
  OpenWrtService(this._ssh, {this.section = 'internal_wifi'});

  final SshService _ssh;
  final String section;

  // Never touch the default/management interface (OpenWrt's stock sections are default_radioN).
  // shortcut: name-based guard only; a production build should pin the section per router.
  static final _blocked = RegExp(r'^(default_radio\d+|mgmt\w*|management\w*)$', caseSensitive: false);
  static final _sectionName = RegExp(r'^[A-Za-z0-9_]+$');

  /// POSIX single-quote escaping: the result is always one literal shell word.
  static String shellQuote(String s) => "'${s.replaceAll("'", r"'\''")}'";

  /// Connect, log in and check the target section, without changing anything.
  Future<void> verify(RouterConfig cfg) => _session(cfg, null, () async {});

  Future<void> applyWifi(
    RouterConfig cfg,
    String ssid,
    String password,
    void Function(ApplyStep) onStep,
  ) async {
    if (Validators.ssid(ssid) != null || Validators.password(password) != null) {
      throw const RouterException(RouterErrorKind.invalidInput, 'The SSID or password is not valid.');
    }

    await _session(cfg, onStep, () async {
      onStep(ApplyStep.ssid);
      await _set('ssid', ssid);

      onStep(ApplyStep.password);
      await _set('key', password);

      onStep(ApplyStep.commit);
      final commit = await _ssh.run('uci commit wireless');
      if (commit.exitCode != 0 || await _get('ssid') != ssid) {
        await _revert();
        throw const RouterException(
            RouterErrorKind.commitFailure, 'The router could not save the new settings. Nothing was changed.');
      }

      onStep(ApplyStep.reload);
      try {
        final r = await _ssh.run('wifi reload');
        if (r.exitCode != 0) {
          throw const RouterException(RouterErrorKind.reloadFailure,
              'Settings were saved, but the router failed to reload Wi-Fi. Try again or reboot the router.');
        }
      } on RouterException catch (e) {
        // A dropped session after the commit is expected while Wi-Fi restarts: the change is already saved.
        if (e.kind != RouterErrorKind.connectionLost) rethrow;
      }
      onStep(ApplyStep.done);
    });
  }

  Future<void> _session(RouterConfig cfg, void Function(ApplyStep)? onStep, Future<void> Function() body) async {
    try {
      onStep?.call(ApplyStep.connecting);
      await _ssh.connect(cfg);
      onStep?.call(ApplyStep.authenticating);
      await _ssh.authenticate();
      await _inspect();
      await body();
    } finally {
      await _ssh.close();
    }
  }

  /// Confirms the target exists, is an AP wifi-iface, is encrypted and is not the management network.
  Future<void> _inspect() async {
    if (!_sectionName.hasMatch(section) || _blocked.hasMatch(section)) {
      throw const RouterException(RouterErrorKind.sectionNotFound, 'This Wi-Fi network cannot be changed from the app.');
    }
    final type = await _ssh.run('uci -q get wireless.$section');
    if (type.exitCode == 127) {
      throw const RouterException(RouterErrorKind.sectionNotFound, 'This device does not look like an OpenWrt router.');
    }
    if (type.exitCode != 0 || type.stdout.trim() != 'wifi-iface') {
      throw RouterException(RouterErrorKind.sectionNotFound,
          'The internal Wi-Fi ("$section") was not found on this router. Please contact support.');
    }
    final mode = await _get('mode');
    final enc = await _get('encryption') ?? '';
    if (mode != 'ap' || !(enc.startsWith('psk') || enc.startsWith('sae'))) {
      throw const RouterException(RouterErrorKind.sectionNotFound,
          'The internal Wi-Fi is not a password-protected access point. Please contact support.');
    }
  }

  Future<String?> _get(String option) async {
    final r = await _ssh.run('uci -q get wireless.$section.$option');
    return r.exitCode == 0 ? r.stdout.trim() : null;
  }

  Future<void> _set(String option, String value) async {
    final r = await _ssh.run('uci set wireless.$section.$option=${shellQuote(value)}');
    if (r.exitCode != 0) {
      await _revert();
      throw RouterException(RouterErrorKind.uciFailure, 'The router rejected the new Wi-Fi $option. Nothing was changed.');
    }
  }

  // Drop uncommitted changes so a half-applied update never lingers in UCI.
  Future<void> _revert() async {
    try {
      await _ssh.run('uci revert wireless');
    } on RouterException catch (_) {}
  }
}
