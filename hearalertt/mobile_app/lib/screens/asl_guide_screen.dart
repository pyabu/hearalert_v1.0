import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/widgets/liquid_background.dart';

class ASLGuideScreen extends StatelessWidget {
  const ASLGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.void_,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'ASL & Signal Guide',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _SectionTitle('Emergency ASL Signs', LucideIcons.siren, AppTheme.danger),
                const SizedBox(height: 12),
                _ASLCard(
                  title: 'HELP',
                  icon: LucideIcons.lifeBuoy,
                  color: AppTheme.primary,
                  description: 'Place your closed right fist (thumbs up) on your flat open left palm. Lift both hands together quickly.',
                  usage: 'If asking for help or offering assistance.',
                ),
                _ASLCard(
                  title: 'FIRE',
                  icon: LucideIcons.flame,
                  color: AppTheme.danger,
                  description: 'Wiggle all 10 fingers while moving your hands up and down in front of your chest, alternating, mimicking leaping flames.',
                  usage: 'Smoke alarm or fire engine detected.',
                ),
                _ASLCard(
                  title: 'HOSPITAL / MEDICAL',
                  icon: LucideIcons.cross,
                  color: AppTheme.info,
                  description: 'Use your dominant hand to draw a cross (✚) on the upper bicep of your non-dominant arm using your index and middle fingers together.',
                  usage: 'Ambulance siren or medical emergency.',
                ),
                _ASLCard(
                  title: 'POLICE',
                  icon: LucideIcons.shieldAlert,
                  color: AppTheme.secondary,
                  description: 'Tap your right hand in a "C" shape against the left side of your chest twice, mimicking a police badge.',
                  usage: 'Police siren or law enforcement approach.',
                ),
                _ASLCard(
                  title: 'DANGER / WARNING',
                  icon: LucideIcons.alertTriangle,
                  color: AppTheme.accentOrange,
                  description: 'Swipe the back of your dominant A-hand (thumb extended) upwards continuously against the back of your non-dominant hand.',
                  usage: 'Car horn, glass breaking, or general hazard.',
                ),
                const SizedBox(height: 32),
                _SectionTitle('App Signal Guide', LucideIcons.activity, AppTheme.accentViolet),
                const SizedBox(height: 12),
                _SignalCard('Emergency', 'Red', 'Highest priority. Sirens, Fire Alarms, Gunshots. Causes strong sustained vibration & rapid flashes.'),
                _SignalCard('Warning', 'Orange', 'Hazards that require attention. Car horns, Glass Breaking. Moderate vibration.'),
                _SignalCard('Info', 'Blue/Violet', 'Everyday sounds. Doorbell, Baby Crying. Single mild pulse.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.bookOpen, color: AppTheme.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Reference Guide',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Use this guide to learn basic American Sign Language (ASL) emergency gestures and understand the color-coded alerts produced by HearAlert.',
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionTitle(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ASLCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final String usage;

  const _ASLCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
    required this.usage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.glassHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.glow(color, intensity: 0.3),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'MOTION:',
            style: GoogleFonts.inter(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.info, color: AppTheme.textMuted, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    usage,
                    style: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  final String level;
  final String colorName;
  final String desc;

  const _SignalCard(this.level, this.colorName, this.desc);

  @override
  Widget build(BuildContext context) {
    Color indicatorColor;
    if (level == 'Emergency') indicatorColor = AppTheme.danger;
    else if (level == 'Warning') indicatorColor = AppTheme.accentOrange;
    else indicatorColor = AppTheme.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glassHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12, height: 12,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: indicatorColor,
              shape: BoxShape.circle,
              boxShadow: AppTheme.glow(indicatorColor, intensity: 0.5),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      level,
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: indicatorColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        colorName,
                        style: GoogleFonts.inter(
                          color: indicatorColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
