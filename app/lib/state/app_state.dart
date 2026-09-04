// Single app-wide state object, deliberately mirroring the shape of the
// Claude Design prototype's Component.state / renderVals(): one `screen`
// enum drives which full-bleed view is shown, and navigation is a small
// fixed graph of named transitions (goHome, backToResults, ...) rather
// than a general Navigator stack - the prototype has no back-stack either
// (Heatmap always backs to Results, Results always backs to Home, etc.),
// so a stack would be solving a problem this app doesn't have.

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../i18n/strings.dart';
import '../models/patient.dart';
import '../models/scan_result.dart';
import '../services/db_service.dart';
import '../services/inference_service.dart';

enum AppScreen {
  onboarding,
  home,
  capture,
  analyzing,
  results,
  heatmap,
  findings,
  referral,
  history,
  record,
  queue,
  settings,
}

class AppState extends ChangeNotifier {
  AppScreen screen = AppScreen.onboarding;
  AppLanguage language = AppLanguage.en;
  bool offlineFirstMode = true;

  bool modelReady = false;
  String? modelLoadError;

  List<Patient> patients = [];
  List<ScanResult> queue = [];
  Patient? currentPatient;
  ScanResult? currentScan;
  int? selectedPatientId;

  File? pendingImage;
  bool isAnalyzing = false;

  // Patient details entered on the capture screen, before analysis runs.
  // All optional except name, which falls back to a placeholder - matching
  // the original apex_app.py patient form's fields (minus a separate
  // free-text "Patient ID": the app already assigns its own internal id,
  // and adding a second, unrelated id field wasn't worth the extra DB
  // schema/UI for this pass).
  String pendingPatientName = '';
  String pendingPatientAge = '';
  String pendingPatientSex = '';

  List<List<double>>? heatmapGrid;
  bool showHeatmapOverlay = true;
  bool heatmapLoading = false;

  Strings get t => Strings(language);

  Future<void> bootstrap() async {
    final ok = await InferenceService.instance.load();
    modelReady = ok;
    modelLoadError = ok ? null : 'model_missing';
    await refreshPatients();
    await refreshQueue();
    notifyListeners();
  }

  Future<void> refreshPatients() async {
    patients = await DbService.instance.allPatients();
    notifyListeners();
  }

  Future<void> refreshQueue() async {
    queue = await DbService.instance.queuedScans();
    notifyListeners();
  }

  void setLanguage(AppLanguage lang) {
    language = lang;
    notifyListeners();
  }

  void toggleOfflineMode() {
    offlineFirstMode = !offlineFirstMode;
    notifyListeners();
  }

  // ── Navigation (fixed graph, matching the design prototype) ──────────
  void goHome() {
    screen = AppScreen.home;
    notifyListeners();
  }

  void goHistory() {
    screen = AppScreen.history;
    notifyListeners();
  }

  void goQueue() {
    refreshQueue();
    screen = AppScreen.queue;
    notifyListeners();
  }

  void goSettings() {
    screen = AppScreen.settings;
    notifyListeners();
  }

  void startNewScan() {
    pendingImage = null;
    currentPatient = null;
    pendingPatientName = '';
    pendingPatientAge = '';
    pendingPatientSex = '';
    screen = AppScreen.capture;
    notifyListeners();
  }

  void startNewScanForPatient(Patient patient) {
    pendingImage = null;
    currentPatient = patient;
    screen = AppScreen.capture;
    notifyListeners();
  }

  void imagePicked(File file) {
    pendingImage = file;
    notifyListeners();
  }

  void retakeImage() {
    pendingImage = null;
    notifyListeners();
  }

  void setPendingPatientName(String v) {
    pendingPatientName = v;
  }

  void setPendingPatientAge(String v) {
    pendingPatientAge = v;
  }

  void setPendingPatientSex(String v) {
    pendingPatientSex = v;
    notifyListeners();
  }

  void openRecord(int patientId) {
    selectedPatientId = patientId;
    screen = AppScreen.record;
    notifyListeners();
  }

  void goHeatmap() {
    screen = AppScreen.heatmap;
    heatmapGrid = null;
    notifyListeners();
    _loadHeatmap();
  }

  Future<void> _loadHeatmap() async {
    final img = pendingImage;
    if (img == null) return;
    heatmapLoading = true;
    notifyListeners();
    try {
      final bytes = await img.readAsBytes();
      heatmapGrid = await InferenceService.instance.computeHeatmap(bytes);
    } catch (_) {
      heatmapGrid = null;
    }
    heatmapLoading = false;
    notifyListeners();
  }

  void toggleHeatmapOverlay() {
    showHeatmapOverlay = !showHeatmapOverlay;
    notifyListeners();
  }

  void goFindings() {
    screen = AppScreen.findings;
    notifyListeners();
  }

  void goReferral() {
    screen = AppScreen.referral;
    notifyListeners();
  }

  void backToHome() {
    pendingImage = null;
    currentScan = null;
    screen = AppScreen.home;
    notifyListeners();
  }

  void backToResults() {
    screen = AppScreen.results;
    notifyListeners();
  }

  void backToHistory() {
    screen = AppScreen.history;
    notifyListeners();
  }

  // ── The actual screening pipeline ─────────────────────────────────────
  Future<void> runAnalysis() async {
    final img = pendingImage;
    if (img == null || !modelReady) return;
    screen = AppScreen.analyzing;
    isAnalyzing = true;
    notifyListeners();

    try {
      final bytes = await img.readAsBytes();
      final output = await InferenceService.instance.runOnBytes(bytes);

      var patient = currentPatient;
      if (patient == null) {
        final name = pendingPatientName.trim();
        patient = Patient(
          name: name.isEmpty ? 'Unnamed patient' : name,
          age: int.tryParse(pendingPatientAge.trim()),
          sex: pendingPatientSex.trim().isEmpty ? null : pendingPatientSex.trim(),
          createdAt: DateTime.now(),
        );
        final id = await DbService.instance.insertPatient(patient);
        patient = patient.copyWith(id: id);
      }
      currentPatient = patient;

      var scan = ScanResult(
        patientId: patient.id!,
        imagePath: img.path,
        drProbs: output.drProbs,
        dmeProbs: output.dmeProbs,
        ocularProbs: output.ocularProbs,
        timestamp: DateTime.now(),
        syncStatus: SyncStatus.queued,
      );
      final scanId = await DbService.instance.insertScan(scan);
      scan = scan.copyWith(id: scanId);
      currentScan = scan;

      await refreshPatients();
      await refreshQueue();

      screen = AppScreen.results;
    } finally {
      isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<void> saveReferral({required String urgency, String? notes}) async {
    final scan = currentScan;
    if (scan == null) return;
    final updated = scan.copyWith(referralUrgency: urgency, referralNotes: notes);
    await DbService.instance.updateScan(updated);
    currentScan = updated;
    notifyListeners();
  }

  /// Marks every queued scan as synced. There is no backend to actually
  /// sync to yet - this simulates the local half of that flow honestly
  /// (it's real local state, not a fabricated network call) so the queue
  /// screen has something real to demonstrate. See README's roadmap.
  Future<void> simulateSync() async {
    for (final scan in queue) {
      final updated = scan.copyWith(syncStatus: SyncStatus.synced);
      await DbService.instance.updateScan(updated);
    }
    await refreshQueue();
  }
}
