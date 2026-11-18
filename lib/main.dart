import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/mock_ssh_service.dart';
import 'services/secure_store.dart';
import 'services/ssh_service.dart';

/// Build with `--dart-define=MOCK=true` to run against a fake in-memory router.
const useMock = bool.fromEnvironment('MOCK');

final _navKey = GlobalKey<NavigatorState>();
final _store = SecureStore();

SshService _createSsh() => useMock ? MockSshService() : DartSshService(_store, _confirmHostKey);

/// First-use prompt: lets the customer/installer approve the router's SSH key fingerprint.
Future<bool> _confirmHostKey(String host, String fingerprint) async {
  final ctx = _navKey.currentState?.overlay?.context;
  if (ctx == null) return false;
  final ok = await showDialog<bool>(
    context: ctx,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('Trust this router?'),
      content: Text('First connection to $host.\n\nSecurity key:\n$fingerprint\n\n'
          'Only continue if you are connected to your own router\'s Wi-Fi.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Trust')),
      ],
    ),
  );
  return ok ?? false;
}

void main() => runApp(const WifiManagerApp());

class WifiManagerApp extends StatelessWidget {
  const WifiManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenWrt Wi-Fi Manager',
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: HomeScreen(createSsh: _createSsh, store: _store),
    );
  }
}
