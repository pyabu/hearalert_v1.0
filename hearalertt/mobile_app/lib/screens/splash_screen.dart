import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_app/providers/settings_provider.dart';
import 'package:mobile_app/screens/app_scaffold.dart';
import 'package:mobile_app/screens/onboarding_screen.dart';
import 'package:mobile_app/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _barController;
  late AnimationController _logoController;

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _initApp();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _barController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    final startTime = DateTime.now();
    final settings = context.read<SettingsProvider>();
    await settings.init();

    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 3200) - elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);
    if (!mounted) return;

    final target = settings.onboardingCompleted
        ? const AppScaffold()
        : const OnboardingScreen();

    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => target,
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 600),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.void_,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Particle field ───────────────────────────────────────────
          AnimatedBuilder(
            animation: _particleController,
            builder: (_, __) => CustomPaint(
              painter: _ParticleFieldPainter(
                progress: _particleController.value,
                size: size,
              ),
              size: size,
            ),
          ),

          // ── Deep radial glow ─────────────────────────────────────────
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 0.6 + _pulseController.value * 0.15,
                  colors: [
                    AppTheme.primary
                        .withOpacity(0.15 + _pulseController.value * 0.08),
                    AppTheme.void_,
                  ],
                ),
              ),
            ),
          ),

          // ── Expanding sonic rings ────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _ringController,
              builder: (_, __) => CustomPaint(
                painter: _SonicRingsPainter(progress: _ringController.value),
                size: const Size(340, 340),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo container with glow
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(
                              0.45 + _pulseController.value * 0.25),
                          blurRadius: 40 + _pulseController.value * 20,
                          spreadRadius: 0,
                          blurStyle: BlurStyle.outer,
                        ),
                        BoxShadow(
                          color: AppTheme.secondary.withOpacity(
                              0.20 + _pulseController.value * 0.10),
                          blurRadius: 60,
                          spreadRadius: 4,
                          blurStyle: BlurStyle.outer,
                        ),
                      ],
                      image: const DecorationImage(
                        image: AssetImage('assets/images/app_icon.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
                    .animate(controller: _logoController)
                    .fadeIn(duration: 700.ms)
                    .scale(
                      begin: const Offset(0.3, 0.3),
                      end: const Offset(1, 1),
                      curve: Curves.elasticOut,
                      duration: 1200.ms,
                    ),

                const SizedBox(height: 36),

                // HearAlert staggered letters
                _StaggeredAppName(),

                const SizedBox(height: 6),

                // Sub-tagline with glitch effect
                Text(
                  'B I O S O N I C  E N G I N E',
                  style: GoogleFonts.inter(
                    fontSize: 10 * AppTheme.textScale,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primary,
                    letterSpacing: 3,
                  ),
                ).animate().fadeIn(delay: 1400.ms).slideY(begin: 0.4, end: 0),

                const SizedBox(height: 52),

                // Sound bars loader
                AnimatedBuilder(
                  animation: _barController,
                  builder: (_, __) => _SoundBarsLoader(
                    animValue: _barController.value,
                  ),
                ).animate().fadeIn(delay: 1600.ms),

                const SizedBox(height: 20),

                Text(
                  'Initializing sound intelligence...',
                  style: GoogleFonts.inter(
                    fontSize: 12 * AppTheme.textScale,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ).animate().fadeIn(delay: 1800.ms),
              ],
            ),
          ),

          // ── Bottom version ────────────────────────────────────────────
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.secondary,
                      shape: BoxShape.circle,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .scale(duration: 800.ms, curve: Curves.easeInOut)
                      .then()
                      .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(0.5, 0.5),
                          duration: 800.ms),
                  const SizedBox(width: 8),
                  Text(
                    'HearAlert v2.0  ·  BioSonic Edition',
                    style: GoogleFonts.inter(
                      fontSize: 11 * AppTheme.textScale,
                      color: AppTheme.textMuted.withOpacity(0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 2000.ms),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Staggered "HearAlert" title
// ─────────────────────────────────────────────────────────────────────────────
class _StaggeredAppName extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const text = 'HearAlert';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(text.length, (i) {
        final isCapital = text[i] == text[i].toUpperCase() &&
            text[i] != text[i].toLowerCase();
        return Text(
          text[i],
          style: GoogleFonts.spaceGrotesk(
            fontSize: 42 * AppTheme.textScale,
            fontWeight: FontWeight.bold,
            color: isCapital ? AppTheme.primary : Colors.white,
            letterSpacing: -1,
            shadows: isCapital
                ? [
                    Shadow(
                        color: AppTheme.primary.withOpacity(0.6),
                        blurRadius: 20)
                  ]
                : null,
          ),
        )
            .animate()
            .fadeIn(
                delay: Duration(milliseconds: 500 + i * 65), duration: 400.ms)
            .moveY(
                begin: 30,
                end: 0,
                delay: Duration(milliseconds: 500 + i * 65),
                duration: 550.ms,
                curve: Curves.easeOutCubic);
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated sound bars reacting to bar controller value
// ─────────────────────────────────────────────────────────────────────────────
class _SoundBarsLoader extends StatelessWidget {
  final double animValue;
  const _SoundBarsLoader({required this.animValue});

  static final _rng = math.Random(7);
  static final _phases = List.generate(12, (_) => _rng.nextDouble() * math.pi);
  static final _heights = [
    16.0,
    28.0,
    42.0,
    56.0,
    42.0,
    64.0,
    42.0,
    56.0,
    42.0,
    28.0,
    42.0,
    16.0
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(12, (i) {
        final h = _heights[i] *
            (0.3 +
                0.7 *
                    (math.sin(animValue * math.pi * 2 + _phases[i]) * 0.5 +
                        0.5));
        final t = i / 12;
        final color = Color.lerp(AppTheme.primary, AppTheme.secondary, t)!;
        return Container(
          width: 5,
          height: h,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.9), color.withOpacity(0.3)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4 expanding sonic rings with fade
// ─────────────────────────────────────────────────────────────────────────────
class _SonicRingsPainter extends CustomPainter {
  final double progress;
  _SonicRingsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const rings = 4;

    for (int i = 0; i < rings; i++) {
      final phase = (progress + i / rings) % 1.0;
      final r = phase * (size.width / 2);
      final opacity = (1.0 - phase) * 0.45;
      if (opacity <= 0.01) continue;

      // Gradient per ring: teal → green
      final t = phase;
      final color = Color.lerp(AppTheme.primary, AppTheme.secondary, t)!;
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = color.withOpacity(opacity));
    }
  }

  @override
  bool shouldRepaint(covariant _SonicRingsPainter old) =>
      old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating particle field
// ─────────────────────────────────────────────────────────────────────────────
class _ParticleFieldPainter extends CustomPainter {
  final double progress;
  final Size size;
  _ParticleFieldPainter({required this.progress, required this.size});

  static final _rng = math.Random(42);
  static const _count = 60;
  static final _particles = List.generate(
      _count,
      (i) => _Particle(
            x: _rng.nextDouble(),
            y: _rng.nextDouble(),
            speed: 0.008 + _rng.nextDouble() * 0.012,
            size: 0.8 + _rng.nextDouble() * 1.8,
            phase: _rng.nextDouble(),
            drift: (_rng.nextDouble() - 0.5) * 0.3,
            isBright: i < 15,
          ));

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (final p in _particles) {
      final y = (p.y - progress * p.speed * 5) % 1.0;
      final opacity =
          (math.sin(progress * math.pi * 2 + p.phase * math.pi * 2) * 0.3 + 0.4)
              .clamp(0.05, 0.7);

      final color = p.isBright ? AppTheme.primary : AppTheme.secondary;
      final paint = Paint()
        ..color = color.withOpacity(opacity * (p.isBright ? 0.7 : 0.25));

      canvas.drawCircle(
        Offset(p.x * canvasSize.width, y * canvasSize.height),
        p.size,
        paint,
      );

      if (p.isBright) {
        // Draw a soft glow around bright particles
        canvas.drawCircle(
          Offset(p.x * canvasSize.width, y * canvasSize.height),
          p.size * 3,
          Paint()
            ..color = AppTheme.primary.withOpacity(opacity * 0.08)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleFieldPainter old) =>
      old.progress != progress;
}

class _Particle {
  final double x, y, speed, size, phase, drift;
  final bool isBright;
  const _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.phase,
    required this.drift,
    required this.isBright,
  });
}
