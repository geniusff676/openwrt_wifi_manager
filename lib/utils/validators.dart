/// Input validation. Every value that ends up in a router command goes through here,
/// and is additionally shell-quoted in OpenWrtService (defence in depth).
class Validators {
  static final _printableAscii = RegExp(r'^[\x20-\x7E]+$');
  // Characters with special meaning to a POSIX shell / UCI quoting.
  static final _unsafe = RegExp(r'''['"`\\$]''');
  static final _host = RegExp(r'^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$');
  static final _user = RegExp(r'^[A-Za-z_][A-Za-z0-9_-]{0,31}$');

  static const unsafeChars = '\' " ` \\ \$';

  static String? ssid(String? v) {
    if (v == null || v.trim().isEmpty) return 'SSID cannot be empty';
    if (v.length > 32) return 'SSID must be at most 32 characters';
    if (v != v.trim()) return 'SSID cannot start or end with a space';
    if (!_printableAscii.hasMatch(v)) return 'SSID may only use standard keyboard characters';
    if (_unsafe.hasMatch(v)) return 'SSID cannot contain: $unsafeChars';
    return null;
  }

  /// WPA2-PSK passphrase: 8-63 printable ASCII characters.
  // shortcut: 64-char hex PSKs are not accepted, add if a deployment needs them.
  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password cannot be empty';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (v.length > 63) return 'Password must be at most 63 characters';
    if (!_printableAscii.hasMatch(v)) return 'Password may only use standard keyboard characters';
    if (_unsafe.hasMatch(v)) return 'Password cannot contain: $unsafeChars';
    return null;
  }

  static String? confirm(String? v, String password) =>
      v == password ? null : 'Passwords do not match';

  static String? host(String? v) =>
      (v != null && _host.hasMatch(v.trim())) ? null : 'Enter a valid IP address or hostname';

  static String? port(String? v) {
    final p = int.tryParse(v?.trim() ?? '');
    return (p != null && p >= 1 && p <= 65535) ? null : 'Port must be 1-65535';
  }

  static String? username(String? v) =>
      (v != null && _user.hasMatch(v.trim())) ? null : 'Enter a valid username';
}
