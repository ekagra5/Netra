import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/scan_result.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tab_shell.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.t;

    return Scaffold(
      backgroundColor: NetraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            NsHeader(leading: const NsBrandMark(letter: 'N'), title: t['queueTitle']),
            NsBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NsCard(
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: NetraColors.red700),
                        const SizedBox(width: NetraSpace.s3),
                        Expanded(
                          child: Text(t['queueBanner'], style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: NetraSpace.s4),
                  if (state.queue.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: NetraSpace.s4),
                      child: Text(t['noQueue'], style: const TextStyle(color: NetraColors.inkMuted)),
                    )
                  else
                    for (final scan in state.queue) _QueueRow(scan: scan, t: t),
                  const SizedBox(height: NetraSpace.s4),
                  Text(
                    '${state.queue.length} ${t['storageNote']}',
                    style: const TextStyle(fontSize: 12, color: NetraColors.inkMuted),
                  ),
                ],
              ),
            ),
            if (state.queue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(NetraSpace.s4),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: state.simulateSync, child: Text(t['syncNow'])),
                ),
              ),
            const NsTabBar(),
          ],
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final ScanResult scan;
  final dynamic t;
  const _QueueRow({required this.scan, required this.t});

  @override
  Widget build(BuildContext context) {
    final statusKey = switch (scan.syncStatus) {
      SyncStatus.queued => 'queued',
      SyncStatus.syncing => 'syncing',
      SyncStatus.failed => 'failed',
      SyncStatus.synced => 'synced',
    };
    final style = scan.syncStatus == SyncStatus.failed
        ? NsTagStyle.accent
        : scan.syncStatus == SyncStatus.syncing
            ? NsTagStyle.outline
            : NsTagStyle.neutral;

    return NsListRow(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scan #${scan.id}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(
                  DateFormat('MMM d, HH:mm').format(scan.timestamp.toLocal()),
                  style: const TextStyle(fontSize: 12, color: NetraColors.inkMuted),
                ),
              ],
            ),
          ),
          NsTag(t[statusKey], style: style),
        ],
      ),
    );
  }
}
