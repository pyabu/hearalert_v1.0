import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_app/services/audio_classifier_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:mobile_app/providers/sound_provider.dart';
import 'package:mobile_app/providers/settings_provider.dart';
import 'package:mobile_app/widgets/liquid_glass_container.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/models/models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 58),
              _buildHeader(),
              const SizedBox(height: 20),
              _buildNeuralRing(),
              const SizedBox(height: 14),
              _buildSpectrumCard(),
              const SizedBox(height: 22),
              _buildSmartZones(),
              const SizedBox(height: 22),
              _buildEnvironmentStats(),
              const SizedBox(height: 22),
              _buildLiveActivity(),
              const SizedBox(height: 22),
              _buildRecentDetections(),
              const SizedBox(height: 120),
            ]),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER — shows active smart zone
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Consumer<SettingsProvider>(
      builder: (_, settings, __) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Selector<SoundProvider, bool>(
                  selector: (_, p) => p.isListening,
                  builder: (_, listening, __) => Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: listening
                              ? AppTheme.secondary
                              : AppTheme.textMuted,
                          boxShadow: listening
                              ? [
                                  BoxShadow(
                                      color: AppTheme.secondary, blurRadius: 8)
                                ]
                              : null,
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat())
                          .fadeIn(duration: 600.ms)
                          .then()
                          .fadeOut(duration: 600.ms),
                      const SizedBox(width: 7),
                      Text(
                        listening
                            ? 'DETECTION  •  ACTIVE'
                            : 'SYSTEM  •  STANDBY',
                        style: GoogleFonts.inter(
                          fontSize: 9 * AppTheme.textScale,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                          color:
                              listening ? AppTheme.primary : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${settings.smartZone.emoji} ${settings.smartZone.label} Mode',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28 * AppTheme.textScale,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  settings.smartZone.description,
                  style: GoogleFonts.inter(
                    fontSize: 11 * AppTheme.textScale,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Zone pulse indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.biosonicGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary
                        .withOpacity(0.28 + _pulseController.value * 0.22),
                    blurRadius: 18,
                  )
                ],
              ),
              child: Icon(_iconForZone(settings.smartZone),
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.04, end: 0),
    );
  }

  IconData _iconForZone(SmartZone zone) {
    switch (zone) {
      case SmartZone.home:
        return LucideIcons.home;
      case SmartZone.street:
        return LucideIcons.car;
      case SmartZone.office:
        return LucideIcons.briefcase;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NEURAL RING — central hero visualizer
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildNeuralRing() {
    return Selector<SoundProvider,
            ({double amplitude, bool isListening, SoundEvent? event})>(
      selector: (_, p) => (
        amplitude: p.amplitude,
        isListening: p.isListening,
        event: p.lastEvent
      ),
      builder: (ctx, data, _) {
        final activeColor = data.event?.isEmergency == true
            ? AppTheme.danger
            : data.isListening
                ? AppTheme.primary
                : AppTheme.glassHigh;

        return SizedBox(
          height: 210,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating outer ring
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _ringController,
                  builder: (_, __) => CustomPaint(
                    painter: _NeuralRingPainter(
                      progress: _ringController.value,
                      amplitude: data.amplitude,
                      isListening: data.isListening,
                      color: activeColor,
                    ),
                    size: const Size(210, 210),
                  ),
                ),
              ),

              // Pulsing inner glow
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Container(
                  width: 110 + data.amplitude * 40,
                  height: 110 + data.amplitude * 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        activeColor.withOpacity((0.12 +
                            data.amplitude * 0.25 +
                            _pulseController.value * 0.08)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Center icon
              Selector<SoundProvider, ({SoundEvent? event, bool isListening})>(
                selector: (_, p) =>
                    (event: p.lastEvent, isListening: p.isListening),
                builder: (_, d, __) {
                  if (d.event != null) {
                    final ec = d.event!.isEmergency
                        ? AppTheme.danger
                        : AppTheme.success;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [ec, ec.withOpacity(0.6)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: AppTheme.glow(ec, intensity: 1.4),
                          ),
                          child: Icon(_iconFor(d.event!.label),
                              color: Colors.white, size: 30),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.1, 1.1),
                            duration: 600.ms),
                        const SizedBox(height: 8),
                        Text(
                          d.event!.label.toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11 * AppTheme.textScale,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ).animate().fadeIn().scale(curve: Curves.easeOutBack);
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        d.isListening ? LucideIcons.waves : LucideIcons.micOff,
                        color: d.isListening
                            ? AppTheme.primary
                            : AppTheme.textMuted,
                        size: 34,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        d.isListening ? 'SCANNING' : 'PAUSED',
                        style: GoogleFonts.inter(
                          fontSize: 10 * AppTheme.textScale,
                          letterSpacing: 3,
                          color: d.isListening
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                },
              ),

              // Tap area to toggle
              GestureDetector(
                onTap: () => ctx.read<SoundProvider>().toggleListening(),
                child: Container(
                  width: 210,
                  height: 210,
                  color: Colors.transparent,
                ),
              ),
            ],
          ),
        );
      },
    )
        .animate()
        .fadeIn(delay: 80.ms)
        .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1));
  }

  Widget _buildSpectrumCard() => const _RealtimeSpectrumCard();


  // ─────────────────────────────────────────────────────────────────────────
  // SMART ZONES — 3 tappable chips: Home / Street / Office
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSmartZones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('SMART ZONES', LucideIcons.mapPin),
        const SizedBox(height: 12),
        Consumer<SettingsProvider>(
          builder: (_, settings, __) => Row(
            children: SmartZone.values.map((zone) {
              final isActive = settings.smartZone == zone;
              final color = _colorForZone(zone);
              return Expanded(
                child: GestureDetector(
                  onTap: () => settings.setSmartZone(zone),
                  child: AnimatedContainer(
                    duration: AppTheme.liquidFast,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: isActive
                          ? LinearGradient(
                              colors: [
                                  color.withOpacity(0.28),
                                  color.withOpacity(0.08)
                                ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight)
                          : null,
                      color:
                          isActive ? null : AppTheme.glassLow.withOpacity(0.5),
                      border: Border.all(
                        color: isActive
                            ? color.withOpacity(0.55)
                            : Colors.white.withOpacity(0.06),
                        width: isActive ? 1.5 : 1,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                  color: color.withOpacity(0.25),
                                  blurRadius: 18)
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: AppTheme.liquidFast,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? color.withOpacity(0.20)
                                : Colors.transparent,
                          ),
                          child: Icon(
                            _iconForZone(zone),
                            color: isActive ? color : AppTheme.textMuted,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          zone.label,
                          style: GoogleFonts.inter(
                            fontSize: 12 * AppTheme.textScale,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w400,
                            color: isActive ? Colors.white : AppTheme.textMuted,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(height: 3),
                          Container(
                            width: 20,
                            height: 2,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1),
                              color: color,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 160.ms);
  }

  Color _colorForZone(SmartZone zone) {
    switch (zone) {
      case SmartZone.home:
        return AppTheme.primary;
      case SmartZone.street:
        return AppTheme.info;
      case SmartZone.office:
        return AppTheme.secondary;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENVIRONMENT STATS — 4 live data cards
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEnvironmentStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('ENVIRONMENT STATS', LucideIcons.barChart2),
        const SizedBox(height: 12),
        Selector<SoundProvider,
            ({List<SoundEvent> history, SoundEvent? last, double amplitude})>(
          selector: (_, p) =>
              (history: p.history, last: p.lastEvent, amplitude: p.amplitude),
          builder: (_, data, __) {
            final todayEvents = data.history
                .where((e) =>
                    e.timestamp.day == DateTime.now().day &&
                    e.timestamp.month == DateTime.now().month)
                .toList();
            final highConf = todayEvents.isEmpty
                ? 0.0
                : todayEvents
                    .map((e) => e.confidence)
                    .reduce((a, b) => a > b ? a : b);
            final emergencies = todayEvents.where((e) => e.isEmergency).length;
            final detectionRate = data.amplitude > 0.05
                ? (data.amplitude * 100).clamp(0, 99)
                : 0.0;

            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                _StatCard(
                  icon: LucideIcons.activity,
                  label: 'Alerts Today',
                  value: '${todayEvents.length}',
                  color: AppTheme.primary,
                  delay: 0,
                ),
                _StatCard(
                  icon: LucideIcons.target,
                  label: 'Peak Confidence',
                  value: '${(highConf * 100).toInt()}%',
                  color: AppTheme.secondary,
                  delay: 40,
                ),
                _StatCard(
                  icon: LucideIcons.shieldAlert,
                  label: 'Emergencies',
                  value: '$emergencies',
                  color: emergencies > 0 ? AppTheme.danger : AppTheme.textMuted,
                  delay: 80,
                ),
                _StatCard(
                  icon: LucideIcons.radio,
                  label: 'Mic Level',
                  value: '${(detectionRate).toInt()}%',
                  color: AppTheme.accentYellow,
                  delay: 120,
                ),
              ],
            );
          },
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVE ACTIVITY
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLiveActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('LIVE ACTIVITY', LucideIcons.activity),
        const SizedBox(height: 12),
        Selector<SoundProvider, SoundEvent?>(
          selector: (_, p) => p.lastEvent,
          builder: (ctx, event, _) {
            if (event == null) {
              return LiquidGlassContainer(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withOpacity(0.08),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.15)),
                      ),
                      child: const Icon(LucideIcons.radio,
                          color: AppTheme.primary, size: 18),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .scale(
                            begin: const Offset(0.95, 0.95),
                            end: const Offset(1.05, 1.05),
                            duration: 1000.ms)
                        .then()
                        .scale(
                            begin: const Offset(1.05, 1.05),
                            end: const Offset(0.95, 0.95),
                            duration: 1000.ms),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No sounds detected',
                            style: GoogleFonts.inter(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14 * AppTheme.textScale)),
                        Text('Ear is open, listening silently...',
                            style: GoogleFonts.inter(
                                color: AppTheme.textMuted,
                                fontSize: 11 * AppTheme.textScale)),
                      ],
                    ),
                  ],
                ),
              );
            }

            final ec = event.isEmergency ? AppTheme.danger : AppTheme.success;
            return LiquidGlassContainer(
              width: double.infinity,
              glow: true,
              glowColor: ec,
              opacity: 0.08,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient:
                              LinearGradient(colors: [ec, ec.withOpacity(0.6)]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppTheme.glow(ec, intensity: 0.6),
                        ),
                        child: Icon(_iconFor(event.label),
                            color: Colors.white, size: 20),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.08, 1.08),
                          duration: 700.ms),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.label,
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15 * AppTheme.textScale),
                                overflow: TextOverflow.ellipsis),
                            Text(
                              event.isEmergency
                                  ? '⚠  EMERGENCY ALERT'
                                  : 'Sound Detected',
                              style: GoogleFonts.inter(
                                  color: ec,
                                  fontSize: 10 * AppTheme.textScale,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${(event.confidence * 100).toInt()}%',
                              style: GoogleFonts.spaceGrotesk(
                                  color: ec,
                                  fontSize: 24 * AppTheme.textScale,
                                  fontWeight: FontWeight.bold)),
                          Text('confidence',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textMuted,
                                  fontSize: 9 * AppTheme.textScale,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: event.confidence),
                      duration: const Duration(milliseconds: 400),
                      builder: (_, v, __) => LinearProgressIndicator(
                        value: v,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(ec),
                        minHeight: 5,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.1, end: 0);
          },
        ),
      ],
    ).animate().fadeIn(delay: 240.ms);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECENT DETECTIONS with confidence bars
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRecentDetections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _label('RECENT DETECTIONS', LucideIcons.clock),
            GestureDetector(
              onTap: () => context.read<SoundProvider>().clearHistory(),
              child: Text(
                'Clear',
                style: GoogleFonts.inter(
                    color: AppTheme.danger.withOpacity(0.7),
                    fontSize: 11 * AppTheme.textScale),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Selector<SoundProvider, List<SoundEvent>>(
          selector: (_, p) => p.recentEvents,
          builder: (_, events, __) {
            if (events.isEmpty) {
              return LiquidGlassContainer(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(LucideIcons.waves,
                        color: AppTheme.textMuted, size: 32),
                    const SizedBox(height: 10),
                    Text('No detections yet',
                        style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: 14 * AppTheme.textScale)),
                    const SizedBox(height: 4),
                    Text('Go to Monitor tab to start',
                        style: GoogleFonts.inter(
                            color: AppTheme.textMuted.withOpacity(0.6),
                            fontSize: 11 * AppTheme.textScale)),
                  ],
                ),
              );
            }

            return Column(
              children: events.take(6).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final ev = entry.value;
                final cc = _catColor(ev.label);
                final h = ev.timestamp.hour.toString().padLeft(2, '0');
                final m = ev.timestamp.minute.toString().padLeft(2, '0');
                final s = ev.timestamp.second.toString().padLeft(2, '0');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: LiquidGlassContainer(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cc.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_iconFor(ev.label), color: cc, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ev.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13 * AppTheme.textScale)),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: ev.confidence,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.05),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      cc.withOpacity(0.7)),
                                  minHeight: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: cc.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${(ev.confidence * 100).toInt()}%',
                                  style: GoogleFonts.inter(
                                      color: cc,
                                      fontSize: 10 * AppTheme.textScale,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(height: 4),
                            Text('$h:$m:$s',
                                style: GoogleFonts.inter(
                                    color: AppTheme.textMuted,
                                    fontSize: 9 * AppTheme.textScale)),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 40 * i))
                    .slideX(begin: 0.05, end: 0);
              }).toList(),
            );
          },
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _label(String t, IconData icon) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 15,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, color: AppTheme.primary, size: 12),
        const SizedBox(width: 6),
        Text(t,
            style: GoogleFonts.inter(
              fontSize: 9.5 * AppTheme.textScale,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
              letterSpacing: 2.2,
            )),
      ],
    );
  }

  IconData _iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('fire') || l.contains('smoke')) return LucideIcons.flame;
    if (l.contains('baby') || l.contains('cry')) return LucideIcons.baby;
    if (l.contains('glass')) return LucideIcons.glassWater;
    if (l.contains('alarm') || l.contains('smoke alarm'))
      return LucideIcons.bellRing;
    if (l.contains('horn') || l.contains('siren')) return LucideIcons.siren;
    if (l.contains('knock') || l.contains('door')) return LucideIcons.doorOpen;
    if (l.contains('dog')) return LucideIcons.dog;
    if (l.contains('phone') || l.contains('ring') || l.contains('bell'))
      return LucideIcons.phone;
    if (l.contains('car') || l.contains('traffic')) return LucideIcons.car;
    return LucideIcons.activity;
  }

  Color _catColor(String label) {
    final l = label.toLowerCase();
    if (l.contains('fire') || l.contains('alarm') || l.contains('siren'))
      return AppTheme.danger;
    if (l.contains('baby') || l.contains('cry')) return AppTheme.warning;
    if (l.contains('dog') || l.contains('bark')) return AppTheme.accentYellow;
    if (l.contains('door') || l.contains('knock')) return AppTheme.info;
    return AppTheme.primary;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card widget
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final int delay;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22 * AppTheme.textScale,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11 * AppTheme.textScale,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).scale(
        begin: const Offset(0.92, 0.92),
        end: const Offset(1, 1),
        delay: Duration(milliseconds: delay),
        curve: Curves.easeOutBack);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Real-Time Spectrum Analyzer — 30fps AnimationController + direct stream
