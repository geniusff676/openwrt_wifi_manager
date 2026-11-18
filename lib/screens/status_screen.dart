import 'package:flutter/material.dart' hide RouterConfig;

import '../models/router_config.dart';
import '../services/openwrt_service.dart';
import '../services/ssh_service.dart';
import '../widgets/status_indicator.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({
    super.key,
    required this.config,
    required this.ssid,
    required this.password,
    required this.createSsh,
  });

  final RouterConfig config;
  final String ssid;
  final String password;
  final SshService Function() createSsh;

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  static const _labels = [
    'Connecting to router',
    'Authenticating SSH session',
    'Updating Wi-Fi SSID',
    'Updating Wi-Fi password',
    'Committing configuration',
    'Reloading wireless service',
    'Configuration completed',
  ];

  final _states = List.filled(_labels.length, IndicatorState.idle);
  int _current = 0;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  void _onStep(ApplyStep step) {
    if (!mounted) return;
    setState(() {
      _current = step.index;
      for (var i = 0; i < step.index; i++) {
        _states[i] = IndicatorState.success;
      }
      _states[step.index] = step == ApplyStep.done ? IndicatorState.success : IndicatorState.working;
    });
  }

  Future<void> _run() async {
    try {
      await OpenWrtService(widget.createSsh()).applyWifi(widget.config, widget.ssid, widget.password, _onStep);
      if (mounted) setState(() => _finished = true);
    } on RouterException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Something went wrong. Please try again.');
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _states[_current] = IndicatorState.error;
      _error = msg;
      _finished = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _finished,
      child: Scaffold(
        appBar: AppBar(title: const Text('Operation Status'), automaticallyImplyLeading: false),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (var i = 0; i < _labels.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: StatusIndicator(state: _states[i], label: _labels[i]),
                ),
              const SizedBox(height: 16),
              if (_error != null)
                Card(
                  color: scheme.errorContainer,
                  child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
                )
              else if (_finished)
                Card(
                  color: scheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Done! Your internal Wi-Fi is now "${widget.ssid}". '
                        'Reconnect your devices with the new password.'),
                  ),
                ),
              const SizedBox(height: 16),
              if (_finished)
                FilledButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: Text(_error == null ? 'Done' : 'Back to start'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
