import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:image/image.dart' as img;

class TFLiteService {
  static const String _modelPath = 'assets/maize_disease.tflite';
  static const String _labelsPath = 'assets/labels.txt';
  
  late Interpreter _interpreter;
  late List<String> _labels;
  bool _isInitialized = false;
  
  // Singleton pattern
  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🔄 Initializing TFLite service...');
      
      // Load model
      final options = InterpreterOptions();
      options.threads = 4; // Use 4 threads for CPU
      
      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        options: options,
      );
      
      // Load labels
      final labelData = await DefaultAssetBundle.of(Instance)
          .loadString(_labelsPath);
      _labels = labelData.split('\n').where((label) => label.isNotEmpty).toList();
      
      // Print model info
      print('✅ Model loaded successfully');
      print('📊 Input shape: ${_interpreter.getInputTensor(0).shape}');
      print('📈 Output shape: ${_interpreter.getInputTensor(0).shape}');
      print('🎯 Classes: $_labels');
      
      _isInitialized = true;
      
      // Warm up model
      await warmUp();
      
    } catch (e) {
      print('❌ Failed to initialize TFLite: $e');
      rethrow;
    }
  }
  
  Future<void> warmUp() async {
    try {
      // Create dummy input
      final inputShape = _interpreter.getInputTensor(0).shape;
      final dummyInput = List.generate(
        inputShape.reduce((a, b) => a * b),
        (_) => 0.0,
      ).reshape(inputShape);
      
      final outputShape = _interpreter.getOutputTensor(0).shape;
      final dummyOutput = List.generate(
        outputShape.reduce((a, b) => a * b),
        (_) => 0.0,
      ).reshape(outputShape);
      
      // Run warm-up inference
      _interpreter.run(dummyInput, dummyOutput);
      print('🔥 Model warmed up');
    } catch (e) {
      print('⚠️ Warm-up failed: $e');
    }
  }
  
  Future<Map<String, dynamic>> predictImage(File imageFile, {int topK = 3}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      // Load and preprocess image
      final inputImage = img.decodeImage(await imageFile.readAsBytes())!;
      final processedImage = _preprocessImage(inputImage);
      
      // Prepare input/output tensors
      final inputShape = _interpreter.getInputTensor(0).shape;
      final outputShape = _interpreter.getOutputTensor(0).shape;
      
      final inputBuffer = processedImage.buffer.asFloat32List();
      final inputTensor = inputBuffer.reshape(inputShape);
      
      final outputBuffer = Float32List(outputShape.reduce((a, b) => a * b));
      final outputTensor = outputBuffer.reshape(outputShape);
      
      // Run inference
      final stopwatch = Stopwatch()..start();
      _interpreter.run(inputTensor, outputTensor);
      final inferenceTime = stopwatch.elapsedMilliseconds;
      
      // Process results
      final predictions = outputTensor[0];
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
  
  List<double> _preprocessImage(img.Image image) {
    // Resize to model input size (224x224)
    final resized = img.copyResize(
      image,
      width: 224,
      height: 224,
    );
    
    // Convert to float32 array and normalize (0-1)
    final pixels = resized.getBytes();
    final floatPixels = List<double>.filled(224 * 224 * 3, 0.0);
    
    for (var i = 0; i < pixels.length; i += 3) {
      final pixelIndex = i ~/ 3;
      floatPixels[pixelIndex * 3] = pixels[i].toDouble() / 255.0;     // R
      floatPixels[pixelIndex * 3 + 1] = pixels[i + 1].toDouble() / 255.0; // G
      floatPixels[pixelIndex * 3 + 2] = pixels[i + 2].toDouble() / 255.0; // B
    }
    
    return floatPixels;
  }
  
  List<Map<String, dynamic>> _processPredictions(List<double> predictions, int topK) {
    // Create list of indices sorted by probability
    final indices = List.generate(predictions.length, (index) => index);
    indices.sort((a, b) => predictions[b].compareTo(predictions[a]));
    
    // Get top K predictions
    return indices.take(topK).map((index) {
      return {
        'label': _labels.isNotEmpty && index < _labels.length 
            ? _labels[index] 
            : 'Class $index',
        'confidence': predictions[index],
        'percentage': (predictions[index] * 100),
        'index': index,
      };
    }).toList();
  }
  
  List<String> get labels => _labels;
  bool get isInitialized => _isInitialized;
  
  void dispose() {
    _interpreter.close();
    _isInitialized = false;
  }
}