// Generates a shareable PDF patient report - the native-app equivalent of
// apex_app.py's "Download report" button.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../i18n/strings.dart';
import '../models/patient.dart';
import '../models/scan_result.dart';

class ReportService {
  static Future<void> shareReport({
    required Patient patient,
    required ScanResult scan,
    required Strings t,
  }) async {
    final doc = pw.Document();
    final gradeKey = drGradeKeys[scan.drGrade];
    final dmeKey = dmeRiskKeys[scan.dmeRisk];

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              t['appName'],
              style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(t['tagline'], style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 1.5),
            pw.SizedBox(height: 12),
            pw.Text(t['patientDetails'], style: pw.TextStyle(fontSize: 10, letterSpacing: 1, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Text(patient.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            if (patient.age != null || patient.sex != null)
              pw.Text(
                [
                  if (patient.age != null) '${t['age']}: ${patient.age}',
                  if (patient.sex != null) patient.sex!,
                ].join('  •  '),
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
              ),
            pw.Text(
              scan.timestamp.toLocal().toString(),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 20),
            _resultBlock(t['gradeLabel'], t[gradeKey], scan.drConfidence),
            pw.SizedBox(height: 12),
            _resultBlock(t['dme'], t[dmeKey], scan.dmeProbs[scan.dmeRisk]),
            pw.SizedBox(height: 16),
            if (scan.flaggedFindings.isNotEmpty) ...[
              pw.Text(t['findingsTitle'], style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              ...scan.flaggedFindings.map(
                (f) => pw.Text(
                  '• ${t[ocularStringKey[f.key] ?? f.key]} (${(f.value * 100).toStringAsFixed(0)}%)',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
              pw.SizedBox(height: 16),
            ],
            if (scan.needsHumanReview) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.red700, width: 1.5)),
                child: pw.Text(
                  '${t['reviewTitle']}: ${t['reviewBody']}',
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.red900),
                ),
              ),
              pw.SizedBox(height: 16),
            ],
            pw.Text(
              t['recommend${scan.drGrade}'],
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 24),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 8),
            pw.Text(
              t['disclaimer'],
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'netra-report-${patient.name.replaceAll(' ', '_')}-${scan.timestamp.millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _resultBlock(String label, String value, double confidence) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.Text(
            '$value  (${(confidence * 100).toStringAsFixed(1)}%)',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        ],
      );
}
