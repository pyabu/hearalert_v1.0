import 'package:flutter/material.dart';
import 'package:mobile_app/config/realtime_alert_config.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:mobile_app/providers/sound_provider.dart';

class TestAlertsScreen extends StatelessWidget {
  const TestAlertsScreen({super.key});

  void _triggerFakeAlert(BuildContext context, SoundAlertConfig config) {
    // 1. Manually fire the exact vibration motor pattern physically
    config.triggerVibration();

    // 2. Push a fake detection through the provider to trigger the authentic overlay UI
    context.read<SoundProvider>().simulateEventForced(config.soundId.replaceAll('_', ' '));
  }

  @override
  Widget build(BuildContext context) {
    // Group alerts by priority
    final allConfiguredAlerts = RealtimeAlertDatabase.alerts.values.toList();
    allConfiguredAlerts.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Developer: Test Alerts',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: allConfiguredAlerts.length,
        itemBuilder: (context, index) {
          final config = allConfiguredAlerts[index];
          
          Color priorityColor;
          switch (config.priority) {
            case AlertPriority.critical:
              priorityColor = Colors.redAccent;
              break;
            case AlertPriority.high:
              priorityColor = Colors.orangeAccent;
              break;
            case AlertPriority.medium:
              priorityColor = Colors.blueAccent;
              break;
            case AlertPriority.low:
            case AlertPriority.info:
              priorityColor = Colors.grey;
              break;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  config.icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              title: Text(
                config.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Priority: ${config.priority.name.toUpperCase()}\nPattern: ${config.vibrationPattern}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              trailing: FilledButton.icon(
                onPressed: () => _triggerFakeAlert(context, config),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Trigger'),
                style: FilledButton.styleFrom(
                  backgroundColor: priorityColor.withOpacity(0.3),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
