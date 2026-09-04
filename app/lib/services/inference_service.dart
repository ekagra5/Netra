// On-device inference for the three-head MobileNetV2 model
// (model_apex_v2.tflite): DR grade (5-class), DME risk (3-class), and
// ocular findings (8-way, sigmoid per finding). No network calls.
//
// Ported line-for-line from apex_app.py's preprocess_image/run_inference/
// compute_occlusion_heatmap (confirmed against the source, not guessed):
//   - Normalization: (pixel/255)*2-1, i.e. (pixel/127.5)-1 - RGB, [-1, 1].
//   - Resize: a DIRECT resize to 224x224, no center-crop - a non-square
//     photo gets squashed, not cropped, because that's what the model was
//     fed at inference time in the reference app. Matching it exactly
//     matters more here than "what would usually be more correct" would.
//   - Output tensor order: identified BY SHAPE (5 vs 3 vs 8 classes)
//     rather than by index - apex_app.py does the same thing, so this
//     isn't just a defensive guess, it's what the reference app relies on.
//   - Softmax fallback: if a head's dequantized output doesn't already sum
//     to ~1 (a quantized model needs it; a float32 model with a baked-in
//     softmax usually doesn't), apply softmax before treating it as
//     probabilities. Ocular outputs are simply clamped to [0, 1].

import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

const int netraInputSize = 224;
const String netraModelAsset = 'assets/models/model_apex_v2.tflite';
const List<String> _ocularKeys = ['N', 'D', 'G', 'C', 'A', 'H', 'M', 'O'];

class InferenceOutput {
  final List<double> drProbs;
  final List<double> dmeProbs;
  final Map<String, double> ocularProbs; // 'N','D','G','C','A','H','M','O'
  InferenceOutput(this.drProbs, this.dmeProbs, this.ocularProbs);
}

/// Runs the loaded [interpreter] on a preprocessed [input] tensor and
/// splits the three output heads apart by shape (5 / 3 / 8 classes) rather
/// than by a hardcoded index - see the file doc comment on why.
InferenceOutput _runInterpreter(Interpreter interpreter, Float32List input) {
  final inputTensor = input.reshape([1, netraInputSize, netraInputSize, 3]);

  final outputBuffers = <int, Object>{};
  for (var i = 0; i < interpreter.getOutputTensors().length; i++) {
    final classes = interpreter.getOutputTensor(i).shape.last;
    outputBuffers[i] = List.filled(classes, 0.0).reshape([1, classes]);
  }

  interpreter.runForMultipleInputs([inputTensor], outputBuffers);

  List<double>? dr, dme, ocular;
  for (final value in outputBuffers.values) {
    final flat = (value as List).expand((row) => row as List).cast<double>().toList();
    if (flat.length == 5) dr = _normalizeProbs(flat);
    if (flat.length == 3) dme = _normalizeProbs(flat);
    if (flat.length == 8) ocular = [for (final v in flat) v.clamp(0.0, 1.0)];
  }
  if (dr == null || dme == null || ocular == null) {
    final shapes = outputBuffers.values.map((v) => (v as List).expand((r) => r as List).length);
    throw StateError(
      'Unexpected model output shapes: ${shapes.toList()}. '
      'Expected one head each of 5 (DR grade), 3 (DME), 8 (ocular).',
    );
  }

  final ocularMap = <String, double>{
    for (var i = 0; i < _ocularKeys.length; i++) _ocularKeys[i]: ocular[i],
  };
  return InferenceOutput(dr, dme, ocularMap);
}

/// If a head's output doesn't already sum to ~1 (within 0.05, matching
/// apex_app.py's `normalize_probs` tolerance) it isn't a normalized
/// probability distribution yet - typically a quantized-model artifact -
/// so apply softmax. A float32 model with a baked-in softmax layer will
/// already sum to ~1 and pass through unchanged.
List<double> _normalizeProbs(List<double> raw) {
  final sum = raw.fold<double>(0.0, (a, b) => a + b);
  if ((sum - 1.0).abs() <= 0.05) return raw;
  final maxVal = raw.reduce(math.max);
  final exps = raw.map((v) => math.exp(v - maxVal)).toList();
  final expSum = exps.fold<double>(0.0, (a, b) => a + b);
  return exps.map((v) => v / expSum).toList();
}

/// Resizes a decoded image DIRECTLY to 224x224 (no center-crop) and
/// normalizes it into the [1, 224, 224, 3] float32 input tensor - matches
/// apex_app.py's preprocess_image exactly, including squashing a
/// non-square photo rather than cropping it, because that's what the
/// model was actually fed at inference time.
Float32List _preprocess(img.Image decoded) {
  final resized = img.copyResize(
    decoded,
    width: netraInputSize,
    height: netraInputSize,
    interpolation: img.Interpolation.linear,
  );

  final input = Float32List(netraInputSize * netraInputSize * 3);
  var i = 0;
  for (var y = 0; y < netraInputSize; y++) {
    for (var x = 0; x < netraInputSize; x++) {
      final px = resized.getPixel(x, y);
      input[i++] = (px.r / 127.5) - 1.0;
      input[i++] = (px.g / 127.5) - 1.0;
      input[i++] = (px.b / 127.5) - 1.0;
    }
  }
  return input;
}

