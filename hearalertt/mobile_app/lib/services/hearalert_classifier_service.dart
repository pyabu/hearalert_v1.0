import 'dart:convert';
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// HearAlert Custom Model Classifier
/// Uses the trained model for enhanced detection of:
/// - Baby crying (multiple types: hungry, tired, discomfort, etc.)
/// - Dog barking
/// - Cat meowing  
/// - Door knock
/// - Glass breaking
/// - Emergency siren
/// - Fire alarm

class HearAlertCategory {
  final String id;
  final String displayName;
  final int priority;
  final String alertType;
  final String color;
  final List<int> vibrationPattern;

  const HearAlertCategory({
    required this.id,
    required this.displayName,
    required this.priority,
    required this.alertType,
    required this.color,
    this.vibrationPattern = const [0, 200, 100, 200],
  });
}

/// Trained categories mapping - Deaf Accessibility Focus
class HearAlertCategories {
  static const Map<String, HearAlertCategory> categories = {
    // ═══════════════════════════════════════════════════════════════════
    // CRITICAL - Emergency & Safety
    // ═══════════════════════════════════════════════════════════════════
    'baby_cry': HearAlertCategory(
      id: 'baby_cry',
      displayName: 'Baby Crying',
      priority: 10,
      alertType: 'critical',
      color: '#FF6B9D',
      vibrationPattern: [0, 500, 200, 500, 200, 500],
    ),
    'car_horn': HearAlertCategory(
      id: 'car_horn',
      displayName: 'Car Horn',
      priority: 10,
      alertType: 'critical',
      color: '#FFD700',
      vibrationPattern: [0, 300, 100, 300, 100, 300, 100, 300],
    ),
    'siren': HearAlertCategory(
      id: 'siren',
      displayName: 'Emergency Siren',
      priority: 10,
      alertType: 'critical',
      color: '#FF0000',
      vibrationPattern: [0, 1000, 500, 1000],
    ),
    'fire_alarm': HearAlertCategory(
      id: 'fire_alarm',
      displayName: 'Fire Alarm',
      priority: 10,
      alertType: 'critical',
      color: '#FF4500',
      vibrationPattern: [0, 500, 100, 500, 100, 500, 100, 500],
    ),
    'glass_breaking': HearAlertCategory(
      id: 'glass_breaking',
      displayName: 'Glass Breaking',
      priority: 9,
      alertType: 'critical',
      color: '#FF6B6B',
      vibrationPattern: [0, 500, 100, 500, 100, 500],
    ),
    'train': HearAlertCategory(
      id: 'train',
      displayName: 'Train',
      priority: 9,
      alertType: 'critical',
      color: '#8B4513',
      vibrationPattern: [0, 800, 200, 800],
    ),
    
    // ═══════════════════════════════════════════════════════════════════
    // HIGH PRIORITY - Traffic & Home Alerts
    // ═══════════════════════════════════════════════════════════════════
    'traffic': HearAlertCategory(
      id: 'traffic',
      displayName: 'Traffic/Vehicle',
      priority: 8,
      alertType: 'high',
      color: '#FFA500',
      vibrationPattern: [0, 400, 150, 400],
    ),
    'door_knock': HearAlertCategory(
      id: 'door_knock',
      displayName: 'Door Knock',
      priority: 8,
      alertType: 'high',
      color: '#8B4513',
      vibrationPattern: [0, 200, 100, 200, 100, 200],
    ),
    'doorbell': HearAlertCategory(
      id: 'doorbell',
      displayName: 'Doorbell',
      priority: 8,
      alertType: 'high',
      color: '#4169E1',
      vibrationPattern: [0, 300, 150, 300],
    ),
    'phone_ring': HearAlertCategory(
      id: 'phone_ring',
      displayName: 'Phone/Alarm Ring',
      priority: 7,
      alertType: 'high',
      color: '#32CD32',
      vibrationPattern: [0, 200, 100, 200, 100, 200, 100, 200],
    ),
    'dog_bark': HearAlertCategory(
      id: 'dog_bark',
      displayName: 'Dog Barking',
      priority: 7,
      alertType: 'high',
      color: '#D4A373',
      vibrationPattern: [0, 300, 100, 300, 100, 300],
    ),
    'thunderstorm': HearAlertCategory(
      id: 'thunderstorm',
      displayName: 'Thunderstorm',
      priority: 7,
      alertType: 'high',
      color: '#4B0082',
      vibrationPattern: [0, 600, 200, 400],
    ),
    
    // ═══════════════════════════════════════════════════════════════════
    // MEDIUM PRIORITY - Awareness
    // ═══════════════════════════════════════════════════════════════════
    'helicopter': HearAlertCategory(
      id: 'helicopter',
      displayName: 'Helicopter',
      priority: 6,
      alertType: 'medium',
      color: '#708090',
      vibrationPattern: [0, 400, 100, 400],
    ),
    'cat_meow': HearAlertCategory(
      id: 'cat_meow',
      displayName: 'Cat Meowing',
      priority: 5,
      alertType: 'medium',
      color: '#4ECDC4',
      vibrationPattern: [0, 200, 100, 200],
    ),
  };

