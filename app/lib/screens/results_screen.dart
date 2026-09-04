import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/scan_result.dart';
import '../services/report_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

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
              leading: NsBackButton(onPressed: state.backToHome),
              title: t['resultTitle'],
            ),
            if (scan == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              NsBody(
                child: scan.needsHumanReview ? _ReviewCase(scan: scan) : _NormalCase(scan: scan),
              ),
          ],
        ),
      ),
    );
  }
}

class _NormalCase extends StatelessWidget {
  final ScanResult scan;
  const _NormalCase({required this.scan});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.t;
    final severityColor = NetraColors.severity[scan.drGrade];
    final confLabel = scan.drConfidence >= 0.8
        ? t['confHigh']
        : scan.drConfidence >= 0.55
            ? t['confMed']
            : t['confLow'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(NetraSpace.s4),
          decoration: BoxDecoration(border: Border.all(color: NetraColors.divider, width: 2)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NsSectionLabel(t['gradeLabel']),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${scan.drGrade}',
                    style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800, height: 1, color: severityColor),
                  ),
                  const SizedBox(width: NetraSpace.s3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      t['grade${scan.drGrade}'],
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NetraSpace.s3),
              Row(
                children: List.generate(5, (i) {
                  return Expanded(
                    child: Container(
                      height: 7,
                      margin: EdgeInsets.only(right: i == 4 ? 0 : 6),
                      color: i <= scan.drGrade ? NetraColors.severity[i] : NetraColors.bgMuted,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: NetraSpace.s4),
        NsSectionLabel(t['confidence']),
        Row(
          children: [
            Expanded(child: _ConfChip(t['confLow'], active: confLabel == t['confLow'])),
            const SizedBox(width: 6),
            Expanded(child: _ConfChip(t['confMed'], active: confLabel == t['confMed'])),
            const SizedBox(width: 6),
            Expanded(child: _ConfChip(t['confHigh'], active: confLabel == t['confHigh'])),
          ],
        ),
        const SizedBox(height: NetraSpace.s4),
        const Divider(),
        const SizedBox(height: NetraSpace.s3),
        Text(t['disclaimer'], style: const TextStyle(fontSize: 13, color: NetraColors.inkMuted)),
        const SizedBox(height: NetraSpace.s5),
        NsListRow(
          onTap: state.goHeatmap,
          child: _RowContent(icon: Icons.blur_circular, label: t['viewHeatmap']),
        ),
        NsListRow(
          onTap: state.goFindings,
          child: _RowContent(icon: Icons.fact_check_outlined, label: t['viewFindings']),
        ),
        NsListRow(
          onTap: state.goReferral,
          showDivider: false,
          child: _RowContent(icon: Icons.person_outline, label: t['viewReferral']),
        ),
        const SizedBox(height: NetraSpace.s5),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final patient = state.currentPatient;
              if (patient != null) {
                ReportService.shareReport(patient: patient, scan: scan, t: t);
              }
            },
            icon: const Icon(Icons.ios_share, size: 16),
            label: Text(t['downloadReport']),
          ),
        ),
      ],
    );
  }
}

class _ReviewCase extends StatelessWidget {
  final ScanResult scan;
  const _ReviewCase({required this.scan});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.t;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NsCard(
          accentBorder: NetraColors.red700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_outlined, color: NetraColors.red700),
                  const SizedBox(width: NetraSpace.s2),
                  Expanded(
                    child: Text(t['reviewTitle'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: NetraSpace.s2),
              Text(t['reviewBody'], style: const TextStyle(fontSize: 13, color: NetraColors.inkMuted)),
            ],
          ),
        ),
        const SizedBox(height: NetraSpace.s4),
        if (scan.isLowConfidence) Text('— ${t['reviewReasonLowConf']}', style: const TextStyle(fontSize: 14)),
        if (scan.isCloseMargin) ...[
          const SizedBox(height: NetraSpace.s2),
          Text('— ${t['reviewReasonMargin']}', style: const TextStyle(fontSize: 14)),
        ],
        const SizedBox(height: NetraSpace.s5),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: state.backToHome, child: Text(t['sendSpecialist'])),
        ),
      ],
    );
  }
}

class _ConfChip extends StatelessWidget {
  final String label;
  final bool active;
  const _ConfChip(this.label, {required this.active});

  @override
  Widget build(BuildContext context) => NsTag(label, style: active ? NsTagStyle.accent : NsTagStyle.outline);
}

class _RowContent extends StatelessWidget {
  final IconData icon;
  final String label;
  const _RowContent({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: NetraColors.red700),
        const SizedBox(width: NetraSpace.s3),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        const Icon(Icons.chevron_right, size: 18, color: NetraColors.inkFaint),
      ],
    );
  }
}
