import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_app/providers/settings_provider.dart';
import 'package:mobile_app/providers/sound_provider.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/widgets/liquid_glass_container.dart';
import 'package:mobile_app/widgets/deaf_accessibility.dart';
import 'package:mobile_app/models/models.dart';
import 'package:mobile_app/screens/contacts_screen.dart';
import 'package:mobile_app/screens/asl_guide_screen.dart'; // Added this import
import 'package:mobile_app/screens/test_alerts_screen.dart';
// import 'package:mobile_app/screens/signal_guide_screen.dart'; // Removed this import as it's no longer used

// ─────────────────────────────────────────────────────────────────────────────
// Settings Screen — all 7 sections fully functional
// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 20),
                      _buildHeader(),
                      const SizedBox(height: 24),

                      // ── Appearance ──────────────────────────────────
                      _sectionLabel('Appearance', LucideIcons.palette),
                      const SizedBox(height: 12),
                      LiquidGlassContainer(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: const Column(
                          children: [
                            _ThemeSelector(),
                            _BiosonicDivider(),
                            _AccentColorPicker(),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 50.ms)
                          .slideY(begin: 0.06, end: 0),

                      const SizedBox(height: 24),

                      // ── Accessibility ─────────────────────────────
                      _sectionLabel('Accessibility', LucideIcons.accessibility),
                      const SizedBox(height: 12),
                      Consumer<SettingsProvider>(
                        builder: (_, s, __) => LiquidGlassContainer(
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          child: AccessibilitySettingsSection(
                            highContrast: s.highContrast,
                            largeText: s.largeText,
                            screenFlash: s.screenFlash,
                            onHighContrastChanged: s.setHighContrast,
                            onLargeTextChanged: s.setLargeText,
                            onScreenFlashChanged: s.setScreenFlash,
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 100.ms)
                          .slideY(begin: 0.06, end: 0),

                      const SizedBox(height: 24),

                      // ── Detection ─────────────────────────────────
                      _sectionLabel('Detection', LucideIcons.radar),
                      const SizedBox(height: 12),
                      LiquidGlassContainer(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            _SensitivitySlider(),
                            const _BiosonicDivider(),
                            const _NotificationToggle(),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 150.ms)
                          .slideY(begin: 0.06, end: 0),

                      const SizedBox(height: 24),

                      // ── Smart Zone ─────────────────────────────────
                      _sectionLabel('Smart Zone', LucideIcons.mapPin),
                      const SizedBox(height: 12),
                      LiquidGlassContainer(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: const _SmartZoneSelector(),
                      )
                          .animate()
                          .fadeIn(delay: 175.ms)
                          .slideY(begin: 0.06, end: 0),

                      const SizedBox(height: 24),

                      // ── Feedback ──────────────────────────────────
                      _sectionLabel('Feedback', LucideIcons.zap),
                      const SizedBox(height: 12),
                      LiquidGlassContainer(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            _VibrationSelector(),
                            _BiosonicDivider(),
                            _FlashlightToggle(),
                            _BiosonicDivider(),
                            _TestAlertsLink(),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideY(begin: 0.06, end: 0),

                      const SizedBox(height: 24),

                      // ── Emergency ─────────────────────────────────
                      _sectionLabel('Emergency', LucideIcons.shieldAlert),
                      const SizedBox(height: 12),
                      LiquidGlassContainer(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            _ActionTile(
                              icon: LucideIcons.users,
                              title: 'Emergency Contacts',
                              subtitle: 'Setup SOS contacts',
                              iconColor: AppTheme.danger,
                              badge: Consumer<SettingsProvider>(
                                builder: (_, s, __) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${s.sosContacts.length}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                      fontSize: 12 * AppTheme.textScale,
                                    ),
                                  ),
                                ),
                              ),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const ContactsScreen())),
                            ),
                            const _BiosonicDivider(),
                            _ActionTile(
                              icon: LucideIcons.messageSquare,
                              title: 'SOS Message',
                              subtitle: 'Edit emergency text',
                              iconColor: AppTheme.warning,
                              onTap: () => _showSosDialog(context),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 250.ms)
                          .slideY(begin: 0.06, end: 0),

                      const SizedBox(height: 24),

                      // ── Help & Testing ─────────────────────────────
                      _sectionLabel('Help & Testing', LucideIcons.helpCircle),
                      const SizedBox(height: 12),
                      LiquidGlassContainer(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            _ActionTile(
                              icon: LucideIcons.bookOpen,
                              iconColor: AppTheme.info,
                              title: 'ASL & Signal Guide',
                              subtitle:
                                  'Reference for alerts and American Sign Language',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const ASLGuideScreen()),
                                );
                              },
                            ),
                            const _BiosonicDivider(),
                            _ActionTile(
                              icon: LucideIcons.testTube,
                              title: 'Test Alerts',
                              subtitle: 'Simulate sound detection alerts',
                              iconColor: AppTheme.secondary,
                              onTap: () => _showTestMenu(context),
                            ),
                            const _BiosonicDivider(),
                            _ActionTile(
                              icon: LucideIcons.refreshCcw,
                              title: 'Reset Settings',
                              subtitle: 'Restore all defaults',
                              iconColor: AppTheme.danger,
                              onTap: () => _showResetDialog(context),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 275.ms)
                          .slideY(begin: 0.06, end: 0),

                      const SizedBox(height: 130),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONFIGURATION',
                style: GoogleFonts.inter(
                  fontSize: 10 * AppTheme.textScale,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.4,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Settings',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28 * AppTheme.textScale,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        // Fixed the settings icon appearance
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.glassHigh,
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
          ),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: AppTheme.glow(AppTheme.primary),
            ),
            child: const Icon(LucideIcons.settings2,
                color: Colors.white, size: 28),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.04, end: 0);
  }

  // ── Section label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: AppTheme.primary, size: 14),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10 * AppTheme.textScale,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  // ── Test menu ─────────────────────────────────────────────────────────────
  void _showTestMenu(BuildContext context) {
    // Capture provider reference before the sheet opens
    final soundProvider = context.read<SoundProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: LiquidGlassContainer(
          blurStrength: 28,
          opacity: 0.14,
          borderRadius: 28,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Test Sound Detections',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 18 * AppTheme.textScale,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                'Simulate alerts — bypasses Smart Zone filter',
                style: GoogleFonts.inter(
                    fontSize: 12 * AppTheme.textScale,
                    color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _TestChip('Baby Cry', LucideIcons.baby, AppTheme.warning,
                      soundProvider),
                  _TestChip('Fire Alarm', LucideIcons.flame, AppTheme.danger,
                      soundProvider),
                  _TestChip('Doorbell', LucideIcons.bell, AppTheme.info,
                      soundProvider),
                  _TestChip('Glass Break', LucideIcons.shieldAlert,
                      AppTheme.danger, soundProvider),
                  _TestChip('Dog Bark', LucideIcons.dog, AppTheme.accentYellow,
                      soundProvider),
                  _TestChip('Car Horn', LucideIcons.car, AppTheme.warning,
                      soundProvider),
                  _TestChip('Siren', LucideIcons.siren, AppTheme.danger,
                      soundProvider),
                  _TestChip('Knock', LucideIcons.doorOpen, AppTheme.primary,
                      soundProvider),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── SOS dialog ────────────────────────────────────────────────────────────
  void _showSosDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final controller = TextEditingController(text: settings.sosMessage);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit SOS Message',
            style: GoogleFonts.spaceGrotesk(
                color: AppTheme.textPrimary,
                fontSize: 18 * AppTheme.textScale)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: GoogleFonts.inter(
              color: AppTheme.textPrimary, fontSize: 14 * AppTheme.textScale),
          decoration: InputDecoration(
            hintText: 'Enter your emergency message...',
            hintStyle: GoogleFonts.inter(
                color: AppTheme.textMuted, fontSize: 13 * AppTheme.textScale),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: AppTheme.glassLow,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              settings.setSosMessage(controller.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('SOS message saved',
                      style: GoogleFonts.inter(color: Colors.white)),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: Text('Save',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Reset dialog ──────────────────────────────────────────────────────────
  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle,
                color: AppTheme.danger, size: 20),
            const SizedBox(width: 8),
            Text('Reset Settings',
                style: GoogleFonts.spaceGrotesk(
                    color: AppTheme.textPrimary,
                    fontSize: 18 * AppTheme.textScale)),
          ],
        ),
        content: Text(
          'This will restore all settings to their default values. Your contacts and history will not be affected.',
          style: GoogleFonts.inter(
              color: AppTheme.textSecondary, fontSize: 14 * AppTheme.textScale),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final s = context.read<SettingsProvider>();
              s.setSensitivity(0.5);
              s.setSmartZone(SmartZone.home);
              s.toggleNotifications(true);
              s.setHighContrast(false);
              s.setLargeText(false);
              s.setScreenFlash(true);
              s.setSosMessage(
                  'Help! I am deaf and in an emergency. Please assist me.');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Settings reset to defaults',
                      style: GoogleFonts.inter(color: Colors.white)),
                  backgroundColor: AppTheme.danger,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: Text('Reset',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared divider
// ─────────────────────────────────────────────────────────────────────────────
class _BiosonicDivider extends StatelessWidget {
  const _BiosonicDivider();
  @override
  Widget build(BuildContext context) =>
      Divider(color: AppTheme.primary.withOpacity(0.08), height: 1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme Selector
// ─────────────────────────────────────────────────────────────────────────────
class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (_, s, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.moon,
                      color: AppTheme.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Text('Theme Mode',
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 14 * AppTheme.textScale,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                _StatusBadge(
                  text: s.themeMode == ThemeMode.system
                      ? 'Auto'
                      : s.themeMode == ThemeMode.dark
                          ? 'Dark'
                          : 'Light',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto, size: 14),
                      label: Text('System')),
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode, size: 14),
                      label: Text('Light')),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode, size: 14),
                      label: Text('Dark')),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => s.setThemeMode(v.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? AppTheme.primary
                          : AppTheme.glassHigh),
                  foregroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? Colors.white
                          : AppTheme.textSecondary),
                  side: WidgetStateProperty.all(
                      BorderSide(color: AppTheme.primary.withOpacity(0.20))),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accent Color Picker
// ─────────────────────────────────────────────────────────────────────────────
class _AccentColorPicker extends StatelessWidget {
  const _AccentColorPicker();

  static const _swatches = [
    Color(0xFFA855F7), // Violet (default)
    Color(0xFF00E5CC), // Electric Teal
    Color(0xFFFF2D78), // Hot Pink
    Color(0xFFFFCA28), // Amber
    Color(0xFF39FF14), // Neon Green
    Color(0xFF00BFFF), // Sky Blue
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (_, s, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: s.accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(LucideIcons.palette, color: s.accentColor, size: 16),
                ),
                const SizedBox(width: 12),
                Text('Accent Color',
                    style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 14 * AppTheme.textScale,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                // Preview dot
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: s.accentColor,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.glow(s.accentColor, intensity: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _swatches.map((c) {
                final selected = s.accentColor.value == c.value;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    s.setAccentColor(c);
                  },
                  child: AnimatedContainer(
                    duration: AppTheme.liquidFast,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                  color: c.withOpacity(0.5),
                                  blurRadius: 14,
                                  spreadRadius: 1)
                            ]
                          : null,
                    ),
                    child: selected
                        ? const Icon(LucideIcons.check,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Smart Zone Selector — 3 radio rows
// ─────────────────────────────────────────────────────────────────────────────
class _SmartZoneSelector extends StatelessWidget {
  const _SmartZoneSelector();

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (_, s, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.mapPin,
                    color: AppTheme.primary, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Zone',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14 * AppTheme.textScale,
                            fontWeight: FontWeight.w500)),
                    Text('Only sounds relevant to this zone will alert you',
                        style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11 * AppTheme.textScale)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...[
            (
              zone: SmartZone.home,
              color: AppTheme.primary,
              desc: 'Baby, doorbell, fire & domestic sounds'
            ),
            (
              zone: SmartZone.street,
              color: AppTheme.info,
              desc: 'Car horns, sirens & traffic sounds'
            ),
            (
              zone: SmartZone.office,
              color: AppTheme.secondary,
              desc: 'Phone rings, alarms & office sounds'
            ),
          ].map((cfg) {
            final isActive = s.smartZone == cfg.zone;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                s.setSmartZone(cfg.zone);
              },
              child: AnimatedContainer(
                duration: AppTheme.liquidFast,
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isActive
                      ? cfg.color.withOpacity(0.10)
                      : Colors.transparent,
                  border: Border.all(
                    color: isActive
                        ? cfg.color.withOpacity(0.45)
                        : AppTheme.primary.withOpacity(0.08),
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: AppTheme.liquidFast,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cfg.color.withOpacity(isActive ? 0.20 : 0.08),
                      ),
                      child: Text(cfg.zone.emoji,
                          style: TextStyle(fontSize: 15 * AppTheme.textScale)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cfg.zone.label,
                              style: GoogleFonts.inter(
                                  color: isActive
                                      ? cfg.color
                                      : AppTheme.textPrimary,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 14 * AppTheme.textScale)),
                          Text(cfg.desc,
                              style: GoogleFonts.inter(
                                  color: AppTheme.textMuted,
                                  fontSize: 11 * AppTheme.textScale)),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: AppTheme.liquidFast,
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? cfg.color : Colors.transparent,
                        border: Border.all(
                          color: isActive
                              ? cfg.color
                              : AppTheme.textMuted.withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      child: isActive
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 12)
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Reusable slider tile
// ──────────────────────────────────────────────────────────────────────────
class _SliderTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final double value, min, max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            fontSize: 14 * AppTheme.textScale,
                            fontWeight: FontWeight.w500)),
                    Text(subtitle,
                        style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: 11 * AppTheme.textScale)),
                  ],
                ),
              ),
              _ValueBadge(displayValue, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          _GradientTrackSlider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: iconColor,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification toggle
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationToggle extends StatelessWidget {
  const _NotificationToggle();
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (_, s, __) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              const Icon(LucideIcons.bell, color: AppTheme.primary, size: 18),
        ),
        title: Text('Push Notifications',
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 14 * AppTheme.textScale,
                fontWeight: FontWeight.w500)),
        subtitle: Text('Notify on sound detection events',
            style: GoogleFonts.inter(
                color: AppTheme.textMuted, fontSize: 11 * AppTheme.textScale)),
        value: s.notificationsEnabled,
        onChanged: s.toggleNotifications,
        activeColor: AppTheme.primary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sensitivity Slider
// ─────────────────────────────────────────────────────────────────────────────
class _SensitivitySlider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (_, s, __) => _SliderTile(
        icon: LucideIcons.gauge,
        iconColor: AppTheme.secondary,
        label: 'Detection Sensitivity',
        subtitle: 'Higher = more sounds detected',
        value: s.sensitivity,
        min: 0.0,
        max: 1.0,
        displayValue: '${(s.sensitivity * 100).toInt()}%',
        onChanged: s.setSensitivity,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vibration selector
// ─────────────────────────────────────────────────────────────────────────────
class _VibrationSelector extends StatelessWidget {
  const _VibrationSelector();
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (_, s, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPink.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.vibrate,
                      color: AppTheme.accentPink, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vibration Intensity',
                          style: GoogleFonts.inter(
                              color: AppTheme.textPrimary,
                              fontSize: 14 * AppTheme.textScale,
                              fontWeight: FontWeight.w500)),
                      Text('Tactile feedback strength on alert',
                          style: GoogleFonts.inter(
                              color: AppTheme.textMuted,
                              fontSize: 11 * AppTheme.textScale)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<VibrationIntensity>(
                segments: const [
                  ButtonSegment(
                      value: VibrationIntensity.low,
                      icon: Icon(Icons.vibration, size: 14),
                      label: Text('Low')),
                  ButtonSegment(
                      value: VibrationIntensity.medium,
                      icon: Icon(Icons.vibration, size: 14),
                      label: Text('Medium')),
                  ButtonSegment(
                      value: VibrationIntensity.high,
                      icon: Icon(Icons.vibration, size: 14),
                      label: Text('High')),
                ],
                selected: {s.vibrationIntensity},
                onSelectionChanged: (v) {
                  HapticFeedback.mediumImpact();
                  s.setVibrationIntensity(v.first);
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? AppTheme.accentPink
                          : AppTheme.glassHigh),
                  foregroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? Colors.white
                          : AppTheme.textSecondary),
                  side: WidgetStateProperty.all(
                      BorderSide(color: AppTheme.accentPink.withOpacity(0.22))),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flashlight toggle — reads from SettingsProvider
// ─────────────────────────────────────────────────────────────────────────────
class _FlashlightToggle extends StatelessWidget {
  const _FlashlightToggle();
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (_, s, __) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: AnimatedContainer(
          duration: AppTheme.liquidFast,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (s.flashlightEnabled
                    ? AppTheme.accentYellow
                    : AppTheme.textMuted)
                .withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            s.flashlightEnabled
                ? LucideIcons.flashlight
                : LucideIcons.flashlightOff,
            color: s.flashlightEnabled
                ? AppTheme.accentYellow
                : AppTheme.textMuted,
            size: 18,
          ),
        ),
        title: Text('Flashlight Alerts',
            style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 14 * AppTheme.textScale,
                fontWeight: FontWeight.w500)),
        subtitle: Text(
          s.flashlightEnabled
              ? 'Torch will flash on detection'
              : 'Torch disabled for alerts',
          style: GoogleFonts.inter(
              color: AppTheme.textMuted, fontSize: 11 * AppTheme.textScale),
        ),
        value: s.flashlightEnabled,
        onChanged: (_) {
          HapticFeedback.lightImpact();
          s.toggleFlashlight();
        },
        activeColor: AppTheme.accentYellow,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action tile (navigation rows)
// ─────────────────────────────────────────────────────────────────────────────
class _ActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;
  final Widget? badge;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
    this.badge,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _pressed
              ? AppTheme.primary.withOpacity(0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: AnimatedContainer(
            duration: AppTheme.liquidFast,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.iconColor.withOpacity(_pressed ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: widget.iconColor, size: 18),
          ),
          title: Text(widget.title,
              style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14 * AppTheme.textScale)),
          subtitle: Text(widget.subtitle,
              style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 11 * AppTheme.textScale)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.badge != null) ...[
                widget.badge!,
                const SizedBox(width: 8)
              ],
              Icon(LucideIcons.chevronRight,
                  color: _pressed ? AppTheme.primary : AppTheme.textMuted,
                  size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient slider wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _GradientTrackSlider extends StatelessWidget {
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final Color activeColor;

  const _GradientTrackSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        activeTrackColor: activeColor,
        inactiveTrackColor: AppTheme.glassHigh,
        thumbColor: activeColor,
        overlayColor: activeColor.withOpacity(0.18),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Value badge
// ─────────────────────────────────────────────────────────────────────────────
class _ValueBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _ValueBadge(this.text, {this.color = AppTheme.primary});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12 * AppTheme.textScale)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status badge
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String text;
  const _StatusBadge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 10 * AppTheme.textScale,
              letterSpacing: 0.5)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Test chip — passes provider directly so works outside modal context
// ─────────────────────────────────────────────────────────────────────────────
class _TestChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final SoundProvider provider;
  const _TestChip(this.label, this.icon, this.color, this.provider);
  @override
  State<_TestChip> createState() => _TestChipState();
}

class _TestChipState extends State<_TestChip> {
  bool _fired = false;

  void _fire(BuildContext ctx) {
    if (_fired) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(ctx);
    // Force-simulate bypassing Smart Zone filter
    widget.provider.simulateEventForced(widget.label);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _fire(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.color.withOpacity(0.28)),
          boxShadow: [
            BoxShadow(color: widget.color.withOpacity(0.08), blurRadius: 8)
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 15, color: widget.color),
            const SizedBox(width: 7),
            Text(widget.label,
                style: GoogleFonts.inter(
                    color: widget.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13 * AppTheme.textScale)),
          ],
        ),
      ),
    );
  }
}

class _TestAlertsLink extends StatelessWidget {
  const _TestAlertsLink();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.code, color: Colors.blueAccent),
      ),
      title: Text(
        'Developer: Test Alerts',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16 * AppTheme.textScale,
        ),
      ),
      subtitle: Text(
        'Trigger UI & vibration patterns manually',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 14 * AppTheme.textScale,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TestAlertsScreen()),
        );
      },
    );
  }
}
