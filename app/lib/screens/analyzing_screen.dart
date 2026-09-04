import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

class AnalyzingScreen extends StatelessWidget {
  const AnalyzingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppState>().t;

    return Scaffold(
      backgroundColor: NetraColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(NetraSpace.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t['analyzingTitle'], style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: NetraSpace.s4),
                const LinearProgressIndicator(
                  color: NetraColors.red600,
                  backgroundColor: NetraColors.bgMuted,
                  minHeight: 6,
                ),
                const SizedBox(height: NetraSpace.s5),
                _Step(t['stepPre'], done: true),
                const SizedBox(height: NetraSpace.s3),
                _Step(t['stepDetect'], done: true),
                const SizedBox(height: NetraSpace.s3),
                _Step(t['stepGrade'], done: false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String label;
  final bool done;
  const _Step(this.label, {required this.done});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        done
            ? const Icon(Icons.check_circle_outline, size: 18, color: NetraColors.red700)
            : const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: NetraColors.red700),
              ),
        const SizedBox(width: NetraSpace.s3),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
