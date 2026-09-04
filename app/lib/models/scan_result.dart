import 'dart:convert';

/// The five DR (diabetic retinopathy) severity grades the model outputs,
/// in class order 0-4 - matches DR_CLASSES in the original apex_app.py.
const List<String> drGradeKeys = ['grade0', 'grade1', 'grade2', 'grade3', 'grade4'];

/// The three DME (diabetic macular edema) risk classes, in class order 0-2.
const List<String> dmeRiskKeys = ['absent', 'someRisk', 'highRisk'];

/// Ocular finding keys in the model's native output order. 'N' (normal) and
/// 'D' (diabetes-general) are predicted but not surfaced in the UI - 'N'
/// means nothing to report, and 'D' duplicates the DR grade head - matching
/// the original app's OCULAR_ORDER / OCULAR_REPORT split.
const List<String> ocularOrder = ['N', 'D', 'G', 'C', 'A', 'H', 'M', 'O'];
const List<String> ocularReport = ['G', 'C', 'A', 'H', 'M', 'O'];

const Map<String, String> ocularStringKey = {
  'G': 'glaucoma',
  'C': 'cataract',
  'A': 'amd',
  'H': 'hypertension',
  'M': 'myopia',
  'O': 'otherFindings',
};

/// Below this top-grade confidence, the result is routed to the "needs
/// human review" flow rather than shown as an automatic grade. Ported
/// unchanged from apex_app.py's LOW_CONFIDENCE_THRESHOLD.
const double lowConfidenceThreshold = 0.45;

/// If the top two DR grade probabilities are closer than this, treat the
/// result as borderline. Ported from apex_app.py's CLOSE_MARGIN_THRESHOLD.
const double closeMarginThreshold = 0.10;

/// Sigmoid threshold for flagging an ocular finding as present. Ported
/// from apex_app.py's OCULAR_THRESHOLD.
const double ocularThreshold = 0.5;

enum SyncStatus { queued, syncing, synced, failed }

class ScanResult {
  final int? id;
  final int patientId;
  final String imagePath;
  final String? heatmapPath;
  final List<double> drProbs; // length 5, softmax
  final List<double> dmeProbs; // length 3, softmax
  final Map<String, double> ocularProbs; // key -> sigmoid prob, 'G'..'O'
  final DateTime timestamp;
  final SyncStatus syncStatus;
  final String? referralUrgency; // 'urgent' | 'routine' | null
  final String? referralNotes;

  ScanResult({
    this.id,
    required this.patientId,
    required this.imagePath,
    this.heatmapPath,
    required this.drProbs,
    required this.dmeProbs,
    required this.ocularProbs,
    required this.timestamp,
    this.syncStatus = SyncStatus.queued,
    this.referralUrgency,
    this.referralNotes,
  });

  int get drGrade {
    var best = 0;
    for (var i = 1; i < drProbs.length; i++) {
      if (drProbs[i] > drProbs[best]) best = i;
    }
    return best;
  }

  double get drConfidence => drProbs[drGrade];

  /// Gap between the top and second-highest DR grade probability.
  double get drMargin {
    final sorted = [...drProbs]..sort((a, b) => b.compareTo(a));
    return sorted[0] - sorted[1];
  }

  bool get isLowConfidence => drConfidence < lowConfidenceThreshold;
  bool get isCloseMargin => drMargin < closeMarginThreshold;

  /// True when the automatic grade should not be shown as-is and the scan
  /// should route to the specialist-review flow instead.
  bool get needsHumanReview => isLowConfidence || isCloseMargin;

  int get dmeRisk {
    var best = 0;
    for (var i = 1; i < dmeProbs.length; i++) {
      if (dmeProbs[i] > dmeProbs[best]) best = i;
    }
    return best;
  }

  /// Ocular findings whose probability cleared [ocularThreshold], sorted by
  /// probability descending.
  List<MapEntry<String, double>> get flaggedFindings {
    final flagged = ocularProbs.entries
        .where((e) => ocularReport.contains(e.key) && e.value >= ocularThreshold)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return flagged;
  }

  bool get dmePresent => dmeRisk > 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'patientId': patientId,
        'imagePath': imagePath,
        'heatmapPath': heatmapPath,
        'drProbs': jsonEncode(drProbs),
        'dmeProbs': jsonEncode(dmeProbs),
        'ocularProbs': jsonEncode(ocularProbs),
        'timestamp': timestamp.toIso8601String(),
        'syncStatus': syncStatus.name,
        'referralUrgency': referralUrgency,
        'referralNotes': referralNotes,
      };

  factory ScanResult.fromMap(Map<String, dynamic> map) => ScanResult(
        id: map['id'] as int?,
        patientId: map['patientId'] as int,
        imagePath: map['imagePath'] as String,
        heatmapPath: map['heatmapPath'] as String?,
        drProbs: (jsonDecode(map['drProbs'] as String) as List)
            .map((e) => (e as num).toDouble())
            .toList(),
        dmeProbs: (jsonDecode(map['dmeProbs'] as String) as List)
            .map((e) => (e as num).toDouble())
            .toList(),
        ocularProbs: (jsonDecode(map['ocularProbs'] as String) as Map)
            .map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        timestamp: DateTime.parse(map['timestamp'] as String),
        syncStatus: SyncStatus.values.firstWhere(
          (s) => s.name == map['syncStatus'],
          orElse: () => SyncStatus.queued,
        ),
        referralUrgency: map['referralUrgency'] as String?,
        referralNotes: map['referralNotes'] as String?,
      );

  ScanResult copyWith({
    int? id,
    String? heatmapPath,
    SyncStatus? syncStatus,
    String? referralUrgency,
    String? referralNotes,
  }) =>
      ScanResult(
        id: id ?? this.id,
        patientId: patientId,
        imagePath: imagePath,
        heatmapPath: heatmapPath ?? this.heatmapPath,
        drProbs: drProbs,
        dmeProbs: dmeProbs,
        ocularProbs: ocularProbs,
        timestamp: timestamp,
        syncStatus: syncStatus ?? this.syncStatus,
        referralUrgency: referralUrgency ?? this.referralUrgency,
        referralNotes: referralNotes ?? this.referralNotes,
      );
}
