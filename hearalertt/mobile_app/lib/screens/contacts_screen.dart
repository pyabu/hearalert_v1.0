import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mobile_app/providers/settings_provider.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/widgets/liquid_glass_container.dart';
import 'package:mobile_app/widgets/liquid_background.dart';
import 'package:mobile_app/models/models.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  // ── Launch phone dialer ────────────────────────────────────────────────────
  Future<void> _callContact(BuildContext context, Contact contact) async {
    final phone = contact.phone.replaceAll(RegExp(r'[\s\-()]'), '');
    final uri = Uri(scheme: 'tel', path: phone);
    HapticFeedback.mediumImpact();
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showCallFallback(context, contact);
      }
    } catch (_) {
      _showCallFallback(context, contact);
    }
  }

  void _showCallFallback(BuildContext context, Contact contact) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: LiquidGlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    AppTheme.success,
                    AppTheme.success.withOpacity(0.6)
                  ]),
                  boxShadow: AppTheme.glow(AppTheme.success),
                ),
                child: const Icon(LucideIcons.phone,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(height: 16),
              Text(contact.name,
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.textPrimary,
                      fontSize: 18 * AppTheme.textScale,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(contact.phone,
                  style: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontSize: 14 * AppTheme.textScale)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: contact.phone));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text('Number copied', style: GoogleFonts.inter()),
                        backgroundColor: AppTheme.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.25)),
                      ),
                      child: Column(children: [
                        const Icon(LucideIcons.copy,
                            color: AppTheme.primary, size: 20),
                        const SizedBox(height: 4),
                        Text('Copy',
                            style: GoogleFonts.inter(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12 * AppTheme.textScale)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final phone =
                          contact.phone.replaceAll(RegExp(r'[\s\-()]'), '');
                      await launchUrl(Uri(scheme: 'tel', path: phone),
                          mode: LaunchMode.externalApplication);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppTheme.success,
                          AppTheme.success.withOpacity(0.7)
                        ]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow:
                            AppTheme.glow(AppTheme.success, intensity: 0.4),
                      ),
                      child: Column(children: [
                        const Icon(LucideIcons.phone,
                            color: Colors.white, size: 20),
                        const SizedBox(height: 4),
                        Text('Call',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12 * AppTheme.textScale)),
                      ]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Add Contact Dialog ─────────────────────────────────────────────────────
  void _showAddContactDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String relation = 'Family';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Add Emergency Contact',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name field
                TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.inter(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                    prefixIcon: const Icon(LucideIcons.user,
                        size: 18, color: AppTheme.primary),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.glassHigh),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Phone field
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.inter(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                    prefixIcon: const Icon(LucideIcons.phone,
                        size: 18, color: AppTheme.success),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.glassHigh),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Relation dropdown
                DropdownButtonFormField<String>(
                  value: relation,
                  dropdownColor: AppTheme.surface,
                  style: GoogleFonts.inter(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Relation',
                    labelStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                    prefixIcon: const Icon(LucideIcons.heart,
                        size: 18, color: AppTheme.danger),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.glassHigh),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                  items: [
                    'Family',
                    'Friend',
                    'Neighbor',
                    'Caregiver',
                    'Service'
                  ]
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => relation = v ?? 'Family'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
            FilledButton.icon(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please fill in both name and phone number',
                          style: GoogleFonts.inter()),
                      backgroundColor: AppTheme.danger,
                    ),
                  );
                  return;
                }
                context.read<SettingsProvider>().addContact(
                      Contact(name: name, phone: phone, relation: relation),
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$name added as emergency contact',
                        style: GoogleFonts.inter()),
                    backgroundColor: AppTheme.success,
                  ),
                );
              },
              icon: const Icon(LucideIcons.userPlus, size: 16),
              label: Text('Add',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete Confirmation ────────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, Contact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove Contact',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Remove ${contact.name} from emergency contacts?',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          FilledButton.icon(
            onPressed: () {
              context.read<SettingsProvider>().removeContact(contact.name);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${contact.name} removed',
                      style: GoogleFonts.inter()),
                  backgroundColor: AppTheme.warning,
                ),
              );
            },
            icon: const Icon(LucideIcons.trash2, size: 16),
            label: Text('Remove',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: LiquidGlassContainer(
            padding: EdgeInsets.zero,
            borderRadius: 12,
            onTap: () => Navigator.pop(context),
            child: Icon(LucideIcons.arrowLeft,
                color: AppTheme.textPrimary, size: 20),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Emergency Contacts",
          style: GoogleFonts.spaceGrotesk(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18 * AppTheme.textScale,
          ),
        ),
      ),
      body: Stack(
        children: [
          const LiquidBackground(subtle: true),
          SafeArea(
            child: Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                final contacts = settings.sosContacts;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // ── Hero Card ──────────────────────────────────
                      LiquidGlassContainer(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: AppTheme.glow(AppTheme.primary,
                                    intensity: 0.6),
                              ),
                              child: const Icon(LucideIcons.userPlus,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Trusted Contacts",
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 20 * AppTheme.textScale,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "They will receive SMS alerts when fire alarms or critical sounds are detected.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                                height: 1.5,
                                fontSize: 14 * AppTheme.textScale,
                              ),
                            ),
                            const SizedBox(height: 24),
                            GestureDetector(
                              onTap: () => _showAddContactDialog(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 28, vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: AppTheme.glow(AppTheme.primary,
                                      intensity: 0.4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.plus,
                                        color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Add Contact",
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14 * AppTheme.textScale,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.05, end: 0),

                      const SizedBox(height: 28),

                      // ── Section Header ─────────────────────────────
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 14),
                          child: Text(
                            contacts.isEmpty
                                ? "NO CONTACTS YET"
                                : "YOUR CONTACTS (${contacts.length})",
                            style: GoogleFonts.inter(
                              fontSize: 11 * AppTheme.textScale,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ),

                      // ── Empty State ────────────────────────────────
                      if (contacts.isEmpty)
                        LiquidGlassContainer(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 48, horizontal: 24),
                          child: Column(
                            children: [
                              Icon(LucideIcons.userPlus,
                                  size: 48,
                                  color: AppTheme.textMuted.withOpacity(0.4)),
                              const SizedBox(height: 16),
                              Text(
                                "No emergency contacts added yet",
                                style: GoogleFonts.inter(
                                  color: AppTheme.textMuted,
                                  fontSize: 15 * AppTheme.textScale,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Tap 'Add Contact' above to get started",
                                style: GoogleFonts.inter(
                                  color: AppTheme.textMuted.withOpacity(0.6),
                                  fontSize: 12 * AppTheme.textScale,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms),

                      // ── Contact Items ──────────────────────────────
                      ...contacts.asMap().entries.map((entry) {
                        final i = entry.key;
                        final c = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildContactItem(context, c, i),
                        );
                      }),

                      const SizedBox(height: 60),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Contact Card ───────────────────────────────────────────────────────────
  Widget _buildContactItem(BuildContext context, Contact contact, int index) {
    return LiquidGlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.glassHigh, AppTheme.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            alignment: Alignment.center,
            child: Text(
              contact.name[0].toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontSize: 16 * AppTheme.textScale,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + phone + relation
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontSize: 15 * AppTheme.textScale,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      contact.phone,
                      style: GoogleFonts.inter(
                        fontSize: 12 * AppTheme.textScale,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        contact.relation,
                        style: GoogleFonts.inter(
                          fontSize: 10 * AppTheme.textScale,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Call button — launches phone dialer
              _ActionButton(
                icon: LucideIcons.phone,
                color: AppTheme.success,
                onTap: () => _callContact(context, contact),
              ),
              const SizedBox(width: 6),
              // Delete button
              _ActionButton(
                icon: LucideIcons.trash2,
                color: AppTheme.danger,
                onTap: () => _confirmDelete(context, contact),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: (80 * index).ms).fadeIn().slideX(begin: 0.03, end: 0);
  }
}

// ── Action Button ────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
