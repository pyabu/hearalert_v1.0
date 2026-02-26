import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:mobile_app/providers/sound_provider.dart';
import 'package:mobile_app/providers/settings_provider.dart';
import 'package:mobile_app/screens/home_screen.dart';
import 'package:mobile_app/screens/realtime_alerts_screen.dart';
import 'package:mobile_app/screens/history_screen.dart';
import 'package:mobile_app/screens/settings_screen.dart';
import 'package:mobile_app/widgets/liquid_background.dart';
import 'package:mobile_app/widgets/screen_alert_overlay.dart';
import 'package:mobile_app/widgets/sound_alert_dialog.dart';
import 'package:mobile_app/widgets/baby_cry_alert_dialog.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/models/models.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});
  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold>
    with TickerProviderStateMixin {
  int _index = 0;
  late AnimationController _badgeController;
  late AnimationController _navController;
  DateTime? _lastAlertTimestamp;
  DateTime? _lastBabyCryAlertTimestamp;
  SoundProvider? _soundProviderRef;

  static const _navItems = [
    _NavItem(LucideIcons.home, LucideIcons.home, 'Home'),
    _NavItem(LucideIcons.radar, LucideIcons.radar, 'Monitor'),
    _NavItem(LucideIcons.clock, LucideIcons.clock, 'History'),
    _NavItem(LucideIcons.settings2, LucideIcons.settings2, 'Settings'),
  ];

  static const _screens = [
    HomeScreen(),
    RealtimeAlertsScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _navController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final soundProvider = context.read<SoundProvider>();
      soundProvider.updateSettings(
            context.read<SettingsProvider>(),
          );
      _soundProviderRef = soundProvider;
      _soundProviderRef!.addListener(_checkForAlerts);
    });
  }

  void _checkForAlerts() {
    if (_soundProviderRef == null || !mounted) return;
    
    // Check Baby Cry Alerts first
    final lastBabyCry = _soundProviderRef!.lastBabyCryDetection;
    if (lastBabyCry != null && _lastBabyCryAlertTimestamp != lastBabyCry.timestamp) {
      _lastBabyCryAlertTimestamp = lastBabyCry.timestamp;
      showDialog(
        context: context,
        barrierDismissible: !lastBabyCry.isHighPriority,
        builder: (context) => BabyCryAlertDialog(prediction: lastBabyCry),
      );
      // Wait to not show both dialogs at exactly the same time. Since baby cry 
      // is most important, skip general alert this frame.
      return; 
    }

    final lastEvent = _soundProviderRef!.lastEvent;
    if (lastEvent != null && 
        (lastEvent.type == 'emergency' || lastEvent.type == 'warning')) {
      if (_lastAlertTimestamp != lastEvent.timestamp) {
        _lastAlertTimestamp = lastEvent.timestamp;
        showDialog(
          context: context,
          barrierDismissible: lastEvent.type != 'emergency', // critical alerts must be acknowledged
          builder: (context) => SoundAlertDialog(event: lastEvent),
        );
      }
    }
  }

  @override
  void dispose() {
    _soundProviderRef?.removeListener(_checkForAlerts);
    _badgeController.dispose();
    _navController.dispose();
    super.dispose();
  }

  void _switchTab(int i) {
    if (i == _index) return;
    HapticFeedback.lightImpact();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.void_,
      extendBody: true,
      body: Stack(
        children: [
          const LiquidBackground(),
          IndexedStack(index: _index, children: _screens),
          const ScreenAlertOverlay(),
        ],
      ),
      bottomNavigationBar: _LiquidGlassNavBar(
        index: _index,
        items: _navItems,
        badgeController: _badgeController,
        onTap: _switchTab,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Liquid Glass Nav Bar with ripple-from-tap-point effect
// ─────────────────────────────────────────────────────────────────────────────
class _LiquidGlassNavBar extends StatefulWidget {
  final int index;
  final List<_NavItem> items;
  final AnimationController badgeController;
  final ValueChanged<int> onTap;

  const _LiquidGlassNavBar({
    required this.index,
    required this.items,
    required this.badgeController,
    required this.onTap,
  });

  @override
  State<_LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<_LiquidGlassNavBar>
    with TickerProviderStateMixin {
  final List<_RippleData> _ripples = [];

  void _handleTapDown(
      TapDownDetails details, BoxConstraints constraints, double animSpeed) {
    final ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (700 / animSpeed).round()),
    );
    final ripple = _RippleData(
      offset: details.localPosition,
      controller: ctrl,
    );
    setState(() => _ripples.add(ripple));

    ctrl.forward().whenComplete(() {
      setState(() => _ripples.remove(ripple));
      ctrl.dispose();
    });
  }

  @override
  void dispose() {
    for (final r in _ripples) {
      r.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Consumer<SettingsProvider>(
      builder: (_, settings, __) {
        final double blurAmount = 20.0; // Reduced from 40.0 for performance
        final double opacityMult = settings.glassIntensity *
            2; // Default settings.glassIntensity is around 0.1-0.3
        final double animSpeed = settings.animationSpeed;

        return Container(
          margin: EdgeInsets.fromLTRB(14, 0, 14, bottom + 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _handleTapDown(d, constraints, animSpeed),
                    child: AnimatedContainer(
                      duration:
                          Duration(milliseconds: (300 / animSpeed).round()),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.12 * opacityMult),
                            settings.accentColor
                                .withOpacity(0.06 * opacityMult),
                            AppTheme.void_
                                .withOpacity(0.65 + (0.2 * opacityMult)),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15 * opacityMult),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: settings.accentColor
                                .withOpacity(0.15 * opacityMult),
                            blurRadius: 36,
                            offset: const Offset(0, -4),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.40),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // ── Ripple Layer ───────────────────────────────────
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: CustomPaint(
                                painter: _RipplePainter(
                                    _ripples, settings.accentColor),
                              ),
                            ),
                          ),
                          // ── Status Strip + Nav Items ───────────────────────
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Micro status strip
                              _StatusStrip(
                                  badgeController: widget.badgeController),
                              // Nav items row
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 2, 10, 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: List.generate(
                                    widget.items.length,
                                    (i) => _NavCell(
                                      item: widget.items[i],
                                      isSelected: widget.index == i,
                                      showBadge: i == 1,
                                      badgeController: widget.badgeController,
                                      onTap: () => widget.onTap(i),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ripple data model + painter
// ─────────────────────────────────────────────────────────────────────────────
class _RippleData {
  final Offset offset;
  final AnimationController controller;
  _RippleData({required this.offset, required this.controller});
}

class _RipplePainter extends CustomPainter {
  final List<_RippleData> ripples;
  final Color accentColor;
  _RipplePainter(this.ripples, this.accentColor)
      : super(
            repaint: Listenable.merge(
          ripples.map((r) => r.controller).toList(),
        ));

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in ripples) {
      final t = r.controller.value;
      final maxRadius = math.max(size.width, size.height) * 0.9;
      final radius = maxRadius * Curves.easeOutQuart.transform(t);
      final opacity = (1.0 - t) * 0.25;

      final paint = Paint()
        ..color = accentColor.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(r.offset, radius, paint);

      // Thin ring outline
      final ringPaint = Paint()
        ..color = accentColor.withOpacity(opacity * 1.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(r.offset, radius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Status strip
// ─────────────────────────────────────────────────────────────────────────────
class _StatusStrip extends StatelessWidget {
  final AnimationController badgeController;
  const _StatusStrip({required this.badgeController});

  @override
  Widget build(BuildContext context) {
    return Selector<SoundProvider,
        ({bool isListening, int count, SmartZone? zone})>(
      selector: (_, p) => (
        isListening: p.isListening,
        count: p.history.length,
        zone: p.settings?.smartZone,
      ),
      builder: (_, data, __) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: data.isListening
              ? AppTheme.primary.withOpacity(0.06)
              : Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            bottom: BorderSide(
              color: AppTheme.primary.withOpacity(0.07),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              AnimatedBuilder(
                animation: badgeController,
                builder: (_, __) => Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: data.isListening
                        ? AppTheme.secondary
                            .withOpacity(0.4 + badgeController.value * 0.6)
                        : AppTheme.textMuted,
                    boxShadow: data.isListening
                        ? [
                            BoxShadow(
                                color: AppTheme.secondary
                                    .withOpacity(badgeController.value * 0.6),
                                blurRadius: 7)
                          ]
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                data.isListening ? 'LIVE  ·  DETECTION' : 'STANDBY',
                style: GoogleFonts.inter(
                  fontSize: 8 * AppTheme.textScale,
                  fontWeight: FontWeight.w700,
                  color:
                      data.isListening ? AppTheme.primary : AppTheme.textMuted,
                  letterSpacing: 1.6,
                ),
              ),
            ]),
            if (data.zone != null)
              Text(
                '${data.zone!.emoji} ${data.zone!.label}',
                style: GoogleFonts.inter(
                  fontSize: 8 * AppTheme.textScale,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.4,
                ),
              )
            else
              Text(
                data.count == 0 ? 'No events' : '${data.count} events',
                style: GoogleFonts.inter(
                    fontSize: 8 * AppTheme.textScale,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single nav cell with bouncy scale press animation
// ─────────────────────────────────────────────────────────────────────────────
class _NavCell extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final bool showBadge;
  final AnimationController badgeController;
  final VoidCallback onTap;

  const _NavCell({
    required this.item,
    required this.isSelected,
    required this.showBadge,
    required this.badgeController,
    required this.onTap,
  });

  @override
  State<_NavCell> createState() => _NavCellState();
}

class _NavCellState extends State<_NavCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    reverseDuration: const Duration(milliseconds: 300),
    lowerBound: 0.88,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _pressCtrl.animateTo(0.88);
  void _onTapUp(_) {
    _pressCtrl.animateTo(1.0,
        curve: Curves.elasticOut, duration: const Duration(milliseconds: 400));
    widget.onTap();
    HapticFeedback.lightImpact();
  }

  void _onTapCancel() => _pressCtrl.animateTo(1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (_, child) => Transform.scale(
          scale: _pressCtrl.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: AppTheme.liquidFast,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: widget.isSelected
                ? LinearGradient(
                    colors: [
                      AppTheme.primary.withOpacity(0.24),
                      AppTheme.secondary.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            border: widget.isSelected
                ? Border.all(
                    color: AppTheme.primary.withOpacity(0.38), width: 1)
                : null,
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.20),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: AppTheme.liquidFast,
                    child: Icon(
                      widget.isSelected
                          ? widget.item.activeIcon
                          : widget.item.icon,
                      key: ValueKey(widget.isSelected),
                      color: widget.isSelected
                          ? AppTheme.primary
                          : AppTheme.textMuted,
                      size: 22,
                    ),
                  ),
                  if (widget.showBadge)
                    Selector<SoundProvider, SoundEvent?>(
                      selector: (_, p) => p.lastEvent,
                      builder: (_, event, __) {
                        if (event == null) return const SizedBox.shrink();
                        return Positioned(
                          right: -4,
                          top: -4,
                          child: AnimatedBuilder(
                            animation: widget.badgeController,
                            builder: (_, __) => Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: event.isEmergency
                                    ? AppTheme.danger
                                    : AppTheme.secondary,
                                boxShadow: [
                                  BoxShadow(
                                    color: (event.isEmergency
                                            ? AppTheme.danger
                                            : AppTheme.secondary)
                                        .withOpacity(0.5 +
                                            widget.badgeController.value * 0.4),
                                    blurRadius: 8,
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: AppTheme.liquidFast,
                style: GoogleFonts.inter(
                  fontSize: 9.5 * AppTheme.textScale,
                  fontWeight:
                      widget.isSelected ? FontWeight.w700 : FontWeight.w400,
                  color:
                      widget.isSelected ? AppTheme.primary : AppTheme.textMuted,
                  letterSpacing: widget.isSelected ? 0.5 : 0,
                ),
                child: Text(widget.item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
