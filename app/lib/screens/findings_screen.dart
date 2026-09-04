import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/scan_result.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class FindingsScreen extends StatelessWidget {
  const FindingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.t;
    final scan = state.currentScan;

    return Scaffold(
      backgroundColor: NetraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            NsHeader(
              leading: NsBackButton(onPressed: state.backToResults),
              title: t['findingsTitle'],
            ),
            if (scan == null)
              const Expanded(child: SizedBox())
            else
              NsBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NsListRow(
                      child: Row(
                        children: [
                          Expanded(child: Text(t['dme'], style: const TextStyle(fontSize: 14))),
                          NsTag(
                            scan.dmePresent ? t['present'] : t['absent'],
                            style: scan.dmePresent ? NsTagStyle.accent : NsTagStyle.outline,
                          ),
                        ],
                      ),
                    ),
                    for (final finding in ocularReport)
                      NsListRow(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(t[ocularStringKey[finding]!], style: const TextStyle(fontSize: 14)),
                            ),
                            NsTag(
                              '${((scan.ocularProbs[finding] ?? 0) * 100).round()}%',
                              style: (scan.ocularProbs[finding] ?? 0) >= ocularThreshold
                                  ? NsTagStyle.accent
                                  : NsTagStyle.neutral,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: NetraSpace.s4),
                    Text(t['estimateNote'], style: const TextStyle(fontSize: 12, color: NetraColors.inkMuted)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
