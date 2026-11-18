import 'package:flutter/material.dart';

enum IndicatorState { idle, working, success, error }

/// Icon + label row, used for the connection status and for each operation step.
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({super.key, required this.state, required this.label});

  final IndicatorState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget icon = switch (state) {
      IndicatorState.idle => Icon(Icons.radio_button_unchecked, color: scheme.outline),
      IndicatorState.working => const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
      IndicatorState.success => const Icon(Icons.check_circle, color: Colors.green),
      IndicatorState.error => Icon(Icons.error, color: scheme.error),
    };
    return Row(children: [
      SizedBox(width: 24, height: 24, child: Center(child: icon)),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
    ]);
  }
}
