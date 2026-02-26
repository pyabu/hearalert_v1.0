import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:audio_streamer/audio_streamer.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_app/services/priority_sounds.dart';
import 'package:mobile_app/services/hearalert_classifier_service.dart';

class ClassificationResult {
  final String label;
  final double confidence;
  final double boostedConfidence; // Confidence after priority boost
  final DateTime timestamp;
  final int yamnetIndex;
  final bool isPriority;
  final SoundPriority? priority;
  final AlertSeverity? severity;

  ClassificationResult(
    this.label, 
    this.confidence, 
    this.timestamp, {
    this.boostedConfidence = 0.0,
    this.yamnetIndex = -1,
    this.isPriority = false,
    this.priority,
    this.severity,
  });

  @override
  String toString() => '$label (${(boostedConfidence > 0 ? boostedConfidence : confidence * 100).toStringAsFixed(1)}%)${isPriority ? " ⚡" : ""}';
}

class AudioClassifierService {
  static final AudioClassifierService _instance = AudioClassifierService._internal();
  factory AudioClassifierService() => _instance;
  AudioClassifierService._internal();

  Interpreter? _interpreter;
  List<String>? _labels;
  StreamSubscription<List<double>>? _micStreamSubscription;
  final HearAlertClassifierService _hearAlertService = HearAlertClassifierService();
  final StreamController<List<ClassificationResult>> _resultController = StreamController.broadcast();
  final StreamController<double> _amplitudeController = StreamController.broadcast();
  final StreamController<List<double>> _visualizerController = StreamController.broadcast();

  Stream<List<ClassificationResult>> get detectionStream => _resultController.stream;
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  Stream<List<double>> get visualizerStream => _visualizerController.stream;
  
  // Expose raw audio for other classifiers (e.g. Baby Cry)
  final StreamController<List<int>> _rawAudioController = StreamController.broadcast();
  Stream<List<int>> get rawAudioStream => _rawAudioController.stream;

  bool _isProcessing = false;
  bool _isRecording = false;
  DateTime _lastHeartbeat = DateTime.now();
  double _maxAmplitudeRecently = 0.0;
  
  bool get isRecording => _isRecording;

  // Added for dynamic detection thresholds
  double currentSensitivity = 0.5;

  // YAMNet constants
  static const int sampleRate = 16000;
  List<int> _inputShape = [];
  int _inputLength = 15600; 
  int get inputLength => _inputLength;
  
  // Sliding window with 0% overlap to prevent budget Android phones from lagging out/freezing
  static const double _overlapRatio = 0.0;
  int get _slideLength => (_inputLength * (1 - _overlapRatio)).toInt();
  
  List<double> _audioBuffer = [];

  // Cached output tensor info (set during initialization after resize)
  Map<int, List<int>> _cachedOutputShapes = {};
  int _scoresIndex = 0;
  int _embeddingsIndex = 1;
  int _numOutputTensors = 0;
  bool _shapesCalibrated = false;

  // Sliding window for temporal smoothing (majority-vote)
  // Only emit a detection when 2+ of last 3 chunks agree on the same label
  static const int _votingWindowSize = 3;
  final List<ClassificationResult> _recentDetections = [];

