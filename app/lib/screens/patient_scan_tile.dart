import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../models/scan_result.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart' show tagStyleForGrade;

/// A patient row with their latest scan's grade badge - the recurring
/// `.ns-listrow` pattern used on Home and History.
class PatientScanTile extends StatelessWidget {
  final Patient patient;
  final ScanResult? scan;
  final VoidCallback onTap;

  const PatientScanTile({super.key, required this.patient, this.scan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppState>().t;
    final dateLabel = DateFormat('MMM d, HH:mm').format((scan?.timestamp ?? patient.createdAt).toLocal());

    return NsListRow(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(dateLabel, style: const TextStyle(fontSize: 12, color: NetraColors.inkMuted)),
              ],
            ),
          ),
          if (scan != null) ...[
            NsTag(t[_gradeKey(scan!.drGrade)], style: tagStyleForGrade(scan!.drGrade)),
            const SizedBox(width: NetraSpace.s2),
          ],
          const Icon(Icons.chevron_right, size: 18, color: NetraColors.inkFaint),
        ],
      ),
    );
  }

  String _gradeKey(int grade) => 'grade$grade';
}
