import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../models/scan_result.dart';
import '../services/db_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tab_shell.dart';
import 'patient_scan_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<int, ScanResult> _latestScanByPatient = {};

  @override
  void initState() {
    super.initState();
    _loadLatestScans();
  }

  Future<void> _loadLatestScans() async {
    final scans = await DbService.instance.allScans();
    final latest = <int, ScanResult>{};
    for (final scan in scans) {
      latest.putIfAbsent(scan.patientId, () => scan);
    }
    if (mounted) setState(() => _latestScanByPatient = latest);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.t;
    final recentPatients = state.patients.take(4).toList();

    return Scaffold(
      backgroundColor: NetraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            NsHeader(
              leading: const NsBrandMark(letter: 'N'),
              title: t['appName'],
            ),
            NsBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['greeting'], style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(t['subGreeting'], style: const TextStyle(fontSize: 13, color: NetraColors.inkMuted)),
                  const SizedBox(height: NetraSpace.s4),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          value: '${state.patients.length}',
                          label: t['statScans'],
                        ),
                      ),
                      Container(width: 2, height: 48, color: NetraColors.divider),
                      Expanded(
                        child: _StatBox(
                          value: '${state.queue.length}',
                          label: t['statPending'],
                          accent: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NetraSpace.s5),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: state.startNewScan,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: Text(t['newScan']),
                    ),
                  ),
                  const SizedBox(height: NetraSpace.s5),
                  NsSectionLabel(t['recent']),
                  if (recentPatients.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: NetraSpace.s4),
                      child: Text(t['noHistory'], style: const TextStyle(color: NetraColors.inkMuted)),
                    )
                  else
                    ...recentPatients.map(
                      (p) => PatientScanTile(
                        patient: p,
                        scan: _latestScanByPatient[p.id],
                        onTap: () => state.openRecord(p.id!),
                      ),
                    ),
                ],
              ),
            ),
            const NsTabBar(),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final bool accent;
  const _StatBox({required this.value, required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NetraSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: accent ? NetraColors.red700 : NetraColors.ink,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: NetraColors.inkMuted)),
        ],
      ),
    );
  }
}

/// Shared helpers for turning a Patient/ScanResult pair into (tag text,
/// tag style) for a `NsTag` badge - used by home/history/record screens.
NsTagStyle tagStyleForGrade(int grade) {
  if (grade >= 3) return NsTagStyle.accent;
  if (grade == 0) return NsTagStyle.outline;
  return NsTagStyle.neutral;
}

extension PatientLabel on Patient {
  String initials() => name.isEmpty ? '?' : name.trim()[0].toUpperCase();
}
