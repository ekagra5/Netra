import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../models/scan_result.dart';
import '../services/db_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart' show tagStyleForGrade;

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  Patient? patient;
  List<ScanResult> scans = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final id = state.selectedPatientId;
    if (id == null) return;
    final p = await DbService.instance.patientById(id);
    final s = await DbService.instance.scansForPatient(id);
    if (mounted) setState(() { patient = p; scans = s; });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.t;

    return Scaffold(
      backgroundColor: NetraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            NsHeader(
              leading: NsBackButton(onPressed: state.backToHistory),
              title: t['recordTitle'],
            ),
            if (patient == null)
              const Expanded(child: SizedBox())
            else
              NsBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient!.name, style: Theme.of(context).textTheme.headlineSmall),
                    if (patient!.age != null)
                      Text('${t['age']}: ${patient!.age}', style: const TextStyle(color: NetraColors.inkMuted)),
                    const SizedBox(height: NetraSpace.s4),
                    if (scans.isNotEmpty)
                      NsCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat('MMM d, HH:mm').format(scans.first.timestamp.toLocal()),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            NsTag(
                              t['grade${scans.first.drGrade}'],
                              style: tagStyleForGrade(scans.first.drGrade),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: NetraSpace.s5),
                    NsSectionLabel(t['pastScans']),
                    for (final scan in scans.skip(1))
                      NsListRow(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat('MMM d, yyyy').format(scan.timestamp.toLocal()),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            NsTag(t['grade${scan.drGrade}'], style: tagStyleForGrade(scan.drGrade)),
                          ],
                        ),
                      ),
                    const SizedBox(height: NetraSpace.s5),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => state.startNewScanForPatient(patient!),
                        child: Text(t['newScanForPatient']),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
