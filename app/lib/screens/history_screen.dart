import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/scan_result.dart';
import '../services/db_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tab_shell.dart';
import 'patient_scan_tile.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String query = '';
  Map<int, ScanResult> latestScanByPatient = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final scans = await DbService.instance.allScans();
    final latest = <int, ScanResult>{};
    for (final scan in scans) {
      latest.putIfAbsent(scan.patientId, () => scan);
    }
    if (mounted) setState(() => latestScanByPatient = latest);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.t;
    final filtered = state.patients
        .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: NetraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            NsHeader(leading: const NsBrandMark(letter: 'N'), title: t['historyTitle']),
            NsBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      hintText: t['searchPlaceholder'],
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: NetraColors.dividerStrong, width: 2),
                        borderRadius: BorderRadius.circular(NetraRadius.card),
                      ),
                    ),
                  ),
                  const SizedBox(height: NetraSpace.s3),
                  Wrap(
                    spacing: 6,
                    children: [
                      NsTag(t['filterAll'], style: NsTagStyle.accent),
                      NsTag(t['filterReferred'], style: NsTagStyle.outline),
                      NsTag(t['filterNormal'], style: NsTagStyle.outline),
                      NsTag(t['filterPending'], style: NsTagStyle.outline),
                    ],
                  ),
                  const SizedBox(height: NetraSpace.s4),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: NetraSpace.s4),
                      child: Text(t['noHistory'], style: const TextStyle(color: NetraColors.inkMuted)),
                    )
                  else
                    ...filtered.map(
                      (p) => PatientScanTile(
                        patient: p,
                        scan: latestScanByPatient[p.id],
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
