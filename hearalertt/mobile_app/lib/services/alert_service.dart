import 'package:vibration/vibration.dart';
import 'dart:io';
import 'package:torch_light/torch_light.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:developer';
import 'package:mobile_app/services/notification_service.dart';
import 'package:mobile_app/models/models.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isFlashing = false;
  bool notificationsEnabled = true;

  Future<void> initialize() async {
    log("AlertService initialized");
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      log("TTS Initialization failed: $e");
    }

    await NotificationService().initialize();

    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      return;
    }
  }

  Future<void> _notify(String title, String body) async {
    if (!notificationsEnabled) return;
    await NotificationService().showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
    );
  }

  Future<void> triggerFireAlarm(
      {bool withFlash = false,
      VibrationIntensity intensity = VibrationIntensity.high}) async {
    _speak("Fire Alarm Detected");
    _notify("Critical Alert", "Fire Alarm Detected! Take action immediately.");
    if (withFlash) _triggerFlashlightPattern(duration: 5000, flashDelay: 50);

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(
        pattern: [
          0,
          100,
          100,
          100,
          100,
          100,
          200,
          300,
          200,
          300,
          200,
          300,
          200,
          100,
          100,
          100,
          100,
          100
        ],
        intensity: intensity,
      );
    }
  }

  Future<void> triggerVehicleHorn(
      {bool withFlash = false,
      VibrationIntensity intensity = VibrationIntensity.high}) async {
    _speak("Car Horn Detected");
    _notify("Traffic Alert", "Car Horn detected nearby.");
    if (withFlash) _triggerFlashlightPattern(duration: 4000, flashDelay: 500);

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(
          pattern: [0, 1000, 500, 1000, 500, 1000], intensity: intensity);
    }
  }

  Future<void> triggerDoorKnock(
      {bool withFlash = false,
      VibrationIntensity intensity = VibrationIntensity.high}) async {
    _speak("Door Knock Detected");
    _notify("Alert", "Door Knock detected.");
    if (withFlash) {
      _triggerFlashlightPattern(duration: 1500, flashDelay: 150);
    }

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(
          pattern: [0, 120, 80, 120, 300, 120, 80, 120], intensity: intensity);
    }
  }

  Future<void> triggerBabyCry(
      {bool withFlash = false,
      VibrationIntensity intensity = VibrationIntensity.high}) async {
    _speak("Baby Crying Detected");
    _notify("Alert", "Baby Crying detected.");
    if (withFlash) _triggerFlashlightPattern(duration: 5000, flashDelay: 800);

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(pattern: [0, 50, 100, 50], intensity: intensity);
    }
  }

  Future<void> triggerGlassBreaking(
      {bool withFlash = false,
      VibrationIntensity intensity = VibrationIntensity.high}) async {
    _speak("Glass Break Detected");
    _notify("Security Alert", "Glass Breaking detected!");
    if (withFlash) _triggerFlashlightPattern(duration: 3000, flashDelay: 40);

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(pattern: [
        0,
        40,
        30,
        40,
        30,
        40,
        30,
        40,
        30,
        40,
        100,
        300,
        100,
        40,
        30,
        40,
        30,
        40,
        30,
        40,
      ], intensity: intensity);
    }
  }

  Future<void> triggerDogBark(
      {bool withFlash = false,
      VibrationIntensity intensity = VibrationIntensity.high}) async {
    _speak("Dog Barking Detected");
    _notify("Alert", "Dog Barking detected.");
    if (withFlash) _triggerFlashlightPattern(duration: 2000, flashDelay: 200);

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(pattern: [0, 200, 100, 200], intensity: intensity);
    }
  }

  Future<void> triggerSiren(
      {bool withFlash = false,
      VibrationIntensity intensity = VibrationIntensity.high}) async {
    _speak("Emergency Siren Detected");
    _notify("Critical Alert", "Siren detected! Use caution.");
    if (withFlash) _triggerFlashlightPattern(duration: 5000, flashDelay: 100);

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(
        pattern: [0, 800, 200, 800, 200, 800, 200, 800],
        intensity: intensity,
      );
    }
  }

  Future<void> triggerHumanDistress(
      {bool withFlash = false,
      VibrationIntensity intensity = VibrationIntensity.high}) async {
    _speak("Human Distress Detected");
    _notify("Emergency", "Human Distress/Scream detected!");
    if (withFlash) _triggerFlashlightPattern(duration: 4000, flashDelay: 100);

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(
          pattern: [0, 500, 200, 500, 200, 500], intensity: intensity);
    }
  }

  Future<void> triggerDoorbell(
      {bool withFlash = false,
      VibrationIntensity intensity = VibrationIntensity.high}) async {
    _speak("Doorbell Ring Detected");
    _notify("Alert", "Doorbell Ring detected.");
    if (withFlash) _triggerFlashlightPattern(duration: 1200, flashDelay: 200);

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(pattern: [0, 150, 150, 250], intensity: intensity);
    }
  }

  Future<void> triggerExplosion(
      {bool withFlash = false,
      VibrationIntensity intensity = VibrationIntensity.high}) async {
    _speak("Danger Detected! Take Cover!");
    _notify("DANGER", "Explosion/Gunshot detected! Take cover.");
    if (withFlash) _triggerFlashlightPattern(duration: 5000, flashDelay: 30);

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(pattern: [
        0,
        100,
        50,
        100,
        50,
        100,
        150,
        300,
        100,
        300,
        100,
        300,
        150,
        100,
        50,
        100,
        50,
        100,
        200,
        500,
      ], intensity: intensity);
    }
  }

  Future<void> triggerPhoneRing(
      {bool withFlash = false,
      VibrationIntensity intensity = VibrationIntensity.high}) async {
    _speak("Phone Ringing");
    _notify("Alert", "Phone Ringing detected.");
    if (withFlash) _triggerFlashlightPattern(duration: 3000, flashDelay: 300);

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(
          pattern: [0, 200, 100, 200, 500, 200, 100, 200],
          intensity: intensity);
    }
  }

  Future<void> triggerAnimalAlert(
      {bool withFlash = false,
      String animalName = 'Animal',
      VibrationIntensity intensity = VibrationIntensity.high}) async {
    _speak("$animalName Detected nearby");
    _notify("Alert", "$animalName detected nearby.");
    if (withFlash) _triggerFlashlightPattern(duration: 2000, flashDelay: 400);

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(
          pattern: [0, 200, 150, 200, 150, 200], intensity: intensity);
    }
  }

  Future<void> triggerDangerousAnimal(
      {bool withFlash = false,
      String animalName = 'Danger',
      VibrationIntensity intensity = VibrationIntensity.high}) async {
    _speak("Warning! $animalName detected!");
    _notify("Danger", "Dangerous Animal ($animalName) detected!");
    if (withFlash) _triggerFlashlightPattern(duration: 4000, flashDelay: 100);

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(
          pattern: [0, 300, 100, 300, 100, 500, 200, 500],
          intensity: intensity);
    }
  }

  Future<void> triggerGenericInfo(
      {bool withFlash = false,
      VibrationIntensity intensity = VibrationIntensity.high}) async {
    if (withFlash) _triggerFlashlightPattern(duration: 1500, flashDelay: 300);
    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(pattern: [0, 150, 100, 150], intensity: intensity);
    }
  }

  Future<void> _triggerFlashlightPattern(
      {required int duration, required int flashDelay}) async {
    if (_isFlashing) return;
    _isFlashing = true;

    final end = DateTime.now().add(Duration(milliseconds: duration));

    try {
      while (DateTime.now().isBefore(end)) {
        try {
          await TorchLight.enableTorch();
        } catch (_) {}
        await Future.delayed(Duration(milliseconds: flashDelay));
        try {
          await TorchLight.disableTorch();
        } catch (_) {}
        await Future.delayed(Duration(milliseconds: flashDelay));
      }
    } catch (e) {
      log("Flashlight error: $e");
    } finally {
      _isFlashing = false;
      try {
        await TorchLight.disableTorch();
      } catch (_) {}
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      log("TTS Error: $e");
    }
  }

  Future<void> triggerCustomAlert({
    required String message,
    required List<int> vibrationPattern,
    bool withFlash = false,
    int flashDuration = 3000,
    int flashDelay = 200,
    VibrationIntensity intensity = VibrationIntensity.high,
  }) async {
    _speak(message);
    _notify("Custom Alert", message);

    if (withFlash) {
      _triggerFlashlightPattern(
          duration: flashDuration, flashDelay: flashDelay);
    }

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(pattern: vibrationPattern, intensity: intensity);
    }
  }

  Future<void> triggerSOS(String message) async {
    _speak("Emergency SOS! $message");
    _notify("🚨 SOS ACTIVATED 🚨", message);

    // Intense flash and vibration
    _triggerFlashlightPattern(duration: 10000, flashDelay: 50);

    if (await Vibration.hasVibrator()) {
      _vibrateWithIntensity(
        pattern: [
          0, 300, 100, 300, 100, 300, // S
          300, 800, 100, 800, 100, 800, // O
          300, 300, 100, 300, 100, 300 // S
        ],
        intensity: VibrationIntensity.high,
      );
    }
  }

  void _vibrateWithIntensity(
      {required List<int> pattern, required VibrationIntensity intensity}) {
    int amplitude = 255;
    if (intensity == VibrationIntensity.medium) amplitude = 128;
    if (intensity == VibrationIntensity.low) amplitude = 60;

    List<int> intensities = [];
    for (int i = 0; i < pattern.length; i++) {
      if (i % 2 == 0) {
        intensities.add(0);
      } else {
        intensities.add(amplitude);
      }
    }

    if (pattern.isNotEmpty) {
      Vibration.vibrate(pattern: pattern, intensities: intensities);
    }
  }
}