  Future<void> initialize() async {
    try {
      debugPrint('Initializing AudioClassifierService...');

      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        debugPrint('Skipping TFLite initialization on Desktop (mock mode).');
        return;
      }
      
      // Load Model with CPU optimization to avoid SELinux hardware probing issues
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset('assets/models/yamnet.tflite', options: options);
      debugPrint('Model loaded successfully with 4 CPU threads.');

      if (_interpreter != null) {
        // YAMNet has a DYNAMIC input shape [1].
        // Resize to [15600] for proper inference.
        _interpreter!.resizeInputTensor(0, [_inputLength]);
        _interpreter!.allocateTensors();
        
        final inputTensor = _interpreter!.getInputTensor(0);
        debugPrint('Input shape: ${inputTensor.shape}');
        
        // Read API-reported shapes (may be stale [1, N] for dynamic models)
        final allOutputs = _interpreter!.getOutputTensors();
        _numOutputTensors = allOutputs.length;
        for (int i = 0; i < allOutputs.length; i++) {
          final shape = allOutputs[i].shape;
          _cachedOutputShapes[i] = List<int>.from(shape);
          debugPrint('Output tensor $i shape (API): $shape');
          if (shape.isNotEmpty && shape.last == 521) _scoresIndex = i;
          else if (shape.isNotEmpty && shape.last == 1024) _embeddingsIndex = i;
        }
        debugPrint('Scores idx=$_scoresIndex, Embeddings idx=$_embeddingsIndex');
      }

      // Load Labels
      final labelData = await rootBundle.loadString('assets/models/yamnet_class_map.csv');
      _labels = _parseLabels(labelData);
      debugPrint('Labels loaded: ${_labels?.length} entries.');

    } catch (e) {
      debugPrint('Error initializing AudioClassifierService: $e');
    }
  }

  List<String> _parseLabels(String csvData) {
    final List<String> labels = [];
    final lines = csvData.split('\n');
    // Skip header if exists, usually "index,mid,display_name"
    // YAMNet CSV structure often: index, mid, display_name
    for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = line.split(',');
        if (parts.length >= 3) {
            labels.add(parts[2]); // display_name
        } else {
            labels.add('Unknown');
        }
    }
    return labels;
  }

  Future<void> start() async {
    if (_isRecording) {
      debugPrint('AudioClassifierService: Already recording. Ignoring start request.');
      return;
    }
    
    // Request Microphone Permission (Mobile only)
    if (Platform.isAndroid || Platform.isIOS) {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          debugPrint('Microphone permission denied.');
          return;
        }
      }
    }

    if (_interpreter == null) await initialize();

    try {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        debugPrint('AudioStreamer not supported on Desktop. Skipping real audio.');
        // Mock recording state for UI verification
        _isRecording = true;
        _resultController.add([]); // Emitting empty results to verify stream listeners
        return;
      }

      // Ensure previous stream is closed
      await _micStreamSubscription?.cancel();

      // Use AudioStreamer - singleton with factory constructor
      // Set sample rate BEFORE listening to the stream
      final audioStreamer = AudioStreamer();
      audioStreamer.sampleRate = sampleRate;
      
      _isRecording = true;
      _audioBuffer = [];

      _micStreamSubscription = audioStreamer.audioStream.listen(
        (List<double> samples) {
          _processAudioSamplesFloat(samples);
        },
        onError: (error) {
          debugPrint('AudioStreamer error: $error');
        },
        cancelOnError: true,
      );
      
      debugPrint('Microphone started with AudioStreamer at ${sampleRate}Hz.');

    } catch (e) {
      debugPrint('Error starting microphone: $e');
      _isRecording = false;
    }
  }

  void _processAudioSamplesFloat(List<double> samples) {
    // Convert to int samples for raw audio stream (for other services)
    final List<int> rawSamples = samples.map((s) => (s * 32768).toInt().clamp(-32768, 32767)).toList();
    _rawAudioController.add(rawSamples);
    
    // Calculate amplitude for visualizer
    double maxAmp = 0.0;
    for (final sample in samples) {
      if (sample.abs() > maxAmp) maxAmp = sample.abs();
    }
    
    // Generate visualizer data (downsample for UI)
    if (samples.isNotEmpty) {
      final int step = (samples.length / 50).ceil();
      final List<double> visualizerData = [];
      for (int i = 0; i < samples.length; i += step) {
        visualizerData.add(samples[i]);
      }
      _visualizerController.add(visualizerData);
    }
    
    _amplitudeController.add(maxAmp);

    _audioBuffer.addAll(samples);

    // Sliding window inference - process when buffer is full
    // Replaced while with if, and added _isProcessing check to prevent UI lockup 
    if (!_isProcessing && _audioBuffer.length >= _inputLength) {
        final inputChunk = _audioBuffer.sublist(0, _inputLength);
        _audioBuffer = _audioBuffer.sublist(_slideLength);
        _runInference(inputChunk);
    } else if (_isProcessing && _audioBuffer.length > _inputLength * 3) {
        // C++ inference is taking too long for this specific CPU.
        // Drop the oldest frames and keep ONLY the most recent continuous 1-second burst.
        debugPrint('⚠️ Audio Buffer Overflowing - Dropping stale frames to catch up.');
        _audioBuffer = _audioBuffer.sublist(_audioBuffer.length - _inputLength);
    }
  }




  Future<void> _runInference(List<double> inputBuffer) async {
    if (_interpreter == null || _labels == null || _isProcessing) return;
    
    _isProcessing = true;
    try {
      await Future.delayed(Duration.zero);

      // ── Step 1: Flat Float32List input of exactly 15600 samples ──────────
      final input = Float32List.fromList(inputBuffer);

      // ── Step 2: Allocate ALL output buffers ──────────────────────────────
      // runForMultipleInputs requires ALL tensors in the map.
      // Scores [1, 521] and embeddings [1, 1024] use API shapes.
      // ONLY the spectrogram tensor (64 cols) needs [96, 64] override.
      final outputs = <int, Object>{};
      for (int i = 0; i < _numOutputTensors; i++) {
        final shape = List<int>.from(_cachedOutputShapes[i] ?? [1]);
        // Override the spectrogram tensor's row dimension (the only one that changes)
        if (shape.length == 2 && shape.last == 64 && shape[0] == 1) {
          shape[0] = 96; // YAMNet produces 96 spectrogram frames for 15600 samples
        }
        if (shape.length == 2) {
          outputs[i] = List.generate(shape[0], (_) => List<double>.filled(shape[1], 0.0));
        } else {
          outputs[i] = List<double>.filled(shape[0], 0.0);
        }
      }

      // ── Step 3: Run inference ─────────────────────────────────────────────
      _interpreter!.runForMultipleInputs([input], outputs);

      // ── Step 4: Mean-pool 96 frames into single vectors ──────────────────
      // YAMNet outputs 96 frames (one per 10ms window). We average them.
      List<double> flatScores = _meanPoolFrames(outputs[_scoresIndex], _labels!.length);
      List<double> flatEmbeddings = _meanPoolFrames(outputs[_embeddingsIndex], 1024);

      // ── Step 5: Heartbeat log ─────────────────────────────────────────────
      final amplitude = inputBuffer.fold<double>(0, (m, v) => v.abs() > m ? v.abs() : m);
      if (DateTime.now().difference(_lastHeartbeat).inSeconds >= 3) {
        final topScores = List<double>.from(flatScores)..sort((a, b) => b.compareTo(a));
        final top3 = topScores.take(3).map((s) => s.toStringAsFixed(3)).toList();
        debugPrint('🎤 HEARTBEAT amp=${amplitude.toStringAsFixed(4)} scores=${flatScores.length} emb=${flatEmbeddings.length} top3=$top3');
        _lastHeartbeat = DateTime.now();
      }

      // ── Step 6: Custom HearAlert model ────────────────────────────────────
      if (flatEmbeddings.isNotEmpty && flatEmbeddings.any((e) => e != 0.0)) {
        if (!_hearAlertService.isInitialized) await _hearAlertService.initialize();
        final hearResults = await _hearAlertService.classifyEmbeddings(flatEmbeddings);
        if (hearResults.isNotEmpty) {
          debugPrint('🎯 HearAlert: ${hearResults.first.displayName} (${(hearResults.first.confidence*100).toStringAsFixed(1)}%)');
        }
      }

      // ── Step 7: YAMNet results → temporal smoothing via majority vote ─────
      final results = _buildResults(flatScores);
      if (results.isNotEmpty) {
        final candidate = results.first;
        debugPrint('🔊 YAMNet RAW: ${candidate.label} (${(candidate.confidence*100).toStringAsFixed(1)}%)');
        
        // Add to sliding window
        _recentDetections.add(candidate);
        if (_recentDetections.length > _votingWindowSize) {
          _recentDetections.removeAt(0);
        }
        
        // Count votes by CATEGORY (not exact label) so related sounds vote together
        // e.g., "Fire alarm" + "Alarm" + "Smoke detector" → all count as ALARM
        final votes = <String, int>{};
        final bestConf = <String, double>{};
        final bestResult = <String, ClassificationResult>{};
        for (final r in _recentDetections) {
          final category = _getCategoryForLabel(r.label);
          votes[category] = (votes[category] ?? 0) + 1;
          if ((bestConf[category] ?? 0) < r.confidence) {
            bestConf[category] = r.confidence;
            bestResult[category] = r;
          }
        }
        
        // Find the category with the most votes
        String? winnerCategory;
        int maxVotes = 0;
        votes.forEach((category, count) {
          if (count > maxVotes) {
            maxVotes = count;
            winnerCategory = category;
          }
        });
        
        // Only emit if the winner has at least 2 votes (majority in window of 3)
        final needMajority = _recentDetections.length >= _votingWindowSize ? 2 : 1;
        if (winnerCategory != null && maxVotes >= needMajority) {
          final winner = bestResult[winnerCategory]!;
          debugPrint('🔊 YAMNet CONFIRMED ($maxVotes/$_votingWindowSize): ${winner.label} [category: $winnerCategory] (${(winner.confidence*100).toStringAsFixed(1)}%)');
          _resultController.add([winner]);
        } else {
          debugPrint('🔇 YAMNet SMOOTHING: no majority yet (votes: $votes)');
        }
      }

    } catch (e) {
      debugPrint('❌ Inference error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Mean-pool N frames of shape [N, dim] into a single [dim] vector.
  List<double> _meanPoolFrames(Object? output, int expectedDim) {
    if (output == null) return List.filled(expectedDim, 0.0);
    if (output is List && output.isNotEmpty && output[0] is List) {
      // 2D: [[frame0], [frame1], ...] → average all frames
      final numFrames = output.length;
      final dim = (output[0] as List).length;
      final pooled = List<double>.filled(dim, 0.0);
      for (int f = 0; f < numFrames; f++) {
        final frame = output[f] as List;
        for (int d = 0; d < dim; d++) {
          pooled[d] += (frame[d] as num).toDouble();
        }
      }
      for (int d = 0; d < dim; d++) {
        pooled[d] /= numFrames;
      }
      return pooled;
    } else if (output is List) {
      return output.map((e) => (e as num).toDouble()).toList();
    }
    return List.filled(expectedDim, 0.0);
  }

  /// Build ClassificationResult list from raw YAMNet scores.
  /// ALWAYS returns the top result so detectionStream always fires,
  /// but explicitly ignores Silence and pure background noise.
  List<ClassificationResult> _buildResults(List<double> scores) {
    if (_labels == null || scores.isEmpty) return [];

    // Ignore these generic background classes so they don't overwrite real sounds
    final ignoreLabels = {
      'silence',
      'background noise',
      'noise'
    };

    // Find top score of a VALID sound
    int maxIdx = -1;
    double maxScore = 0;
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        final labelLabel = _labels![i].toLowerCase();
        // Skip ignored background classes
        if (ignoreLabels.contains(labelLabel)) continue;

        maxScore = scores[i];
        maxIdx = i;
      }
    }

    // Must be at least 1% confident (since mobile mics are bad, rely on YAMNet top score)
    // Must be at least 15% confident to avoid false positives
    if (maxIdx == -1 || maxScore < 0.15 || maxIdx >= _labels!.length) {
      debugPrint('🔊 YAMNet Ignored (too low): max score=${maxScore.toStringAsFixed(4)}');
      return [];
    }

    final label = _labels![maxIdx];
    final prioritySound = PrioritySoundsDatabase.getByKeyword(label)
        ?? PrioritySoundsDatabase.getByIndex(maxIdx);
    final boosted = prioritySound != null
        ? maxScore * prioritySound.confidenceBoost
        : maxScore;

    debugPrint('🎧 TOP VALID: $label (${(maxScore*100).toStringAsFixed(1)}%)');

    return [
      ClassificationResult(
        label,
        maxScore,
        DateTime.now(),
        boostedConfidence: boosted,
        yamnetIndex: maxIdx,
        isPriority: prioritySound != null,
        priority: prioritySound?.priority,
        severity: prioritySound?.severity,
      )
    ];
  }

  Future<void> stop() async {
    await _micStreamSubscription?.cancel();
    _micStreamSubscription = null;
    _isRecording = false;
    _audioBuffer.clear();
    debugPrint('Microphone stopped.');
  }

  /// Maps related YAMNet labels into unified categories for majority-vote.
  String _getCategoryForLabel(String label) {
    final l = label.toLowerCase();
    // ALARM / EMERGENCY
    if (l.contains('fire') || l.contains('smoke') || l.contains('alarm') ||
        l.contains('siren') || l.contains('ambulance') || l.contains('police')) return 'ALARM';
    // DOOR
    if (l.contains('knock') || (l.contains('door') && !l.contains('doorbell'))) return 'DOOR';
    // BELL
    if (l.contains('bell') || l.contains('chime') || l.contains('ding')) return 'BELL';
    // SPEECH
    if (l.contains('speech') || l.contains('voice') || l.contains('talk') ||
        l.contains('conversation') || l.contains('narration')) return 'SPEECH';
    // VEHICLE
    if (l.contains('horn') || l.contains('honk') || l.contains('vehicle') ||
        l.contains('car') || l.contains('truck') || l.contains('engine') ||
        l.contains('traffic') || l.contains('motor')) return 'VEHICLE';
    // MUSIC
    if (l.contains('music') || l.contains('singing') || l.contains('song') ||
        l.contains('guitar') || l.contains('piano') || l.contains('drum')) return 'MUSIC';
    // ANIMAL
    if (l.contains('dog') || l.contains('bark') || l.contains('cat') ||
        l.contains('bird') || l.contains('chirp') || l.contains('meow')) return 'ANIMAL';
    // BABY
    if (l.contains('baby') || l.contains('cry') || l.contains('infant')) return 'BABY';
    // GUNSHOT
    if (l.contains('gun') || l.contains('explosion') || l.contains('blast') ||
        l.contains('firework')) return 'GUNSHOT';
    // GLASS
    if (l.contains('glass') || l.contains('break') || l.contains('shatter')) return 'GLASS';
    // PHONE
    if (l.contains('phone') || l.contains('telephone') || l.contains('ringtone')) return 'PHONE';
    // No match — use exact label
    return label;
  }

  void dispose() {
    stop();
    _interpreter?.close();
    _resultController.close();
    _amplitudeController.close();
    _visualizerController.close();
    _rawAudioController.close();
  }
}
