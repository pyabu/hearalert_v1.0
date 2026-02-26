// Real-time Alert Configuration for HearAlert
// Maps all 26 trained audio categories to display messages and vibration patterns

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Priority levels for sound alerts
enum AlertPriority { critical, high, medium, low, info }

/// Configuration for a single sound alert
class SoundAlertConfig {
  final String soundId;
  final String displayName;
  final String alertMessage;
  final String shortMessage;
  final String description;
  final AlertPriority priority;
  final List<int> vibrationPattern;
  final String icon;
  final int colorHex;
  final double minConfidence;

  const SoundAlertConfig({
    required this.soundId,
    required this.displayName,
    required this.alertMessage,
    required this.shortMessage,
    required this.description,
    required this.priority,
    required this.vibrationPattern,
    required this.icon,
    required this.colorHex,
    this.minConfidence = 0.5,
  });

  /// Trigger completely unique vibration matrix
  Future<void> triggerVibration() async {
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      bool? hasCustomVibrationsSupport = await Vibration.hasCustomVibrationsSupport();

      if (hasVibrator == true && hasCustomVibrationsSupport == true) {
        // Play the exact millisecond array [wait, vibrate, wait, vibrate...]
        await Vibration.vibrate(pattern: vibrationPattern);
        return;
      }

      // Android/iOS Fallback for generic haptics if custom arrays blocked
      switch (priority) {
        case AlertPriority.critical:
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.heavyImpact();
          break;
        case AlertPriority.high:
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 150));
          await HapticFeedback.mediumImpact();
          break;
        case AlertPriority.medium:
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 200));
          await HapticFeedback.lightImpact();
          break;
        case AlertPriority.low:
          await HapticFeedback.lightImpact();
          break;
        case AlertPriority.info:
          await HapticFeedback.selectionClick();
          break;
      }
    } catch (_) {}
  }
}