int _argmax(List<double> v) {
  var best = 0;
  for (var i = 1; i < v.length; i++) {
    if (v[i] > v[best]) best = i;
  }
  return best;
}

/// Main-isolate service: owns the interpreter used for single-shot scans
/// (one forward pass, ~tens of ms on a mid-range phone - cheap enough to
/// run inline without a background isolate).
class InferenceService {
  InferenceService._();
  static final InferenceService instance = InferenceService._();

  Interpreter? _interpreter;
  Uint8List? _modelBytes;
  bool get isReady => _interpreter != null;

  Future<bool> load({String assetPath = netraModelAsset}) async {
    try {
      final data = await rootBundle.load(assetPath);
      _modelBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      _interpreter = Interpreter.fromBuffer(_modelBytes!);
      return true;
    } catch (_) {
      _interpreter = null;
      _modelBytes = null;
      return false;
    }
  }

  Future<InferenceOutput> runOnBytes(Uint8List bytes) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Model not loaded. Call load() first.');
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('Could not decode image.');
    return _runInterpreter(interpreter, _preprocess(decoded));
  }

  /// Occlusion-sensitivity explainability: slides a gray patch across the
  /// image, measuring how much each patch position drops the predicted DR
  /// grade's confidence. A bigger drop means the model relied on that
  /// region more - the same technique the original app used, chosen
  /// instead of Grad-CAM because a converted .tflite model has no
  /// backprop access for Grad-CAM to hook into.
  ///
  /// This runs `gridSize * gridSize` extra forward passes, so it happens in
  /// a SEPARATE isolate with its OWN interpreter instance (a
  /// tflite_flutter Interpreter isn't safe to share across isolates) built
  /// from the same model bytes already held in memory - keeps the many
  /// repeated passes off the UI isolate so scrolling/animation stay smooth
  /// while it runs. gridSize defaults to 7, matching apex_app.py's
  /// compute_occlusion_heatmap.
  Future<List<List<double>>> computeHeatmap(Uint8List bytes, {int gridSize = 7}) async {
    final modelBytes = _modelBytes;
    if (modelBytes == null) {
      throw StateError('Model not loaded. Call load() first.');
    }
    return Isolate.run(() => _heatmapIsolateEntry(_HeatmapArgs(modelBytes, bytes, gridSize)));
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _modelBytes = null;
  }
}

class _HeatmapArgs {
  final Uint8List modelBytes;
  final Uint8List imageBytes;
  final int gridSize;
  _HeatmapArgs(this.modelBytes, this.imageBytes, this.gridSize);
}

/// Top-level so it can be handed to [Isolate.run] - builds its own
/// interpreter from the raw model bytes, entirely independent of the
/// main-isolate InferenceService.
List<List<double>> _heatmapIsolateEntry(_HeatmapArgs args) {
  final interpreter = Interpreter.fromBuffer(args.modelBytes);
  try {
    final decoded = img.decodeImage(args.imageBytes);
    if (decoded == null) throw const FormatException('Could not decode image.');

    // Same direct (non-cropping) resize as _preprocess, done once here so
    // the occlusion loop below patches this same 224x224 buffer repeatedly
    // instead of re-resizing on every pass - matches apex_app.py's
    // compute_occlusion_heatmap, which resizes once up front too.
    final square = img.copyResize(decoded, width: netraInputSize, height: netraInputSize);

    final baseline = _runInterpreter(interpreter, _preprocess(square));
    final targetGrade = _argmax(baseline.drProbs);
    final baseConfidence = baseline.drProbs[targetGrade];

    final gridSize = args.gridSize;
    final patch = netraInputSize ~/ gridSize;
    final grid = List.generate(gridSize, (_) => List.filled(gridSize, 0.0));

    for (var gy = 0; gy < gridSize; gy++) {
      for (var gx = 0; gx < gridSize; gx++) {
        final occluded = img.Image.from(square);
        img.fillRect(
          occluded,
          x1: gx * patch,
          y1: gy * patch,
          x2: math.min((gx + 1) * patch, netraInputSize) - 1,
          y2: math.min((gy + 1) * patch, netraInputSize) - 1,
          color: img.ColorRgb8(128, 128, 128),
        );
        final result = _runInterpreter(interpreter, _preprocess(occluded));
        final drop = baseConfidence - result.drProbs[targetGrade];
        grid[gy][gx] = drop.clamp(0.0, 1.0);
      }
    }

    final maxDrop = grid.expand((r) => r).fold<double>(0.0, math.max);
    if (maxDrop > 0) {
      for (var gy = 0; gy < gridSize; gy++) {
        for (var gx = 0; gx < gridSize; gx++) {
          grid[gy][gx] = grid[gy][gx] / maxDrop;
        }
      }
    }
    return grid;
  } finally {
    interpreter.close();
  }
}
