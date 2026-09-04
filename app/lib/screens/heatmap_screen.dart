import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HeatmapScreen extends StatelessWidget {
  const HeatmapScreen({super.key});

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
              leading: NsBackButton(onPressed: state.backToResults),
              title: t['heatmapTitle'],
            ),
            NsBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(NetraRadius.card),
                          child: state.pendingImage != null
                              ? Image.file(state.pendingImage!, fit: BoxFit.cover)
                              : Container(color: NetraColors.bgMuted),
                        ),
                        if (state.heatmapLoading)
                          const Center(child: CircularProgressIndicator(color: NetraColors.red600)),
                        if (state.showHeatmapOverlay && state.heatmapGrid != null)
                          Positioned.fill(
                            child: CustomPaint(painter: _HeatmapPainter(state.heatmapGrid!)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: NetraSpace.s4),
                  Row(
                    children: [
                      Switch(
                        value: state.showHeatmapOverlay,
                        activeThumbColor: NetraColors.red600,
                        onChanged: (_) => state.toggleHeatmapOverlay(),
                      ),
                      const SizedBox(width: NetraSpace.s2),
                      Text(t['heatmapToggle'], style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: NetraSpace.s3),
                  Text(t['heatmapCaption'], style: const TextStyle(fontSize: 13, color: NetraColors.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the occlusion-sensitivity grid as translucent red cells - warmer
/// (more opaque) where occluding that patch dropped the model's confidence
/// most, i.e. where the model relied on that region most.
class _HeatmapPainter extends CustomPainter {
  final List<List<double>> grid;
  const _HeatmapPainter(this.grid);

  @override
  void paint(Canvas canvas, Size size) {
    final rows = grid.length;
    final cols = grid.isEmpty ? 0 : grid[0].length;
    if (rows == 0 || cols == 0) return;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final intensity = grid[y][x].clamp(0.0, 1.0);
        if (intensity < 0.08) continue;
        final paint = Paint()..color = NetraColors.red600.withValues(alpha: intensity * 0.65);
        canvas.drawRect(Rect.fromLTWH(x * cellW, y * cellH, cellW, cellH), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) => oldDelegate.grid != grid;
}
