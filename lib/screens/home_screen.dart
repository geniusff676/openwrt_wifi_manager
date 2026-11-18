import 'package:flutter/material.dart';

import '../models/router_config.dart';
import '../services/openwrt_service.dart';
import '../services/secure_store.dart';
import '../services/ssh_service.dart';
import '../utils/validators.dart';
import '../widgets/custom_button.dart';
import '../widgets/status_indicator.dart';
import 'wifi_config_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.createSsh, required this.store});

  final SshService Function() createSsh;
  final SecureStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _form = GlobalKey<FormState>();
  final _host = TextEditingController(text: '192.168.1.1');
  final _port = TextEditingController(text: '22');
  final _user = TextEditingController(text: 'root');
  final _pass = TextEditingController();
  bool _show = false;
  IndicatorState _state = IndicatorState.idle;
  String _msg = 'Not connected';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final h = await widget.store.read('host');
    final p = await widget.store.read('port');
    final u = await widget.store.read('user');
    if (!mounted) return;
    setState(() {
      if (h != null) _host.text = h;
      if (p != null) _port.text = p;
      if (u != null) _user.text = u;
    });
  }

  Future<void> _connect() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final cfg = RouterConfig(
      host: _host.text.trim(),
      port: int.parse(_port.text.trim()),
      username: _user.text.trim(),
      password: _pass.text,
    );
    setState(() {
      _state = IndicatorState.working;
      _msg = 'Connecting to ${cfg.host}…';
    });
    try {
      await OpenWrtService(widget.createSsh()).verify(cfg);
      await widget.store.write('host', cfg.host);
      await widget.store.write('port', '${cfg.port}');
      await widget.store.write('user', cfg.username);
      if (!mounted) return;
      setState(() {
        _state = IndicatorState.success;
        _msg = 'Connected to ${cfg.host}';
      });
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => WifiConfigScreen(config: cfg, createSsh: widget.createSsh),
      ));
      if (mounted) setState(() {
        _state = IndicatorState.idle;
        _msg = 'Not connected';
      });
    } on RouterException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Something went wrong while connecting. Please try again.');
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _state = IndicatorState.error;
      _msg = msg;
    });
  }

  Future<void> _resetKey() async {
    if (Validators.host(_host.text) != null || Validators.port(_port.text) != null) return;
    await widget.store.delete(SecureStore.hostKeyId(_host.text.trim(), int.parse(_port.text.trim())));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trusted key cleared for this router')));
    }
  }

  @override
  void dispose() {
    for (final c in [_host, _port, _user, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OpenWrt Wi-Fi Manager')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Connect to your router', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('First join the router\'s management Wi-Fi on this phone.'),
            const SizedBox(height: 20),
            Form(
              key: _form,
              child: Column(children: [
                TextFormField(
                  controller: _host,
                  decoration: const InputDecoration(labelText: 'Router IP address', border: OutlineInputBorder()),
                  keyboardType: TextInputType.url,
                  validator: Validators.host,
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _port,
                      decoration: const InputDecoration(labelText: 'SSH port', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: Validators.port,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _user,
                      decoration: const InputDecoration(labelText: 'SSH username', border: OutlineInputBorder()),
                      validator: Validators.username,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pass,
                  obscureText: !_show,
                  decoration: InputDecoration(
                    labelText: 'SSH password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _show = !_show),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter the SSH password' : null,
                ),
              ]),
            ),
            const SizedBox(height: 20),
            CustomButton(
              label: 'Connect to Router',
              icon: Icons.router,
              loading: _state == IndicatorState.working,
              onPressed: _connect,
            ),
            const SizedBox(height: 16),
            StatusIndicator(state: _state, label: _msg),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _resetKey, child: const Text('Reset trusted key')),
            ),
          ],
        ),
      ),
    );
  }
}