  static HearAlertCategory? getCategory(String id) => categories[id];
}

class HearAlertResult {
  final String categoryId;
  final String displayName;
  final double confidence;
  final DateTime timestamp;
  final int priority;
  final String alertType;
  final String color;
  final List<int> vibrationPattern;

  HearAlertResult({
    required this.categoryId,
    required this.displayName,
    required this.confidence,
    required this.timestamp,
    required this.priority,
    required this.alertType,
    required this.color,
    this.vibrationPattern = const [],
  });

  bool get isCritical => alertType == 'critical';
  bool get isHigh => alertType == 'high' || isCritical;

  @override
  String toString() => '$displayName (${(confidence * 100).toStringAsFixed(1)}%)';
}

/// HearAlert Custom Model Classifier Service
/// This service runs alongside YAMNet for enhanced accuracy
class HearAlertClassifierService {
  static final HearAlertClassifierService _instance = HearAlertClassifierService._internal();
  factory HearAlertClassifierService() => _instance;
  HearAlertClassifierService._internal();

  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isInitialized = false;

  // Sliding window for majority vote
  static const int _votingWindowSize = 3;
  final List<HearAlertResult> _recentDetections = [];

  final StreamController<List<HearAlertResult>> _resultController = StreamController.broadcast();
  Stream<List<HearAlertResult>> get detectionStream => _resultController.stream;

  // Model configuration
  static const String _modelPath = 'assets/models/hearalert_classifier.tflite';
  static const String _labelsPath = 'assets/models/hearalert_labels.txt';
  static const double _minConfidenceThreshold = 0.45; // Increased to prevent false positives on silence
  static const double _criticalThreshold = 0.70;

  bool get isInitialized => _isInitialized;

  // Dynamic categories map
  Map<String, HearAlertCategory> _categoriesConfig = {};

  Future<void>_loadMetadata() async {
    try {
      final jsonString = await rootBundle.loadString('assets/models/categories_config.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      _categoriesConfig.clear();
      for (var item in jsonList) {
        final id = item['id'];
        _categoriesConfig[id] = HearAlertCategory(
          id: id,
          displayName: item['label'] ?? id,
          priority: item['priority'] ?? 0,
          alertType: item['alert_type'] ?? 'low',
          color: '#808080', // Default, app can map priority to color if needed
          vibrationPattern: (item['vibration_pattern'] as List<dynamic>?)?.cast<int>() ?? [0, 200],
        );
      }
      log('✓ Configuration loaded: ${_categoriesConfig.length} categories from JSON');
      
    } catch (e) {
      log('⚠️ Error loading metadata JSON: $e');
      // Fallback to hardcoded if needed, or just warn
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('🎯 Initializing HearAlert Custom Classifier...');

      // Load Metadata First
      await _loadMetadata();
      await _loadScaler();

      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        log('Skipping HearAlert model initialization on Desktop (mock mode).');
        _isInitialized = true;
        return;
      }

      // Load custom trained model
      final options = InterpreterOptions()..threads = 2;
      
      try {
        _interpreter = await Interpreter.fromAsset(_modelPath, options: options);
        log('✓ HearAlert model loaded successfully.');
      } catch (e) {
        log('⚠️ Could not load HearAlert model: $e');
        log('Falling back to YAMNet-only mode.');
        return;
      }

      if (_interpreter != null) {
        _interpreter!.allocateTensors();
      }

      // Load labels
      try {
        final labelData = await rootBundle.loadString(_labelsPath);
        _labels = labelData.split('\n').where((l) => l.trim().isNotEmpty).toList();
        log('✓ Labels loaded: ${_labels?.length} categories');
      } catch (e) {
        log('⚠️ Could not load labels: $e');
      }

      _isInitialized = true;
      log('🎯 HearAlert Classifier initialized successfully!');

    } catch (e) {
      log('Error initializing HearAlert Classifier: $e');
    }
  }

  List<double>? _scalerMean;
  List<double>? _scalerScale;

