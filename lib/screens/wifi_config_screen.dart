import 'package:flutter/material.dart';

import '../models/router_config.dart';
import '../services/ssh_service.dart';
import '../utils/validators.dart';
import '../widgets/custom_button.dart';
import 'status_screen.dart';

class WifiConfigScreen extends StatefulWidget {
  const WifiConfigScreen({super.key, required this.config, required this.createSsh});

  final RouterConfig config;
  final SshService Function() createSsh;

  @override
  State<WifiConfigScreen> createState() => _WifiConfigScreenState();
}

class _WifiConfigScreenState extends State<WifiConfigScreen> {
  final _form = GlobalKey<FormState>();
  final _ssid = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;

  void _apply() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StatusScreen(
        config: widget.config,
        ssid: _ssid.text,
        password: _pass.text,
        createSsh: widget.createSsh,
      ),
    ));
  }

  @override
  void dispose() {
    _ssid.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi Configuration')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Internal Wi-Fi Configuration', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Devices on the internal Wi-Fi will briefly disconnect and must rejoin with the new password. '
                'This management Wi-Fi is not changed.'),
            const SizedBox(height: 20),
            Form(
              key: _form,
              child: Column(children: [
                TextFormField(
                  controller: _ssid,
                  decoration: const InputDecoration(labelText: 'New Wi-Fi SSID', border: OutlineInputBorder()),
                  validator: Validators.ssid,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pass,
                  obscureText: !_show,
                  decoration: InputDecoration(
                    labelText: 'New Wi-Fi password',
                    helperText: '8-63 characters',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _show = !_show),
                    ),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  obscureText: !_show,
                  decoration: const InputDecoration(labelText: 'Confirm password', border: OutlineInputBorder()),
                  validator: (v) => Validators.confirm(v, _pass.text),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            CustomButton(label: 'Apply Configuration', icon: Icons.wifi, onPressed: _apply),
          ],
        ),
      ),
    );
  }
}