// ─────────────────────────────────────────────────────────────────────────────
class _RealtimeSpectrumCard extends StatefulWidget {
  const _RealtimeSpectrumCard();
  @override
  State<_RealtimeSpectrumCard> createState() => _RealtimeSpectrumCardState();
}

class _RealtimeSpectrumCardState extends State<_RealtimeSpectrumCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  StreamSubscription<List<double>>? _sub;
  List<double> _waveform = [];
  final _service = AudioClassifierService();

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _sub = _service.visualizerStream.listen((data) { _waveform = data; });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<SoundProvider>(context, listen: false);
    final isListening = p.isListening;
    final lastEvent = p.lastEvent;
    final isEmergency = lastEvent?.isEmergency == true;
    return AnimatedBuilder(
      animation: _ticker,
      builder: (_, __) => LiquidGlassContainer(
        width: double.infinity, height: 118, borderRadius: 24, opacity: 0.07,
        glow: isListening, glowColor: isEmergency ? AppTheme.danger : AppTheme.primary,
        child: Stack(children: [
          Positioned.fill(child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: CustomPaint(painter: _SpectrumPainter(
              waveformData: _waveform, amplitude: p.amplitude,
              isListening: isListening, isEmergency: isEmergency,
              tick: _ticker.value,
            )),
          )),
          Positioned(top: 14, left: 16, right: 16,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('SPECTRUM ANALYZER', style: GoogleFonts.inter(
                fontSize: 9 * AppTheme.textScale, fontWeight: FontWeight.w700,
                color: AppTheme.primary, letterSpacing: 2)),
              if (lastEvent != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isEmergency ? AppTheme.danger : AppTheme.success).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: (isEmergency ? AppTheme.danger : AppTheme.success).withOpacity(0.30))),
                  child: Text('${(lastEvent.confidence * 100).toInt()}% CONF',
                    style: GoogleFonts.inter(fontSize: 9 * AppTheme.textScale,
                      fontWeight: FontWeight.w700,
                      color: isEmergency ? AppTheme.danger : AppTheme.success))),
            ])),
          Positioned(bottom: 6, left: 16, right: 16,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['20Hz','250Hz','1kHz','4kHz','20kHz']
                .map((f) => Text(f, style: GoogleFonts.inter(
                  fontSize: 7 * AppTheme.textScale,
                  color: AppTheme.textMuted.withOpacity(0.5)))).toList())),
        ]),
      ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.07, end: 0),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
