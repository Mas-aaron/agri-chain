import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:mindspore_lite_flutter/mindspore_lite_flutter.dart';

enum CropModel {
  maize,
  coffee
}

class TFLiteService {
  static const String _modelPath = 'assets/models/maize_model.ms';
  static const String _labelsPath = 'assets/models/maize_labels.txt';
  
  late List<String> _labels;
  bool _isInitialized = false;
  String _currentModel = 'maize';
  
  // Singleton pattern
  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🔄 Initializing MindSpore service via Plugin...');
      
      final modelPath = _currentModel == 'maize' ? 'assets/models/maize_model.ms' : 'assets/models/coffee_model.ms';
      final labelsPath = _currentModel == 'maize' ? 'assets/models/maize_labels.txt' : 'assets/models/coffee_labels.txt';
      
      // Load labels using rootBundle
      final labelData = await rootBundle.loadString(labelsPath);
      _labels = labelData.split('\n').where((label) => label.isNotEmpty).toList();
      
      final bool success = await MindsporeLiteFlutter.initialize(modelPath);
      
      if (success) {
        _isInitialized = true;
        print('✅ MindSpore Model loaded successfully');
        print('🎯 Classes: $_labels');
      } else {
        throw Exception("Plugin initialization returned false");
      }
    } catch (e) {
      print('❌ Failed to initialize MindSpore: $e');
      rethrow;
    }
  }
  
  Future<void> warmUp() async {
    // Stub
  }
  
  Future<void> setModel(CropModel model) async {
    final newModel = model == CropModel.maize ? 'maize' : 'coffee';
    if (_currentModel != newModel) {
      _currentModel = newModel;
      _isInitialized = false; // Force re-initialization
    }
  }
  
  Future<Map<String, dynamic>> predictImage(File imageFile, {int topK = 3}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      final stopwatch = Stopwatch()..start();
      
      final imageBytes = await imageFile.readAsBytes();
      
      final result = await MindsporeLiteFlutter.runInference(
        imageBytes: imageBytes, 
        width: 224, 
        height: 224,
      );
      
      final inferenceTime = stopwatch.elapsedMilliseconds;
      
      if (result['success'] != true || !result.containsKey('predictions')) {
         throw Exception("Invalid result from MindSpore plugin: ${result['error']}");
      }
      
      final Map<String, dynamic> rawPredictions = result['predictions'];
      
      // Create a fixed size list of zeroes
      List<double> predictions = List<double>.filled(_labels.length, 0.0);
      
      // The plugin returns a map with keys like "class_0", "class_1", with their values
      rawPredictions.forEach((key, value) {
        if (key.startsWith('class_')) {
          int index = int.tryParse(key.split('_')[1]) ?? -1;
          if (index >= 0 && index < predictions.length) {
            predictions[index] = (value as num).toDouble();
          }
        }
      });
      
      final results = _processPredictions(predictions, topK);
      
      return {
        'success': true,
        'predictions': results,
        'inferenceTime': inferenceTime,
        'imagePath': imageFile.path,
      };
      
    } catch (e) {
      print('❌ Prediction error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  List<Map<String, dynamic>> _processPredictions(List<double> predictions, int topK) {
    final indices = List.generate(predictions.length, (index) => index);
    indices.sort((a, b) => predictions[b].compareTo(predictions[a]));
    
    return indices.take(topK).map((index) {
      return {
        'label': _labels.isNotEmpty && index < _labels.length 
            ? _labels[index] 
            : 'Class $index',
        'confidence': predictions[index],
        'percentage': (predictions[index] * 100).toStringAsFixed(2),
        'index': index,
      };
    }).toList();
  }
  
  List<String> get labels => _labels;
  bool get isInitialized => _isInitialized;
  
  void dispose() {
    try {
      MindsporeLiteFlutter.close();
    } catch (e) {
      print('⚠️ Error closing MindSpore: $e');
    }
    _isInitialized = false;
  }
}