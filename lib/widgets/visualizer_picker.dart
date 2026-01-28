import 'package:flutter/material.dart';
import '../models/visualizer_type.dart';

/// A dialog for selecting visualizer styles with visual previews.
class VisualizerPicker extends StatelessWidget {
  const VisualizerPicker({
    super.key,
    required this.currentType,
    required this.onSelect,
  });

  final VisualizerType currentType;
  final ValueChanged<VisualizerType> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Visualizer Style',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how your music comes alive',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),

          // Visualizer options grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: VisualizerType.values.length,
            itemBuilder: (context, index) {
              final type = VisualizerType.values[index];
              final isSelected = type == currentType;

              return _VisualizerOptionCard(
                type: type,
                isSelected: isSelected,
                onTap: () => onSelect(type),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Show the visualizer picker as a modal bottom sheet
  static Future<VisualizerType?> show(
    BuildContext context, {
    required VisualizerType currentType,
  }) {
    return showModalBottomSheet<VisualizerType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => VisualizerPicker(
        currentType: currentType,
        onSelect: (type) => Navigator.pop(context, type),
      ),
    );
  }
}

class _VisualizerOptionCard extends StatelessWidget {
  const _VisualizerOptionCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final VisualizerType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _getPreviewColors(type, primaryColor),
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryColor : primaryColor.withValues(alpha: 0.3),
              width: isSelected ? 3 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Visual preview (abstract pattern based on visualizer type)
              Positioned.fill(
                child: _buildPreviewPattern(type, primaryColor),
              ),

              // Icon and label overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        type.icon,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          type.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Selected checkmark
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _getPreviewColors(VisualizerType type, Color primary) {
    switch (type) {
      case VisualizerType.bioluminescent:
        return [
          const Color(0xFF0A1628),
          primary.withValues(alpha: 0.3),
          const Color(0xFF0A2040),
        ];
      case VisualizerType.spectrumBars:
        return [
          const Color(0xFF1A0A28),
          const Color(0xFF2A1438),
          const Color(0xFF0A1828),
        ];
      case VisualizerType.spectrumMirror:
        return [
          const Color(0xFF0A1828),
          primary.withValues(alpha: 0.2),
          const Color(0xFF0A1828),
        ];
      case VisualizerType.spectrumRadial:
        return [
          const Color(0xFF0A0A1A),
          const Color(0xFF1A1A2A),
          const Color(0xFF0A1020),
        ];
      case VisualizerType.butterchurn:
        return [
          const Color(0xFF1A0A2A),
          const Color(0xFF2A1A3A),
          const Color(0xFF0A1A2A),
        ];
    }
  }

  Widget _buildPreviewPattern(VisualizerType type, Color primary) {
    switch (type) {
      case VisualizerType.bioluminescent:
        return CustomPaint(
          painter: _BioluminescentPreviewPainter(primary),
        );
      case VisualizerType.spectrumBars:
        return CustomPaint(
          painter: _SpectrumBarsPreviewPainter(primary),
        );
      case VisualizerType.spectrumMirror:
        return CustomPaint(
          painter: _SpectrumMirrorPreviewPainter(primary),
        );
      case VisualizerType.spectrumRadial:
        return CustomPaint(
          painter: _SpectrumRadialPreviewPainter(primary),
        );
      case VisualizerType.butterchurn:
        return CustomPaint(
          painter: _ButterchurnPreviewPainter(primary),
        );
    }
  }
}

// Preview painters for each visualizer type (simplified static representations)

class _BioluminescentPreviewPainter extends CustomPainter {
  final Color primary;
  _BioluminescentPreviewPainter(this.primary);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primary.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Draw wave lines
    for (int i = 0; i < 3; i++) {
      final path = Path();
      final y = size.height * (0.4 + i * 0.15);
      path.moveTo(0, y);

      for (double x = 0; x <= size.width; x += 4) {
        final wave = 8 * (1 - i * 0.2) * (0.5 + 0.5 * ((x / size.width * 3.14).remainder(3.14) < 1.57 ? 1 : -1));
        path.lineTo(x, y + wave * (x / size.width));
      }

      canvas.drawPath(path, paint);
    }

