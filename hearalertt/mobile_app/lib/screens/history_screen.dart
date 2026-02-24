import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_app/providers/sound_provider.dart';
import 'package:mobile_app/widgets/liquid_glass_container.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/models/models.dart';
import 'package:mobile_app/services/firebase_database_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  String _filter = 'All';
  late TabController _tc;
  static const _filters = ['All', '🚨 Emergency', '⚠ Warning', 'ℹ Info'];

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: _filters.length, vsync: this);
    _tc.addListener(() {
      if (!_tc.indexIsChanging) return;
      setState(() => _filter = _filters[_tc.index]);
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 16),
                _buildStatsRow(),
                const SizedBox(height: 16),
                _buildFilterBar(),
                const SizedBox(height: 12),
                Expanded(child: _buildList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DETECTION LOG',
                  style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: AppTheme.primary, letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'History',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28, fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary, letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Consumer<SoundProvider>(
            builder: (_, p, __) => GestureDetector(
              onTap: () => _confirmClear(context, p),
              child: LiquidGlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                blurStrength: 16,
                borderRadius: 12,
                child: Row(
                  children: [
                    const Icon(LucideIcons.trash2, color: AppTheme.danger, size: 14),
                    const SizedBox(width: 6),
                    Text('Clear',
                        style: GoogleFonts.inter(
                            color: AppTheme.danger, fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.04, end: 0);
  }

  // ─────────────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseDatabaseService().alertsStream,
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 100);
        final hist = snapshot.data!.map((e) => SoundEvent(
          id: e['id'] ?? '',
          label: e['label'] ?? '',
          confidence: (e['confidence'] as num?)?.toDouble() ?? 0.0,
          timestamp: e['timestamp'] != null ? DateTime.fromMillisecondsSinceEpoch(e['timestamp'] as int) : DateTime.now(),
          type: e['type'] ?? 'info',
        )).toList();

        final emergency = hist.where((e) => e.type == 'emergency').length;
        final warning = hist.where((e) => e.type == 'warning').length;
        final info = hist.length - emergency - warning;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _StatBox('${hist.length}', 'Total Events', AppTheme.primary),
              const SizedBox(width: 8),
              _StatBox('$emergency', 'Emergency', AppTheme.danger),
              const SizedBox(width: 8),
              _StatBox('$warning', 'Warnings', AppTheme.warning),
              const SizedBox(width: 8),
              _StatBox('$info', 'Info', AppTheme.info),
            ],
          ),
        );
      },
    ).animate().fadeIn(delay: 80.ms);
  }

  // ─────────────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.glassLow.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.08)),
        ),
        child: TabBar(
          controller: _tc,
          isScrollable: true,
          splashBorderRadius: BorderRadius.circular(14),
          dividerHeight: 0,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: AppTheme.biosonicGradient,
          ),
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400),
          tabs: _filters.map((f) => Tab(text: f)).toList(),
          padding: const EdgeInsets.all(4),
          tabAlignment: TabAlignment.start,
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  // ─────────────────────────────────────────────────────────────────────
  Widget _buildList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseDatabaseService().alertsStream,
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        final hist = snapshot.data!.map((e) => SoundEvent(
          id: e['id'] ?? '',
          label: e['label'] ?? '',
          confidence: (e['confidence'] as num?)?.toDouble() ?? 0.0,
          timestamp: e['timestamp'] != null ? DateTime.fromMillisecondsSinceEpoch(e['timestamp'] as int) : DateTime.now(),
          type: e['type'] ?? 'info',
        )).toList();

        // Filter by selected tab
        final filtered = hist.where((e) {
          if (_filter == 'All') return true;
          if (_filter.contains('Emergency')) return e.type == 'emergency';
          if (_filter.contains('Warning')) return e.type == 'warning';
          if (_filter.contains('Info')) return e.type == 'info';
          return true;
        }).toList();

        if (filtered.isEmpty) {
          return _buildEmpty();
        }

        // Group by date
        final grouped = <String, List<SoundEvent>>{};
        for (final e in filtered) {
          final key = _dateKey(e.timestamp);
          grouped.putIfAbsent(key, () => []).add(e);
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: grouped.length,
          itemBuilder: (ctx, i) {
            final key = grouped.keys.elementAt(i);
            final events = grouped[key]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 24, height: 1,
                        color: AppTheme.primary.withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                      Text(key,
                          style: GoogleFonts.inter(
                            fontSize: 10, color: AppTheme.primary,
                            fontWeight: FontWeight.w600, letterSpacing: 1.5,
                          )),
                      const SizedBox(width: 8),
                      Expanded(child: Container(height: 1,
                          color: AppTheme.primary.withOpacity(0.3))),
                    ],
                  ),
                ),
                ...events.asMap().entries.map((entry) =>
                    _buildEventTile(entry.value, entry.key)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.primary.withOpacity(0.10), Colors.transparent]),
            ),
            child: const Icon(LucideIcons.waves,
                color: AppTheme.primary, size: 48),
          ),
          const SizedBox(height: 16),
          Text('No${_filter == 'All' ? '' : ' $_filter'} events yet',
              style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.textPrimary, fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Detected sounds will appear here',
              style: GoogleFonts.inter(
                  color: AppTheme.textMuted, fontSize: 13)),
        ],
      ).animate().fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
    );
  }

  Widget _buildEventTile(SoundEvent ev, int i) {
    final cc = _catColor(ev.label);
    final isEmergency = ev.type == 'emergency';
    final isWarning = ev.type == 'warning';
    final typeLabel = isEmergency ? 'EMERGENCY' : isWarning ? 'WARNING' : 'DETECTED';
    final h = ev.timestamp.hour.toString().padLeft(2, '0');
    final m = ev.timestamp.minute.toString().padLeft(2, '0');
    final s = ev.timestamp.second.toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LiquidGlassContainer(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        opacity: 0.06,
        child: Row(
          children: [
            // Left color accent bar
            Container(
              width: 3, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cc, cc.withOpacity(0.3)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Icon
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: cc.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconFor(ev.label), color: cc, size: 18),
            ),
            const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ev.label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(typeLabel,
                      style: GoogleFonts.inter(
                          color: cc, fontSize: 9,
                          fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                ],
              ),
            ),

            // Right: confidence + time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${(ev.confidence * 100).toInt()}%',
                      style: GoogleFonts.inter(
                          color: cc, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 5),
                Text('$h:$m:$s',
                    style: GoogleFonts.inter(
                        color: AppTheme.textMuted, fontSize: 9.5)),
              ],
            ),
          ],
        ),
      ).animate()
          .fadeIn(delay: Duration(milliseconds: 30 * i))
          .slideX(begin: 0.04, end: 0),
    );
  }

  String _dateKey(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'TODAY';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'YESTERDAY';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _confirmClear(BuildContext ctx, SoundProvider p) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear History',
            style: GoogleFonts.spaceGrotesk(
                color: AppTheme.textPrimary, fontSize: 18)),
        content: Text(
          'All ${p.history.length} detection events will be removed.',
          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              p.clearHistory();
              FirebaseDatabaseService().clearAllAlerts();
              Navigator.pop(ctx);
            },
            child: Text('Clear All',
                style: GoogleFonts.inter(
                    color: AppTheme.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _catColor(String label) {
    final l = label.toLowerCase();
    if (l.contains('fire') || l.contains('alarm') || l.contains('siren'))
      return AppTheme.danger;
    if (l.contains('baby') || l.contains('cry')) return AppTheme.warning;
    if (l.contains('dog') || l.contains('bark')) return AppTheme.accentYellow;
    if (l.contains('door') || l.contains('knock') || l.contains('bell'))
      return AppTheme.info;
    return AppTheme.primary;
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
    if (l.contains('phone') || l.contains('ring') || l.contains('bell'))
      return LucideIcons.phone;
    return LucideIcons.activity;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatBox(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.14), color.withOpacity(0.04)],
          ),
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.spaceGrotesk(
                    color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppTheme.textMuted, fontSize: 9, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}
