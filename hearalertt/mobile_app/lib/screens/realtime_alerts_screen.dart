import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_app/providers/sound_provider.dart';
import 'package:mobile_app/providers/settings_provider.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/widgets/glass_container.dart';
import 'package:mobile_app/models/models.dart';

class RealtimeAlertsScreen extends StatefulWidget {
  const RealtimeAlertsScreen({super.key});

  @override
  State<RealtimeAlertsScreen> createState() => _RealtimeAlertsScreenState();
}

class _RealtimeAlertsScreenState extends State<RealtimeAlertsScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    // Sync animation speed to settings
    final newDur = (3000 ~/ settings.animationSpeed);
    if (_ringController.duration?.inMilliseconds != newDur) {
      _ringController.duration = Duration(milliseconds: newDur);
      if (_ringController.isAnimating) _ringController.repeat();
    }

    return Scaffold(
      backgroundColor: AppTheme.void_,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
              decoration: BoxDecoration(gradient: AppTheme.surfaceGradient)),

          // Ambient glow
          _buildAmbientGlow(settings),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(settings),
                const SizedBox(height: 8),
                Expanded(child: _buildCentralRing(settings)),
                _buildCategoryStrip(),
                _buildDetectionCard(settings),
                _buildControlDock(settings),
              ],
            ),
          ),

          // Screen flash for emergency
          Selector<SoundProvider, ({SoundEvent? event})>(
            selector: (_, p) => (event: p.lastEvent),
            builder: (_, data, __) {
              if (!settings.screenFlash || data.event == null) {
                return const SizedBox.shrink();
              }
              final isEmergency = data.event!.type == 'emergency';
              final flashColor =
                  isEmergency ? AppTheme.danger : AppTheme.primary;
              return IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: isEmergency
                      ? const Duration(milliseconds: 350)
                      : const Duration(milliseconds: 700),
                  builder: (_, val, __) {
                    final flash = (val * 8).toInt() % 2 == 0
                        ? 0.0
                        : (isEmergency ? 0.25 : 0.10);
                    return Container(color: flashColor.withOpacity(flash));
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  Widget _buildAmbientGlow(SettingsProvider settings) {
    return Selector<SoundProvider, SoundEvent?>(
      selector: (_, p) => p.lastEvent,
      builder: (_, event, __) {
        Color glow = AppTheme.primary;
        if (event?.type == 'emergency') glow = AppTheme.danger;
        if (event?.type == 'warning') glow = AppTheme.warning;

        return AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: (0.7 + _pulseController.value * 0.12) *
                    settings.glowBrightness,
                colors: [
                  glow.withOpacity((event != null ? 0.18 : 0.05) *
                      settings.glowBrightness *
                      (1.0 + _pulseController.value * 0.3)),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  Widget _buildHeader(SettingsProvider settings) {
    final scale = settings.largeText ? 1.2 : 1.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GlassCard(
        blur: 22,
        opacity: 0.10,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.biosonicGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(LucideIcons.radar, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Monitor',
                    style: GoogleFonts.spaceGrotesk(
                      color: settings.highContrast
                          ? Colors.white
                          : AppTheme.textPrimary,
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Selector<SoundProvider, bool>(
                    selector: (_, p) => p.isListening,
                    builder: (_, listening, __) => Text(
                      listening ? 'Actively scanning...' : 'Standby mode',
                      style: GoogleFonts.inter(
                        color:
                            listening ? AppTheme.primary : AppTheme.textMuted,
                        fontSize: 11 * scale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Selector<SoundProvider, bool>(
              selector: (_, p) => p.isListening,
              builder: (_, listening, __) => _StatusPill(
                text: listening ? 'LIVE' : 'OFF',
                color: listening ? AppTheme.success : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Circular amplitude ring visualizer
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildCentralRing(SettingsProvider settings) {
    return Selector<SoundProvider,
        ({bool isListening, double amplitude, SoundEvent? event})>(
      selector: (_, p) => (
        isListening: p.isListening,
        amplitude: p.amplitude,
        event: p.lastEvent
      ),
      builder: (context, data, _) {
        final isEmergency = data.event?.type == 'emergency';
        final ringColor = isEmergency
            ? AppTheme.danger
            : data.isListening
                ? AppTheme.primary
                : AppTheme.glassHigh;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Circular amplitude ring
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ringController,
                builder: (_, __) => CustomPaint(
                  painter: _CircularAmplitudeRingPainter(
                    amplitude: data.amplitude,
                    isListening: data.isListening,
                    sweepProgress: _ringController.value,
                    color: ringColor,
                    accentColor: isEmergency
                        ? AppTheme.accentOrange
                        : AppTheme.secondary,
                  ),
                  size: const Size(260, 260),
                ),
              ),
            ),

            // Center content
            Selector<SoundProvider, ({SoundEvent? event, bool isListening})>(
              selector: (_, p) =>
                  (event: p.lastEvent, isListening: p.isListening),
              builder: (_, d, __) {
                if (d.event != null) {
                  return _buildDetectedEventCenter(d.event!, settings);
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      d.isListening ? LucideIcons.waves : LucideIcons.radio,
                      color:
                          d.isListening ? AppTheme.primary : AppTheme.textMuted,
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      d.isListening ? 'SCANNING' : 'READY',
                      style: GoogleFonts.spaceGrotesk(
                        color: d.isListening
                            ? AppTheme.primary
                            : AppTheme.textMuted,
                        fontSize: 13 * AppTheme.textScale,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetectedEventCenter(
      SoundEvent event, SettingsProvider settings) {
    final scale = settings.largeText ? 1.2 : 1.0;
    Color color = AppTheme.primary;
    if (event.type == 'emergency') color = AppTheme.danger;
    if (event.type == 'warning') color = AppTheme.warning;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: AppTheme.glow(color, intensity: 1.2),
          ),
          child: Icon(_iconFor(event.label), color: Colors.white, size: 36),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
              begin: const Offset(1, 1),
              end: const Offset(1.08, 1.08),
              duration: 700.ms,
            ),
        const SizedBox(height: 14),
        Text(
          event.label.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 20 * scale,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ],
    ).animate().fadeIn().scale(curve: Curves.easeOutBack);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Category tag strip
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildCategoryStrip() {
    return Selector<SoundProvider, List<SoundEvent>>(
      selector: (_, p) => p.recentEvents,
      builder: (context, events, _) {
        if (events.isEmpty) return const SizedBox(height: 12);
        // Unique recent categories
        final cats = events.map((e) => e.label).toSet().take(5).toList();
        return SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: cats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = cats[i];
              final color = _catColor(cat);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_iconFor(cat), color: color, size: 12),
                    const SizedBox(width: 5),
                    Text(
                      cat,
                      style: GoogleFonts.inter(
                        color: color,
                        fontSize: 11 * AppTheme.textScale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Bottom detection card with gradient waveform
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildDetectionCard(SettingsProvider settings) {
    return Selector<SoundProvider,
        ({List<double> waveform, bool isListening, SoundEvent? event})>(
      selector: (_, p) => (
        waveform: p.waveformData,
        isListening: p.isListening,
        event: p.lastEvent
      ),
      builder: (_, data, __) {
        return Container(
          height: 90,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppTheme.glassLow,
            border: Border.all(
              color: data.isListening
                  ? AppTheme.primary.withOpacity(0.20)
                  : Colors.white.withOpacity(0.05),
            ),
          ),
          child: Stack(
            children: [
              // Gradient waveform
              if (data.isListening && data.waveform.isNotEmpty)
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _GradientWaveformPainter(data: data.waveform),
                    size: Size.infinite,
                  ),
                ),
              // Label overlay
              if (data.event != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.void_.withOpacity(0.9),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data.event!.label,
                          style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12 * AppTheme.textScale,
                          ),
                        ),
                        Text(
                          '${(data.event!.confidence * 100).toInt()}% confidence',
                          style: GoogleFonts.inter(
                            color: AppTheme.primary,
                            fontSize: 11 * AppTheme.textScale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!data.isListening)
                Center(
                  child: Text(
                    'Tap power to start listening',
                    style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 12 * AppTheme.textScale),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  Widget _buildControlDock(SettingsProvider settings) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      child: GlassCard(
        blur: 22,
        opacity: 0.10,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        borderRadius: BorderRadius.circular(28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _DockButton(
              icon: LucideIcons.zap,
              label: 'Flash',
              isActive: context
                  .select<SoundProvider, bool>((p) => p.flashlightEnabled),
              color: AppTheme.accentYellow,
              onTap: () => context.read<SoundProvider>().toggleFlashlight(),
            ),
            _MainToggleButton(),
            _DockButton(
              icon: LucideIcons.trash2,
              label: 'Clear',
              isActive: false,
              color: AppTheme.danger,
              onTap: () => context.read<SoundProvider>().clearHistory(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('fire') || l.contains('smoke')) return LucideIcons.flame;
    if (l.contains('baby') || l.contains('cry')) return LucideIcons.baby;
    if (l.contains('glass')) return LucideIcons.glassWater;
    if (l.contains('alarm')) return LucideIcons.bellRing;
    if (l.contains('horn') || l.contains('siren')) return LucideIcons.siren;
    if (l.contains('knock') || l.contains('door')) return LucideIcons.doorOpen;
    if (l.contains('dog')) return LucideIcons.dog;
    return LucideIcons.activity;
  }

  Color _catColor(String label) {
    final l = label.toLowerCase();
    if (l.contains('fire') || l.contains('alarm') || l.contains('siren'))
      return AppTheme.danger;
    if (l.contains('baby') || l.contains('cry')) return AppTheme.warning;
    if (l.contains('dog')) return AppTheme.accentYellow;
    if (l.contains('door') || l.contains('knock')) return AppTheme.info;
    return AppTheme.primary;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circular amplitude ring painter
// ─────────────────────────────────────────────────────────────────────────────
class _CircularAmplitudeRingPainter extends CustomPainter {
  final double amplitude;
  final bool isListening;
  final double sweepProgress;
  final Color color;
  final Color accentColor;

  const _CircularAmplitudeRingPainter({
    required this.amplitude,
    required this.isListening,
    required this.sweepProgress,
    required this.color,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2 - 20;

    // Static base rings
    for (int i = 1; i <= 3; i++) {
      final r = maxR * (i / 3);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = Colors.white.withOpacity(0.05),
      );
    }

    if (!isListening) {
      // Idle ring
      canvas.drawCircle(
        center,
        maxR * 0.65,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppTheme.textMuted.withOpacity(0.3),
      );
      return;
    }

    // Animated sweep arc
    final sweepRect = Rect.fromCircle(center: center, radius: maxR * 0.85);
    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: [
          color.withOpacity(0),
          color.withOpacity(0.8),
          accentColor.withOpacity(0.4),
          color.withOpacity(0),
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
        transform: GradientRotation(sweepProgress * 2 * math.pi),
      ).createShader(sweepRect);

    canvas.drawArc(
      sweepRect,
      sweepProgress * 2 * math.pi,
      2 * math.pi * 0.85,
      false,
      sweepPaint,
    );

    // Amplitude ring — pulses with sound
    final ampRadius = maxR * (0.5 + amplitude * 0.35);
    canvas.drawCircle(
      center,
      ampRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color.withOpacity(0.55 + amplitude * 0.4),
    );

    // Outer glow ring
    canvas.drawCircle(
      center,
      ampRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = color.withOpacity(0.08 + amplitude * 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Center dot
    canvas.drawCircle(
      center,
      5,
      Paint()
        ..color = color.withOpacity(0.8)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularAmplitudeRingPainter old) =>
      old.sweepProgress != sweepProgress ||
      old.amplitude != amplitude ||
      old.isListening != isListening;
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient waveform painter (teal → neon green)
// ─────────────────────────────────────────────────────────────────────────────
class _GradientWaveformPainter extends CustomPainter {
  final List<double> data;
  const _GradientWaveformPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final centerY = size.height / 2;
    final widthPerSample = size.width / data.length;

    for (int i = 0; i < data.length; i++) {
      final val = data[i].abs();
      double h = (val * size.height * 1.6).clamp(2.0, size.height);
      final x = i * widthPerSample;
      final t = i / data.length; // 0..1 position across width

      // Interpolate teal → neon green across width
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(AppTheme.primary, AppTheme.secondary, t)!
                .withOpacity(0.85),
            Color.lerp(AppTheme.primary, AppTheme.secondary, t)!
                .withOpacity(0.3),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(x, centerY - h / 2, widthPerSample, h))
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      // Glow
      final glow = Paint()
        ..color = AppTheme.primary.withOpacity(0.15)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawLine(
          Offset(x, centerY - h / 2), Offset(x, centerY + h / 2), glow);
      canvas.drawLine(
          Offset(x, centerY - h / 2), Offset(x, centerY + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradientWaveformPainter old) =>
      old.data != data;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main power toggle button
// ─────────────────────────────────────────────────────────────────────────────
class _MainToggleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Selector<SoundProvider, bool>(
      selector: (_, p) => p.isListening,
      builder: (context, isListening, _) {
        return GestureDetector(
          onTap: () => context.read<SoundProvider>().toggleListening(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: isListening ? AppTheme.biosonicGradient : null,
              color: isListening ? null : AppTheme.surfaceElevated,
              shape: BoxShape.circle,
              boxShadow: isListening
                  ? AppTheme.glow(AppTheme.primary, intensity: 0.9)
                  : null,
              border: Border.all(
                color: isListening
                    ? Colors.transparent
                    : Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
            ),
            child: Icon(
              isListening ? LucideIcons.pause : LucideIcons.power,
              color: Colors.white,
              size: 24,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dock button
// ─────────────────────────────────────────────────────────────────────────────
class _DockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _DockButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppTheme.liquidFast,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.15) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? color.withOpacity(0.3) : Colors.transparent,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? color : AppTheme.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: isActive ? color : AppTheme.textMuted,
              fontSize: 11 * AppTheme.textScale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status pill widget (also used in header)
// ─────────────────────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: text == 'LIVE'
                  ? [BoxShadow(color: color, blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 10 * AppTheme.textScale,
              fontWeight: FontWeight.w700,
              color: text == 'LIVE' ? Colors.white : color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