  Future<void> _loadScaler() async {
    try {
      final jsonString = await rootBundle.loadString('assets/models/scaler.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      _scalerMean = (data['mean'] as List).cast<num>().map((n) => n.toDouble()).toList();
      _scalerScale = (data['scale'] as List).cast<num>().map((n) => n.toDouble()).toList();
      log('✓ StandardScaler loaded successfully');
    } catch (e) {
      log('⚠️ Could not load scaler.json: $e. Using unscaled raw embeddings.');
    }
  }

  /// Process YAMNet embeddings through HearAlert model
  /// The HearAlert model was trained on YAMNet embeddings (1024-dimensional)
  Future<List<HearAlertResult>> classifyEmbeddings(List<double> yamnetEmbeddings) async {
    if (_interpreter == null || _labels == null) {
      return [];
    }

    try {
      // Apply Standardization if available
      List<double> processedEmbeddings = yamnetEmbeddings.toList();
      if (_scalerMean != null && _scalerScale != null) {
        for (int i = 0; i < processedEmbeddings.length; i++) {
          final scaleVal = _scalerScale![i];
          if (scaleVal != 0) {
            processedEmbeddings[i] = (processedEmbeddings[i] - _scalerMean![i]) / scaleVal;
          }
        }
      }

      // Input: YAMNet embeddings [1024]
      var input = Float32List.fromList(processedEmbeddings).reshape([1, 1024]);
      
      // Output: Category probabilities
      int numClasses = _labels!.length;
      var output = List.filled(1 * numClasses, 0.0).reshape([1, numClasses]);
      
      _interpreter!.run(input, output);
      
      final List<double> scores = output[0];
      return _getTopResults(scores);

    } catch (e) {
      log('HearAlert inference error: $e');
      return [];
    }
  }

  List<HearAlertResult> _getTopResults(List<double> scores) {
    if (_labels == null) {
      log('⚠️ HearAlert Error: _labels is null! Inference was blocked.');
      return [];
    }

    double maxScore = 0.0;
    int maxIndex = 0;
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        maxScore = scores[i];
        maxIndex = i;
      }
    }
    
    if (maxIndex < _labels!.length) {
      log('🧠 HearAlert RAW MAX: ${_labels![maxIndex]} at ${(maxScore * 100).toStringAsFixed(2)}%');
    }

    final results = <HearAlertResult>[];
    
    for (int i = 0; i < scores.length && i < _labels!.length; i++) {
      final score = scores[i];
      final categoryId = _labels![i];
      
      // Pull dynamic configuration from Python build first, fallback to hardcoded
      final category = _categoriesConfig[categoryId] ?? HearAlertCategories.getCategory(categoryId);
      
      if (category != null && score >= _minConfidenceThreshold) {
        results.add(HearAlertResult(
          categoryId: categoryId,
          displayName: category.displayName,
          confidence: score,
          timestamp: DateTime.now(),
          priority: category.priority,
          alertType: category.alertType,
          color: category.color,
          vibrationPattern: category.vibrationPattern,
        ));
      }
    }

    // Return early if nothing was > threshold
    if (results.isEmpty) return [];

    // Sort by priority first, then by confidence
    results.sort((a, b) {
      if (a.priority != b.priority) {
        return b.priority.compareTo(a.priority);
      }
      return b.confidence.compareTo(a.confidence);
    });

    final topRaw = results.first;

    // ── Apply Majority Vote (Temporal Smoothing) ─────────────────────────
    _recentDetections.add(topRaw);
    if (_recentDetections.length > _votingWindowSize) {
      _recentDetections.removeAt(0);
    }

    final votes = <String, int>{};
    final bestResult = <String, HearAlertResult>{};
    for (final r in _recentDetections) {
      // Vote strictly by category ID (e.g. fire_alarm, door_knock)
      votes[r.categoryId] = (votes[r.categoryId] ?? 0) + 1;
      // Keep highest confidence item for the winner
      if (!(bestResult.containsKey(r.categoryId)) || r.confidence > bestResult[r.categoryId]!.confidence) {
        bestResult[r.categoryId] = r;
      }
    }

    String? winnerId;
    int maxVotes = 0;
    votes.forEach((id, count) {
      if (count > maxVotes) {
        maxVotes = count;
        winnerId = id;
      }
    });

    final needMajority = _recentDetections.length >= _votingWindowSize ? 2 : 1;
    
    if (winnerId != null && maxVotes >= needMajority) {
      final winner = bestResult[winnerId]!;
      log('🎯 HearAlert CONFIRMED ($maxVotes/$_votingWindowSize): ${winner.displayName} (${(winner.confidence * 100).toStringAsFixed(1)}%)');
      _resultController.add([winner]);
      return [winner];
    } else {
      log('🔇 HearAlert SMOOTHING: No majority yet (votes: $votes)');
      return [];
    }

    return results.take(3).toList();
  }

  /// Check if a result should trigger an immediate alert
  bool shouldTriggerAlert(HearAlertResult result) {
    return result.confidence >= _criticalThreshold && result.isCritical;
  }

  void dispose() {
    _interpreter?.close();
    _resultController.close();
    _isInitialized = false;
  }
}

/// Configuration for real-time detection
class HearAlertConfig {
  static const Map<String, dynamic> realTimeConfig = {
    'audio_format': {
      'sample_rate': 16000,
      'channels': 1,
      'bit_depth': 16,
    },
    'detection': {
      'buffer_size_ms': 1000,
      'overlap_ms': 500,
      'min_confidence': 0.35,
      'critical_confidence': 0.60,
    },
    'alerts': {
      'enabled': true,
      'vibration': true,
      'visual_flash': true,
      'sound': false, // Disabled for deaf users
    },
  };

  static const List<String> priorityCategories = [
    'baby_cry',
    'fire_alarm',
    'siren',
    'glass_breaking',
    'door_knock',
    'dog_bark',
    'cat_meow',
  ];
}