/// Complete database of all 26 sound alert configurations
class RealtimeAlertDatabase {
  static const Map<String, SoundAlertConfig> alerts = {
    // ═══════════════════════════════════════════════════════════════════
    // CRITICAL PRIORITY (10) - Emergency Alerts
    // ═══════════════════════════════════════════════════════════════════

    'baby_cry': SoundAlertConfig(
      soundId: 'baby_cry',
      displayName: 'Baby Crying',
      alertMessage: '👶 Baby is crying!',
      shortMessage: 'Baby Crying',
      description: 'Your baby needs attention - crying detected',
      priority: AlertPriority.critical,
      vibrationPattern: [0, 500, 200, 500, 200, 500],
      icon: '👶',
      colorHex: 0xFFFF6B9D,
      minConfidence: 0.4,
    ),

    'car_horn': SoundAlertConfig(
      soundId: 'car_horn',
      displayName: 'Car Horn',
      alertMessage: '🚗 Car horn detected!',
      shortMessage: 'Car Horn',
      description: 'Vehicle honking nearby - be alert for traffic',
      priority: AlertPriority.critical,
      vibrationPattern: [0, 300, 100, 300, 100, 300, 100, 300],
      icon: '🚗',
      colorHex: 0xFFFFD700,
      minConfidence: 0.45,
    ),

    'siren': SoundAlertConfig(
      soundId: 'siren',
      displayName: 'Emergency Siren',
      alertMessage: '🚨 Emergency vehicle approaching!',
      shortMessage: 'Siren Alert',
      description: 'Ambulance, police, or fire truck siren detected',
      priority: AlertPriority.critical,
      vibrationPattern: [0, 600, 200, 600, 200, 600, 200, 600], // Slower wailing sweeps pattern
      icon: '🚨',
      colorHex: 0xFFFF4444,
      minConfidence: 0.4,
    ),

    'fire_alarm': SoundAlertConfig(
      soundId: 'fire_alarm',
      displayName: 'Fire Alarm',
      alertMessage: '🔥 FIRE ALARM! Evacuate immediately!',
      shortMessage: 'FIRE ALARM',
      description: 'Fire or smoke alarm detected - check surroundings',
      priority: AlertPriority.critical,
      vibrationPattern: [0, 1500, 500, 1500, 500, 1500], // Extremely long, continuous blare
      icon: '🔥',
      colorHex: 0xFFFF0000,
      minConfidence: 0.35,
    ),

    'gunshot_firework': SoundAlertConfig(
      soundId: 'gunshot_firework',
      displayName: 'Gunshot/Fireworks',
      alertMessage: '💥 Loud bang detected!',
      shortMessage: 'Bang Alert',
      description: 'Gunshot or firework sound detected - stay alert',
      priority: AlertPriority.critical,
      vibrationPattern: [0, 100, 50, 100, 50, 100, 50, 100],
      icon: '💥',
      colorHex: 0xFFDC143C,
      minConfidence: 0.45,
    ),

    'smoke_alarm': SoundAlertConfig(
      soundId: 'smoke_alarm',
      displayName: 'Smoke Alarm',
      alertMessage: '💨 Smoke Alarm Detected!',
      shortMessage: 'Smoke Alarm',
      description: 'Smoke or fire alarm going off. Evacuate if necessary.',
      priority: AlertPriority.critical,
      vibrationPattern: [0, 150, 75, 150, 75, 150, 800],
      icon: '💨',
      colorHex: 0xFFA52A2A,
      minConfidence: 0.35,
    ),

    'car_alarm': SoundAlertConfig(
      soundId: 'car_alarm',
      displayName: 'Car Alarm',
      alertMessage: '🚗 Car alarm is ringing!',
      shortMessage: 'Car Alarm',
      description: 'A car alarm is going off nearby.',
      priority: AlertPriority.critical,
      vibrationPattern: [0, 250, 80, 250, 80, 250, 80, 250, 80, 250, 80, 250],
      icon: '🚗',
      colorHex: 0xFFDC143C,
      minConfidence: 0.45,
    ),

    // ═══════════════════════════════════════════════════════════════════
    // HIGH PRIORITY (8-9) - Safety & Important Alerts
    // ═══════════════════════════════════════════════════════════════════

    'train': SoundAlertConfig(
      soundId: 'train',
      displayName: 'Train',
      alertMessage: '🚂 Train approaching!',
      shortMessage: 'Train Alert',
      description: 'Train horn or railway crossing sound detected',
      priority: AlertPriority.high,
      vibrationPattern: [0, 600, 300, 600, 300, 600],
      icon: '🚂',
      colorHex: 0xFF8B4513,
      minConfidence: 0.45,
    ),

    'glass_breaking': SoundAlertConfig(
      soundId: 'glass_breaking',
      displayName: 'Glass Breaking',
      alertMessage: '💔 Glass breaking detected!',
      shortMessage: 'Glass Break',
      description: 'Window or glass breaking sound - check security',
      priority: AlertPriority.high,
      vibrationPattern: [0, 50, 50, 150, 50, 50, 50, 100], // Sharp, erratic shattering pulse
      icon: '💔',
      colorHex: 0xFF00CED1,
      minConfidence: 0.4,
    ),

    'traffic': SoundAlertConfig(
      soundId: 'traffic',
      displayName: 'Traffic',
      alertMessage: '🚦 Heavy traffic nearby',
      shortMessage: 'Traffic',
      description: 'Vehicle and traffic sounds detected',
      priority: AlertPriority.high,
      vibrationPattern: [0, 200, 150, 300, 200, 250], // Staggered, rumbling engine pattern
      icon: '🚦',
      colorHex: 0xFF808080,
      minConfidence: 0.5,
    ),

    'door_knock': SoundAlertConfig(
      soundId: 'door_knock',
      displayName: 'Door Knock',
      alertMessage: '🚪 Someone is knocking!',
      shortMessage: 'Door Knocked',
      description: 'Someone is knocking at your door',
      priority: AlertPriority.high,
      vibrationPattern: [0, 200, 150, 200, 150, 200],
      icon: '🚪',
      colorHex: 0xFF8B4513,
      minConfidence: 0.4,
    ),

    'doorbell': SoundAlertConfig(
      soundId: 'doorbell',
      displayName: 'Doorbell',
      alertMessage: '🔔 Doorbell ringing!',
      shortMessage: 'Doorbell',
      description: 'Someone rang your doorbell',
      priority: AlertPriority.high,
      vibrationPattern: [0, 600, 200, 600], // Ding... Dong pattern
      icon: '🔔',
      colorHex: 0xFF32CD32,
      minConfidence: 0.45,
    ),

    'speech': SoundAlertConfig(
      soundId: 'speech',
      displayName: 'Human Voice',
      alertMessage: '🗣️ Someone is speaking!',
      shortMessage: 'Voice Detected',
      description: 'Human speech or voice detected nearby',
      priority: AlertPriority.high,
      vibrationPattern: [0, 300, 200, 300],
      icon: '🗣️',
      colorHex: 0xFF6B5B95,
      minConfidence: 0.5,
    ),

    'door_creaking': SoundAlertConfig(
      soundId: 'door_creaking',
      displayName: 'Door Opening',
      alertMessage: '🚪 Door opening detected!',
      shortMessage: 'Door Opening',
      description: 'A door is being opened or closed',
      priority: AlertPriority.high,
      vibrationPattern: [0, 800, 100, 50], // Long creak followed by a subtle click
      icon: '🚪',
      colorHex: 0xFFA0522D,
      minConfidence: 0.45,
    ),

    'chainsaw': SoundAlertConfig(
      soundId: 'chainsaw',
      displayName: 'Power Tools',
      alertMessage: '⚡ Power tools detected!',
      shortMessage: 'Power Tools',
      description: 'Chainsaw or power tool sound nearby',
      priority: AlertPriority.high,
      vibrationPattern: [0, 50, 50, 50, 50, 800], // Engine pull cord then continuous rev
      icon: '⚡',
      colorHex: 0xFFFF4500,
      minConfidence: 0.45,
    ),

    'knock_knock': SoundAlertConfig(
      soundId: 'knock_knock',
      displayName: 'Knocking',
      alertMessage: '🚪 Rapid knocking detected!',
      shortMessage: 'Knocking',
      description: 'Someone is knocking quickly on a door.',
      priority: AlertPriority.high,
      vibrationPattern: [0, 100, 60, 100, 60, 100, 60, 100],
      icon: '🚪',
      colorHex: 0xFFDEB887,
      minConfidence: 0.4,
    ),

    'alarm_clock': SoundAlertConfig(
      soundId: 'alarm_clock',
      displayName: 'Alarm Clock',
      alertMessage: '⏰ Alarm clock is ringing!',
      shortMessage: 'Alarm Clock',
      description: 'An alarm clock is going off nearby.',
      priority: AlertPriority.high,
      vibrationPattern: [0, 180, 120, 180, 120, 180, 120, 180],
      icon: '⏰',
      colorHex: 0xFF00008B,
      minConfidence: 0.45,
    ),

    'microwave_beep': SoundAlertConfig(
      soundId: 'microwave_beep',
      displayName: 'Microwave Beep',
      alertMessage: '⏲️ Microwave is beeping!',
      shortMessage: 'Microwave',
      description: 'A microwave has finished cooking.',
      priority: AlertPriority.high,
      vibrationPattern: [0, 220, 80, 220, 80, 220],
      icon: '⏲️',
      colorHex: 0xFF9370DB,
      minConfidence: 0.45,
    ),

    // ═══════════════════════════════════════════════════════════════════
    // MEDIUM PRIORITY (6-7) - Informational Alerts
    // ═══════════════════════════════════════════════════════════════════

    'phone_ring': SoundAlertConfig(
      soundId: 'phone_ring',
      displayName: 'Phone Ring',
      alertMessage: '📱 Phone is ringing!',
      shortMessage: 'Phone Ringing',
      description: 'Your phone or a phone nearby is ringing',
      priority: AlertPriority.medium,
      vibrationPattern: [0, 400, 150, 400, 1000, 400, 150, 400], // Brrr-brrr... brrr-brrr pattern
      icon: '📱',
      colorHex: 0xFF1E90FF,
      minConfidence: 0.5,
    ),

    'dog_bark': SoundAlertConfig(
      soundId: 'dog_bark',
      displayName: 'Dog Barking',
      alertMessage: '🐕 Dog barking detected!',
      shortMessage: 'Dog Barking',
      description: 'A dog is barking nearby',
      priority: AlertPriority.medium,
      vibrationPattern: [0, 150, 100, 150, 400, 150], // Ruff ruff... ruff pattern
      icon: '🐕',
      colorHex: 0xFFA0522D,
      minConfidence: 0.45,
    ),

    'thunderstorm': SoundAlertConfig(
      soundId: 'thunderstorm',
      displayName: 'Thunderstorm',
      alertMessage: '⛈️ Thunder detected!',
      shortMessage: 'Thunder',
      description: 'Thunderstorm or lightning nearby',
      priority: AlertPriority.medium,
      vibrationPattern: [0, 100, 100, 600, 200, 400], // Lightning strike followed by rolling thunder
      icon: '⛈️',
      colorHex: 0xFF4169E1,
      minConfidence: 0.5,
    ),

    'coughing': SoundAlertConfig(
      soundId: 'coughing',
      displayName: 'Coughing',
      alertMessage: '😷 Coughing detected!',
      shortMessage: 'Coughing',
      description: 'Someone is coughing nearby',
      priority: AlertPriority.medium,
      vibrationPattern: [0, 200, 100, 200],
      icon: '😷',
      colorHex: 0xFFFF7F50,
      minConfidence: 0.5,
    ),

    'breathing': SoundAlertConfig(
      soundId: 'breathing',
      displayName: 'Heavy Breathing',
      alertMessage: '😮‍💨 Heavy breathing/snoring detected!',
      shortMessage: 'Breathing',
      description: 'Heavy breathing or snoring sounds',
      priority: AlertPriority.medium,
      vibrationPattern: [0, 800, 800, 800, 800], // Long, slow rhythmic inhales and exhales
      icon: '😮‍💨',
      colorHex: 0xFF87CEEB,
      minConfidence: 0.5,
    ),

    'helicopter': SoundAlertConfig(
      soundId: 'helicopter',
      displayName: 'Helicopter',
      alertMessage: '🚁 Helicopter nearby!',
      shortMessage: 'Helicopter',
      description: 'Helicopter flying overhead',
      priority: AlertPriority.medium,
      vibrationPattern: [0, 100, 100, 100, 100, 100, 100, 100, 100], // Fast, continuous rotary chopping
      icon: '🚁',
      colorHex: 0xFF708090,
      minConfidence: 0.5,
    ),

    'footsteps': SoundAlertConfig(
      soundId: 'footsteps',
      displayName: 'Footsteps',
      alertMessage: '👣 Footsteps approaching!',
      shortMessage: 'Footsteps',
      description: 'Someone walking or approaching',
      priority: AlertPriority.medium,
      vibrationPattern: [0, 150, 400, 150, 400, 150], // Slow, steady walking pace
      icon: '👣',
      colorHex: 0xFF8B4513,
      minConfidence: 0.5,
    ),

    'washing_machine': SoundAlertConfig(
      soundId: 'washing_machine',
      displayName: 'Washing Machine',
      alertMessage: '🧺 Washing machine running!',
      shortMessage: 'Washer',
      description: 'Washing machine cycle in progress',
      priority: AlertPriority.medium,
      vibrationPattern: [0, 200, 50, 200, 50, 600, 200, 600], // Agitating cycle ending in spin cycle
      icon: '🧺',
      colorHex: 0xFF4682B4,
      minConfidence: 0.5,
    ),

    'water_running': SoundAlertConfig(
      soundId: 'water_running',
      displayName: 'Water Running',
      alertMessage: '🚰 Water is running!',
      shortMessage: 'Water Running',
      description: 'A sink, shower, or water source is running.',
      priority: AlertPriority.medium,
      vibrationPattern: [0, 80, 80, 80, 80, 80, 80, 80, 80],
      icon: '🚰',
      colorHex: 0xFF00FFFF,
      minConfidence: 0.5,
    ),

    // ═══════════════════════════════════════════════════════════════════
    // LOW PRIORITY (4-5) - Ambient Alerts
    // ═══════════════════════════════════════════════════════════════════

    'cat_meow': SoundAlertConfig(
      soundId: 'cat_meow',
      displayName: 'Cat Meowing',
      alertMessage: '🐱 Cat meowing!',
      shortMessage: 'Cat',
      description: 'A cat is meowing nearby',
      priority: AlertPriority.low,
      vibrationPattern: [0, 400, 300, 100], // Long purr ending in a sharp mew
      icon: '🐱',
      colorHex: 0xFFDDA0DD,
      minConfidence: 0.5,
    ),

    'vacuum_cleaner': SoundAlertConfig(
      soundId: 'vacuum_cleaner',
      displayName: 'Vacuum Cleaner',
      alertMessage: '🧹 Vacuum cleaner running!',
      shortMessage: 'Vacuum',
      description: 'Vacuum cleaner is in use',
      priority: AlertPriority.low,
      vibrationPattern: [0, 2000], // Extremely long, monotonous drone
      icon: '🧹',
      colorHex: 0xFF708090,
      minConfidence: 0.55,
    ),

    'airplane': SoundAlertConfig(
      soundId: 'airplane',
      displayName: 'Airplane',
      alertMessage: '✈️ Airplane overhead!',
      shortMessage: 'Airplane',
      description: 'Airplane flying overhead',
      priority: AlertPriority.low,
      vibrationPattern: [0, 400, 300, 400],
      icon: '✈️',
      colorHex: 0xFF4169E1,
      minConfidence: 0.55,
    ),

    'keyboard_typing': SoundAlertConfig(
      soundId: 'keyboard_typing',
      displayName: 'Keyboard Typing',
      alertMessage: '⌨️ Keyboard typing detected!',
      shortMessage: 'Typing',
      description: 'Keyboard or mouse clicking sounds',
      priority: AlertPriority.info,
      vibrationPattern: [0, 30, 80, 40, 60, 30, 50, 40, 70, 30], // Rapid, randomized clacking cadence
      icon: '⌨️',
      colorHex: 0xFF2F4F4F,
      minConfidence: 0.55,
    ),

    'clock_tick': SoundAlertConfig(
      soundId: 'clock_tick',
      displayName: 'Clock Ticking',
      alertMessage: '🕐 Clock ticking!',
      shortMessage: 'Clock',
      description: 'Clock ticking sound detected',
      priority: AlertPriority.info,
      vibrationPattern: [0, 30, 970, 30, 970, 30], // Very short blips exactly 1 second apart
      icon: '🕐',
      colorHex: 0xFFDAA520,
      minConfidence: 0.55,
    ),
  };