    // Draw particles
    final particlePaint = Paint()
      ..color = primary.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.35), 4, particlePaint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.5), 5, particlePaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.65), 3, particlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpectrumBarsPreviewPainter extends CustomPainter {
  final Color primary;
  _SpectrumBarsPreviewPainter(this.primary);

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 12;
    final barWidth = size.width / barCount * 0.7;
    final spacing = size.width / barCount;

    // Fake spectrum heights
    final heights = [0.5, 0.7, 0.9, 0.6, 0.8, 0.5, 0.4, 0.6, 0.7, 0.5, 0.3, 0.4];

    for (int i = 0; i < barCount; i++) {
      final x = i * spacing + spacing * 0.15;
      final height = heights[i] * size.height * 0.6;

      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFF4444),
          const Color(0xFFFFDD00),
          const Color(0xFF44FF44),
        ],
      );

      final rect = Rect.fromLTWH(x, size.height - height - 10, barWidth, height);
      final paint = Paint()
        ..shader = gradient.createShader(rect);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpectrumMirrorPreviewPainter extends CustomPainter {
  final Color primary;
  _SpectrumMirrorPreviewPainter(this.primary);

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 16;
    final barWidth = size.width / barCount * 0.6;
    final spacing = size.width / barCount;
    final centerY = size.height / 2;

    final heights = [0.3, 0.5, 0.7, 0.8, 0.6, 0.9, 0.5, 0.4, 0.4, 0.5, 0.9, 0.6, 0.8, 0.7, 0.5, 0.3];

    for (int i = 0; i < barCount; i++) {
      final x = i * spacing + spacing * 0.2;
      final height = heights[i] * size.height * 0.35;

      final paint = Paint()
        ..color = primary.withValues(alpha: 0.7 + heights[i] * 0.3);

      // Top bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - height, barWidth, height),
          const Radius.circular(1),
        ),
        paint,
      );

      // Bottom bar (mirrored)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY, barWidth, height),
          const Radius.circular(1),
        ),
        paint,
      );
    }

    // Center line
    final linePaint = Paint()
      ..color = primary.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpectrumRadialPreviewPainter extends CustomPainter {
  final Color primary;
  _SpectrumRadialPreviewPainter(this.primary);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final innerRadius = size.width * 0.15;
    final maxBarLength = size.width * 0.25;

    // Center glow
    final glowPaint = Paint()
      ..color = primary.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, innerRadius * 0.8, glowPaint);

    // Draw radial bars
    final barCount = 20;

    for (int i = 0; i < barCount; i++) {
      final value = 0.4 + 0.5 * ((i % 4) / 4);
      final barLength = value * maxBarLength;

      final hue = (i / barCount * 360) % 360;
      final color = HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();

      final paint = Paint()
        ..color = color.withValues(alpha: 0.7)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      // Simplified radial line
      final actualStartX = center.dx + innerRadius * 0.9 * (i / barCount - 0.5) * 2;
      final actualStartY = center.dy + innerRadius * 0.9 * ((i % 2 == 0 ? 1 : -1) * (i / barCount));
      final actualEndX = center.dx + (innerRadius + barLength) * (i / barCount - 0.5) * 2;
      final actualEndY = center.dy + (innerRadius + barLength) * ((i % 2 == 0 ? 1 : -1) * (i / barCount));

      canvas.drawLine(
        Offset(actualStartX.clamp(0, size.width), actualStartY.clamp(0, size.height)),
        Offset(actualEndX.clamp(0, size.width), actualEndY.clamp(0, size.height)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ButterchurnPreviewPainter extends CustomPainter {
  final Color primary;
  _ButterchurnPreviewPainter(this.primary);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw concentric rings
    for (int i = 0; i < 5; i++) {
      final radius = size.width * 0.08 * (i + 1);
      final hue = (i * 60.0) % 360;
      final color = HSLColor.fromAHSL(1.0, hue, 0.8, 0.5).toColor();

      final paint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(center, radius, paint);
    }

    // Draw spiral arm hints
    final spiralPaint = Paint()
      ..color = primary.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (int arm = 0; arm < 4; arm++) {
      final path = Path();
      final armOffset = arm * 1.57;

      path.moveTo(center.dx, center.dy);
      for (double t = 0; t < 2; t += 0.1) {
        final r = t * size.width * 0.2;
        final angle = t * 2 + armOffset;
        final x = center.dx + r * (angle % 2 - 1);
        final y = center.dy + r * ((angle + 0.5) % 2 - 1);
        path.lineTo(x.clamp(0, size.width), y.clamp(0, size.height));
      }

      canvas.drawPath(path, spiralPaint);
    }

    // Center glow
    final glowPaint = Paint()
      ..color = primary.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, size.width * 0.08, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
