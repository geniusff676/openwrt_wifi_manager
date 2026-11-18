import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Android Keystore-backed storage. Holds the router address/user and trusted SSH host keys.
/// The SSH password is intentionally never stored.
class SecureStore {
  final _s = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String hostKeyId(String host, int port) => 'hostkey:$host:$port';

  Future<String?> read(String key) => _s.read(key: key);
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  Future<void> delete(String key) => _s.delete(key: key);
}
