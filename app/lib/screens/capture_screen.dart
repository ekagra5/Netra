import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final state = context.read<AppState>();
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source, maxWidth: 2048, maxHeight: 2048);
    if (xfile != null) {
      state.imagePicked(File(xfile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.t;
    final hasImage = state.pendingImage != null;

    return Scaffold(
      backgroundColor: NetraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            NsHeader(
              leading: NsBackButton(onPressed: state.backToHome),
              title: t['newScanTitle'],
            ),
            NsBody(
              child: hasImage ? _ImagePreview(state: state, t: t) : _SourcePicker(t: t, onPick: (s) => _pick(context, s)),
            ),
            if (hasImage)
              Container(
                padding: const EdgeInsets.all(NetraSpace.s4),
                decoration: const BoxDecoration(
                  color: NetraColors.bg,
                  border: Border(top: BorderSide(color: NetraColors.divider, width: 2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: state.retakeImage, child: Text(t['retake'])),
                    ),
                    const SizedBox(width: NetraSpace.s3),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: state.modelReady ? state.runAnalysis : null,
                        child: Text(t['continueBtn']),
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

class _SourcePicker extends StatelessWidget {
  final dynamic t;
  final void Function(ImageSource) onPick;
  const _SourcePicker({required this.t, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t['choosePhoto'], style: const TextStyle(fontSize: 14, color: NetraColors.inkMuted)),
        const SizedBox(height: NetraSpace.s4),
        NsCard(
          onTap: () => onPick(ImageSource.gallery),
          child: Row(
            children: [
              const Icon(Icons.photo_library_outlined, color: NetraColors.red700),
              const SizedBox(width: NetraSpace.s3),
              Text(t['uploadFromGallery'], style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: NetraSpace.s3),
        NsCard(
          onTap: () => onPick(ImageSource.camera),
          child: Row(
            children: [
              const Icon(Icons.camera_alt_outlined, color: NetraColors.red700),
              const SizedBox(width: NetraSpace.s3),
              Text(t['captureWithCamera'], style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final AppState state;
  final dynamic t;
  const _ImagePreview({required this.state, required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(NetraRadius.card),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.file(state.pendingImage!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: NetraSpace.s4),
        _Check(t['checkSharp']),
        const SizedBox(height: NetraSpace.s2),
        _Check(t['checkCentered']),
        const SizedBox(height: NetraSpace.s2),
        _Check(t['checkGlare']),
        const SizedBox(height: NetraSpace.s4),
        NsCard(
          accentBorder: NetraColors.red700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t['qualityGoodTitle'], style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(t['qualityGoodBody'], style: const TextStyle(fontSize: 13, color: NetraColors.inkMuted)),
            ],
          ),
        ),
        if (!state.modelReady) ...[
          const SizedBox(height: NetraSpace.s3),
          Text(t['modelMissing'], style: const TextStyle(color: NetraColors.red700, fontSize: 12)),
        ],
      ],
    );
  }
}

class _Check extends StatelessWidget {
  final String text;
  const _Check(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline, size: 16, color: NetraColors.red700),
        const SizedBox(width: NetraSpace.s2),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
