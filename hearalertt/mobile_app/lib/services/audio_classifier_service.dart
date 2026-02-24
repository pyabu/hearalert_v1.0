import 'dart:async';
import 'dart:developer';
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
  
  // Sliding window with 75% overlap for faster detection
  static const double _overlapRatio = 0.75;
  int get _slideLength => (_inputLength * (1 - _overlapRatio)).toInt();
  
  List<double> _audioBuffer = [];

  Future<void> initialize() async {
    try {
      log('Initializing AudioClassifierService...');

      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        log('Skipping TFLite initialization on Desktop (mock mode).');
        return;
      }
      
      // Load Model with CPU optimization to avoid SELinux hardware probing issues
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset('assets/models/yamnet.tflite', options: options);
      log('Model loaded successfully with 4 CPU threads.');

      if (_interpreter != null) {
        _interpreter!.allocateTensors();
        final inputTensor = _interpreter!.getInputTensor(0);
        final outputTensor = _interpreter!.getOutputTensor(0);
        log('Input shape: ${inputTensor.shape}');
        log('Output shape: ${outputTensor.shape}');
        
        // Check for embeddings output (usually index 1 in YAMNet)
        if (_interpreter!.getOutputTensors().length > 1) {
            try {
              final embeddingTensor = _interpreter!.getOutputTensor(1);
              log('Embedding Output shape: ${embeddingTensor.shape}');
            } catch (e) {
              log('Could not inspect embedding tensor: $e');
            }
        }
        
        _inputShape = inputTensor.shape;
        // Calculate total length (e.g. [1, 15600] -> 15600)
        _inputLength = _inputShape.isNotEmpty 
            ? _inputShape.reduce((a, b) => a * b) 
            : 15600;
            
        log('Set calculated input length to: $_inputLength');
      }

      // Load Labels
      final labelData = await rootBundle.loadString('assets/models/yamnet_class_map.csv');
      _labels = _parseLabels(labelData);
      log('Labels loaded: ${_labels?.length} entries.');

    } catch (e) {
      log('Error initializing AudioClassifierService: $e');
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
      log('AudioClassifierService: Already recording. Ignoring start request.');
      return;
    }
    
    // Request Microphone Permission (Mobile only)
    if (Platform.isAndroid || Platform.isIOS) {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          log('Microphone permission denied.');
          return;
        }
      }
    }

    if (_interpreter == null) await initialize();

    try {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        log('AudioStreamer not supported on Desktop. Skipping real audio.');
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
          log('AudioStreamer error: $error');
        },
        cancelOnError: true,
      );
      
      log('Microphone started with AudioStreamer at ${sampleRate}Hz.');

    } catch (e) {
      log('Error starting microphone: $e');
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
    if (_audioBuffer.length >= _inputLength) {
        final inputChunk = _audioBuffer.sublist(0, _inputLength);
        _audioBuffer = _audioBuffer.sublist(_slideLength);
        _runInference(inputChunk);
    }
  }




  Future<void> _runInference(List<double> inputBuffer) async {
    if (_interpreter == null || _labels == null) return;

    try {
      // YAMNet model expects input shape [1, 15600] as confirmed by Python test
      // and dynamic tensor allocation. Forcing 1D [15600] can cause silent failures.
      var input = Float32List.fromList(inputBuffer).reshape([1, _inputLength]);
      
      // Output 0: Scores [1, 521]
      int outputClasses = 521;
      try {
         final outputShape = _interpreter!.getOutputTensor(0).shape;
         if (outputShape.isNotEmpty) {
             outputClasses = outputShape.last;
         }
      } catch (_) {}

      var outputBuffer = List.filled(1 * outputClasses, 0.0).reshape([1, outputClasses]);
      
      // Output 1: Embeddings [1, 1024]
      List<double>? embeddings;
      Map<int, Object> outputs = {0: outputBuffer};
      
      if (_interpreter!.getOutputTensors().length > 1) {
          // Prepare buffer for embeddings
          var embeddingBuffer = List.filled(1 * 1024, 0.0).reshape([1, 1024]);
          outputs[1] = embeddingBuffer;
      }
      
      // Run inference on YAMNet
      _interpreter!.runForMultipleInputs([input], outputs);
      
      // Extract embeddings if available
      if (outputs.containsKey(1)) {
          embeddings = (outputs[1] as List)[0].cast<double>();
      }
      
      // Heartbeat Logging
      final amplitude = inputBuffer.fold<double>(0, (max, v) => v.abs() > max ? v.abs() : max);
      _maxAmplitudeRecently = amplitude > _maxAmplitudeRecently ? amplitude : _maxAmplitudeRecently;
      if (DateTime.now().difference(_lastHeartbeat).inSeconds >= 3) {
          log('🎤 AUDIO HEARTBEAT: Amp=${amplitude.toStringAsFixed(4)} (Max Recently=${_maxAmplitudeRecently.toStringAsFixed(4)})');
          _lastHeartbeat = DateTime.now();
          _maxAmplitudeRecently = 0.0;
      }

      // 1. ALWAYS run custom HearAlert classification if embeddings available
      if (embeddings != null) {
          if (!_hearAlertService.isInitialized) {
              await _hearAlertService.initialize();
          }
          await _hearAlertService.classifyEmbeddings(embeddings);
      }
      
      // 2. Process YAMNet results
      final List<double> scores = outputBuffer[0];
      final results = _getTopResults(scores);
      
      if (results.isNotEmpty) {
          final topResult = results.first;
          log('🔊 YAMNet: ${topResult.label} (${(topResult.confidence * 100).toStringAsFixed(1)}%)');
          
          // Fallback keyword mapping if custom model isn't picking it up
          await _mapToHearAlertCategories(topResult);
          
          _resultController.add(results);
      }
    } catch (e) {
      log('Inference error: $e');
    }
  }
  
  /// Map YAMNet detection to HearAlert categories for better display names
  Future<void> _mapToHearAlertCategories(ClassificationResult yamnetResult) async {
    final categoryMappings = <String, List<String>>{
      'baby_cry': ['crying baby', 'baby crying', 'infant crying'],
      'dog_bark': ['dog', 'bark', 'barking', 'growl', 'howl', 'dog barking'],
      'cat_meow': ['cat', 'meow', 'purr', 'hiss'],
      'car_horn': ['car horn', 'vehicle horn', 'honking', 'horn', 'beep, horn'],
      'siren': ['siren', 'ambulance', 'police', 'fire engine', 'emergency vehicle'],
      'fire_alarm': ['fire alarm', 'smoke detector', 'alarm'],
      'glass_breaking': ['glass breaking', 'breaking', 'shatter'],
      'door_knock': ['knock', 'door knock', 'knocking'],
      'doorbell': ['doorbell', 'ding-dong', 'bell'],
      'phone_ring': ['telephone', 'ringtone', 'phone', 'ringing'],
      'traffic': ['traffic', 'engine', 'car', 'vehicle'],
      'train': ['train', 'railroad', 'locomotive'],
      'helicopter': ['helicopter', 'rotor'],
      'thunderstorm': ['thunder', 'thunderstorm', 'lightning'],
      'speech': ['speech', 'talking', 'voice', 'conversation', 'male speech', 'female speech'],
      'coughing': ['cough', 'coughing'],
      'breathing': ['breathing', 'snoring', 'wheezing'],
      'footsteps': ['footsteps', 'walking', 'running'],
      'door_creaking': ['door', 'creak', 'squeak'],
      'washing_machine': ['washing machine', 'laundry'],
      'vacuum_cleaner': ['vacuum', 'vacuum cleaner'],
      'keyboard_typing': ['keyboard', 'typing', 'clicking', 'computer keyboard'],
      'clock_tick': ['clock', 'tick', 'ticking'],
      'chainsaw': ['chainsaw', 'power tool'],
      'gunshot_firework': ['gunshot', 'firework', 'explosion', 'cap gun', 'bang'],
      'airplane': ['airplane', 'aircraft', 'jet', 'fixed-wing aircraft'],
    };
    
    final yamnetLabel = yamnetResult.label.toLowerCase();
    
    for (final entry in categoryMappings.entries) {
      for (final keyword in entry.value) {
        if (yamnetLabel.contains(keyword)) {
          log('📍 Mapped "${yamnetResult.label}" → "${entry.key}"');
          break;
        }
      }
    }
  }

  List<ClassificationResult> _getTopResults(List<double> scores) {
    if (_labels == null) return [];
    
    // ALWAYS find and log the top detection for debugging
    double maxScore = 0.0;
    int maxIndex = 0;
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        maxScore = scores[i];
        maxIndex = i;
      }
    }
    
    // Log every detection for debugging
    if (maxIndex < _labels!.length) {
      log('🎧 TOP SOUND: ${_labels![maxIndex]} (${(maxScore * 100).toStringAsFixed(1)}%) Index: $maxIndex');
    }
    
    // First, check for any priority sounds that exceed their thresholds
    final priorityResults = <ClassificationResult>[];
    final regularResults = <ClassificationResult>[];
    
    for (int i = 0; i < scores.length; i++) {
        final score = scores[i];
        final prioritySound = PrioritySoundsDatabase.getByIndex(i);
        
        // Priority threshold: 0.30 (min sensitivity) to 0.01 (max sensitivity) - optimized for deaf users
        final priorityThreshold = 0.30 - (currentSensitivity * 0.29);
        
        if (prioritySound != null && score > priorityThreshold) {
            // Priority sound detected - apply confidence boost
            final boostedScore = score * prioritySound.confidenceBoost;
            
            priorityResults.add(ClassificationResult(
                prioritySound.displayName,
                score,
                DateTime.now(),
                boostedConfidence: boostedScore,
                yamnetIndex: i,
                isPriority: true,
                priority: prioritySound.priority,
                severity: prioritySound.severity,
            ));
        }
    }
    
    // Sort priority results by boosted confidence
    priorityResults.sort((a, b) => b.boostedConfidence.compareTo(a.boostedConfidence));
    
    // If we have priority detections, return them
    if (priorityResults.isNotEmpty) {
        log('✅ PRIORITY DETECTED: ${priorityResults.first.label} (${(priorityResults.first.boostedConfidence * 100).toStringAsFixed(1)}%)');
        return priorityResults.take(3).toList();
    }
    
    // ALWAYS return top result as fallback (for debugging even if low confidence)
    final List<MapEntry<int, double>> indexedScores = [];
    // Base threshold: 0.40 (min sensitivity) to 0.05 (max sensitivity) - more sensitive for accessibility
    final baseThreshold = 0.40 - (currentSensitivity * 0.35);
    for (int i = 0; i < scores.length; i++) {
        // Include sounds above dynamic threshold
        if (scores[i] > baseThreshold) {
          indexedScores.add(MapEntry(i, scores[i]));
        }
    }

    indexedScores.sort((a, b) => b.value.compareTo(a.value));
    
    for (int i = 0; i < 3 && i < indexedScores.length; i++) {
        final index = indexedScores[i].key;
        final score = indexedScores[i].value;
        
        if (index < _labels!.length) {
            // Check if this might be a priority sound by keyword
            final keywordMatch = PrioritySoundsDatabase.getByKeyword(_labels![index]);
            
            regularResults.add(ClassificationResult(
                _labels![index], 
                score, 
                DateTime.now(),
                boostedConfidence: keywordMatch != null ? score * keywordMatch.confidenceBoost : score,
                yamnetIndex: index,
                isPriority: keywordMatch != null,
                priority: keywordMatch?.priority,
                severity: keywordMatch?.severity,
            ));
        }
    }

    return regularResults;
  }

  Future<void> stop() async {
    await _micStreamSubscription?.cancel();
    _micStreamSubscription = null;
    _isRecording = false;
    _audioBuffer.clear();
    log('Microphone stopped.');
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