  /// Get alert configuration by sound ID
  static SoundAlertConfig? getAlert(String soundId) {
    return alerts[soundId.toLowerCase()];
  }

  /// Get alert by matching label keywords
  static SoundAlertConfig? getAlertByLabel(String label) {
    final lower = label.toLowerCase();

    // Direct match first
    if (alerts.containsKey(lower)) {
      return alerts[lower];
    }

    // Keyword matching
    for (final entry in alerts.entries) {
      // Check if label contains the sound ID
      if (lower.contains(entry.key.replaceAll('_', ' '))) {
        return entry.value;
      }

      // Check specific keyword patterns
      final keywords = _getKeywords(entry.key);
      for (final keyword in keywords) {
        if (lower.contains(keyword)) {
          return entry.value;
        }
      }
    }

    return null;
  }

  /// Get keywords for a sound ID
  static List<String> _getKeywords(String soundId) {
    switch (soundId) {
      case 'baby_cry':
        return ['baby', 'cry', 'infant', 'crying'];
      case 'car_horn':
        return ['horn', 'honk', 'vehicle horn'];
      case 'siren':
        return ['siren', 'ambulance', 'police', 'emergency'];
      case 'fire_alarm':
        return ['fire', 'alarm', 'smoke'];
      case 'gunshot_firework':
        return ['gunshot', 'firework', 'explosion', 'bang'];
      case 'train':
        return ['train', 'railroad', 'railway'];
      case 'glass_breaking':
        return ['glass', 'breaking', 'shatter', 'smash'];
      case 'traffic':
        return ['traffic', 'vehicle', 'engine'];
      case 'door_knock':
        return ['knock', 'knocking', 'door'];
      case 'doorbell':
        return ['doorbell', 'ding', 'dong', 'bell'];
      case 'speech':
        return ['speech', 'voice', 'talking', 'speak', 'laugh'];
      case 'door_creaking':
        return ['creak', 'squeak', 'hinge'];
      case 'chainsaw':
        return ['chainsaw', 'saw', 'power tool'];
      case 'phone_ring':
        return ['phone', 'ring', 'ringtone', 'telephone'];
      case 'dog_bark':
        return ['dog', 'bark', 'barking', 'growl'];
      case 'thunderstorm':
        return ['thunder', 'storm', 'lightning'];
      case 'coughing':
        return ['cough', 'coughing'];
      case 'breathing':
        return ['breath', 'breathing', 'snore', 'snoring'];
      case 'helicopter':
        return ['helicopter', 'chopper'];
      case 'footsteps':
        return ['footstep', 'step', 'walking', 'running'];
      case 'washing_machine':
        return ['washing', 'washer', 'laundry'];
      case 'cat_meow':
        return ['cat', 'meow', 'kitten', 'feline'];
      case 'vacuum_cleaner':
        return ['vacuum', 'cleaner', 'hoover'];
      case 'airplane':
        return ['airplane', 'plane', 'aircraft', 'jet'];
      case 'keyboard_typing':
        return ['keyboard', 'typing', 'mouse', 'click'];
      case 'clock_tick':
        return ['clock', 'tick', 'ticking'];
      default:
        return [];
    }
  }

  /// Get all critical alerts
  static List<SoundAlertConfig> getCriticalAlerts() {
    return alerts.values
        .where((a) => a.priority == AlertPriority.critical)
        .toList();
  }

  /// Get all high priority alerts
  static List<SoundAlertConfig> getHighPriorityAlerts() {
    return alerts.values
        .where((a) => a.priority == AlertPriority.high)
        .toList();
  }
}
