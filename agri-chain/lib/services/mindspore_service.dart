import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

enum CropModel {
  maize,
  coffee
}

class MindSporeService {
  static const MethodChannel _channel = MethodChannel('com.agrichain.mindspore');

  static final MindSporeService _instance = MindSporeService._internal();
  factory MindSporeService() => _instance;
  MindSporeService._internal();

  bool _isInitialized = false;
  late List<String> _labels;
  String _currentModel = '';

  Future<void> initialize({required String modelType}) async {
    try {
      if (_isInitialized && _currentModel == modelType) return;
      print('🔄 Initializing MindSpore service for $modelType...');

      String modelPath;
      String labelsPath;

      if (modelType.toLowerCase() == 'coffee') {
        modelPath = 'assets/models/coffee_model.ms';
        labelsPath = 'assets/models/coffee_labels.txt';
      } else {
        // Default to maize
        modelPath = 'assets/models/maize_model.ms';
        labelsPath = 'assets/models/maize_labels.txt';
      }

      // Load labels
      final labelData = await rootBundle.loadString(labelsPath);
      _labels = labelData.split('\n').where((label) => label.trim().isNotEmpty).toList();

      // Initialize native model
      final bool? success = await _channel.invokeMethod('initModel', {
        'modelPath': modelPath,
      });

      if (success == true) {
        _isInitialized = true;
        _currentModel = modelType;
        print('✅ MindSpore Lite $modelType model loaded successfully via Native Channel!');
        print('🎯 Classes: $_labels');
      } else {
        throw Exception("Native initialization returned false");
      }
    } catch (e) {
      print('❌ Failed to initialize MindSpore: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> predictImage(File imageFile, {int topK = 3}) async {
    if (!_isInitialized) {
      await initialize(modelType: 'maize'); // Fallback initialization
    }

    try {
      final stopwatch = Stopwatch()..start();
      
      // Call native Android/iOS method to run prediction on the image
      final Map<dynamic, dynamic>? result = await _channel.invokeMapMethod('predictImage', {
        'imagePath': imageFile.path,
        'modelType': _currentModel, // tells native side which preprocessor to use
      });
      
      final inferenceTime = stopwatch.elapsedMilliseconds;

      if (result == null || !result.containsKey('predictions')) {
        throw Exception("Invalid result from native MindSpore Lite");
      }

      // Convert probabilities from native array to ordered list
      // Cast safely: Java returns List<Double> which Dart sees as List<dynamic>
      List<double> predictions = (result['predictions'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      
      final processedResults = _processPredictions(predictions, topK);

      return {
        'success': true,
        'predictions': processedResults,
        'inferenceTime': inferenceTime,
        'imagePath': imageFile.path,
        'model': _currentModel,
      };
    } catch (e) {
      print('❌ Prediction error via MindSpore Channel: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Apply softmax to convert raw logits → probabilities [0,1] summing to 1.
  // Required because the model was trained with SoftmaxCrossEntropyWithLogits,
  // which does NOT bake softmax into the model graph — outputs are raw logits.
  List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce(math.max); // numerical stability
    final expVals = logits.map((v) => math.exp(v - maxVal)).toList();
    final sumExp = expVals.reduce((a, b) => a + b);
    return expVals.map((v) => v / sumExp).toList();
  }

  List<Map<String, dynamic>> _processPredictions(List<double> rawLogits, int topK) {
    if (rawLogits.isEmpty) return [];

    // Convert logits → valid probabilities
    final probabilities = _softmax(rawLogits);

    final indices = List.generate(probabilities.length, (i) => i);
    indices.sort((a, b) => probabilities[b].compareTo(probabilities[a]));

    return indices.take(topK).map((index) {
      final prob = probabilities[index];
      return {
        'label': _labels.isNotEmpty && index < _labels.length
            ? _labels[index]
            : 'Class $index',
        'confidence': prob,
        'percentage': (prob * 100).toStringAsFixed(1),
        'index': index,
      };
    }).toList();
  }

  List<String> get labels => _labels;
  bool get isInitialized => _isInitialized;
  String get currentModel => _currentModel;

  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('disposeModel');
    } catch (e) {
      print('⚠️ Error disposing MindSpore interpreter: $e');
    }
    _isInitialized = false;
    _currentModel = '';
  }
}