class _NeuralRingPainter extends CustomPainter {
  final double progress, amplitude;
  final bool isListening;
  final Color color;

  const _NeuralRingPainter({
    required this.progress,
    required this.amplitude,
    required this.isListening,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;

    if (!isListening) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = AppTheme.textMuted.withOpacity(0.2));
      return;
    }

    const dashes = 36;
    for (int i = 0; i < dashes; i++) {
      final angle = (i / dashes) * math.pi * 2 + progress * math.pi * 2;
      final nextAngle =
          ((i + 0.6) / dashes) * math.pi * 2 + progress * math.pi * 2;
      final bright =
          amplitude * math.max(0, math.sin(angle - progress * math.pi)).abs();
      final c1 = Color.lerp(color, AppTheme.secondary, i / dashes)!;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        angle,
        nextAngle - angle,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + amplitude * 2
          ..color = c1.withOpacity(0.45 + bright * 0.5)
          ..strokeCap = StrokeCap.round,
      );
    }

    final innerR = r * 0.62 * (0.85 + amplitude * 0.30);
    canvas.drawCircle(
        c,
        innerR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withOpacity(0.40 + amplitude * 0.50));

    canvas.drawCircle(
        c,
        innerR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = color.withOpacity(0.05 + amplitude * 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    canvas.drawCircle(
        c,
        4,
        Paint()
          ..color = color.withOpacity(0.80)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _NeuralRingPainter old) =>
      old.progress != progress || old.amplitude != amplitude;
}

// ─────────────────────────────────────────────────────────────────────────────
// Spectrum Painter — ALWAYS animated. Real waveform when mic is on, sine-wave idle otherwise.
// ─────────────────────────────────────────────────────────────────────────────
class _SpectrumPainter extends CustomPainter {
  final List<double> waveformData;
  final double amplitude;
  final bool isListening;
  final bool isEmergency;
  final double tick; // 0.0…1.0 from AnimationController, drives idle animation

  static const _bars = 30;

  const _SpectrumPainter({
    required this.waveformData,
    required this.amplitude,
    required this.isListening,
    required this.isEmergency,
    required this.tick,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const paddingH   = 16.0;
    const paddingTop = 36.0;
    const paddingBot = 22.0;
    final availW = size.width - paddingH * 2;
    final barW   = (availW / _bars) - 2.5;
    final maxH   = size.height - paddingTop - paddingBot;

    // Peak-normalise real waveform data so bars fill 20–100% of height
    final double peak = waveformData.isNotEmpty
        ? waveformData.map((v) => v.abs()).fold(0.0, math.max)
        : 0.0;
    final double norm  = peak > 0.001 ? peak : 1.0;
    final bool hasData = waveformData.isNotEmpty && isListening;

    for (int i = 0; i < _bars; i++) {
      double barHeight;

      if (hasData) {
        // — Real microphone waveform —
        final wi = (i / _bars * waveformData.length).toInt().clamp(0, waveformData.length - 1);
        final norm2 = (waveformData[wi].abs() / norm).clamp(0.0, 1.0);
        barHeight = (norm2 * maxH * 0.92 + 4.0).clamp(4.0, maxH);
      } else {
        // — Idle sine-wave animation — always visible even before mic starts
        final phase = tick * 2 * math.pi;
        final sine  = math.sin(phase + i * 0.45) * 0.5 + 0.5; // 0..1
        final idle  = isListening
            ? (amplitude * maxH * 8.0 * (0.3 + sine * 0.7)).clamp(6.0, maxH)
            : (maxH * 0.08 + sine * maxH * 0.12).clamp(4.0, maxH * 0.22);
        barHeight = idle;
      }

      final x  = paddingH + i * (availW / _bars);
      final y  = size.height - barHeight - paddingBot;
      final t  = i / _bars;
      final op = isListening ? 0.92 : 0.35; // dim when mic off

      final Color c1 = isEmergency
          ? Color.lerp(AppTheme.danger, AppTheme.accentOrange, t)!
          : Color.lerp(AppTheme.primary, AppTheme.secondary, t)!;

      // Glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barW, barHeight), const Radius.circular(3)),
        Paint()
          ..color = c1.withOpacity(isListening ? 0.25 : 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barW, barHeight), const Radius.circular(3)),
        Paint()
          ..shader = LinearGradient(
            colors: [c1.withOpacity(op), c1.withOpacity(op * 0.25)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(x, y, barW, barHeight)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter old) => true; // always repaint at 30fps
}

