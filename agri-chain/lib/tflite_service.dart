import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
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
      
      // Load labels using rootBundle (correct way for assets)
      final labelData = await rootBundle.loadString(_labelsPath);
      _labels = labelData.split('\n').where((label) => label.isNotEmpty).toList();
      
      // Print model info
      print('✅ Model loaded successfully');
      print('📊 Input shape: ${_interpreter.getInputTensor(0).shape}');
      print('📈 Output shape: ${_interpreter.getOutputTensor(0).shape}');
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
      // Create dummy input with proper shape
      final inputShape = _interpreter.getInputTensor(0).shape;
      final totalElements = inputShape.reduce((a, b) => a * b);
      final dummyInput = Float32List(totalElements);
      
      final outputShape = _interpreter.getOutputTensor(0).shape;
      final totalOutputElements = outputShape.reduce((a, b) => a * b);
      final dummyOutput = Float32List(totalOutputElements);
      
      // Run warm-up inference - no need for buffer access
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
      
      // Ensure input matches expected shape
      final expectedInputSize = inputShape.reduce((a, b) => a * b);
      if (processedImage.length != expectedInputSize) {
        throw Exception('Input size mismatch: expected $expectedInputSize, got ${processedImage.length}');
      }
      
      final inputBuffer = Float32List.fromList(processedImage);
      final outputBuffer = Float32List(outputShape.reduce((a, b) => a * b));
      
      // Run inference
      final stopwatch = Stopwatch()..start();
      _interpreter.run(inputBuffer, outputBuffer);
      final inferenceTime = stopwatch.elapsedMilliseconds;
      
      // Process results
      final predictions = outputBuffer.map((e) => e.toDouble()).toList();
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
    // Get model input shape
    final inputShape = _interpreter.getInputTensor(0).shape;
    final inputHeight = inputShape.length > 1 ? inputShape[1] : 224;
    final inputWidth = inputShape.length > 2 ? inputShape[2] : 224;
    
    // Resize to model input size
    final resized = img.copyResize(
      image,
      width: inputWidth,
      height: inputHeight,
    );
    
    // Convert to float32 array and normalize (0-1)
    final floatPixels = List<double>.filled(inputHeight * inputWidth * 3, 0.0);
    int idx = 0;
    for (int y = 0; y < inputHeight; y++) {
      for (int x = 0; x < inputWidth; x++) {
        final px = resized.getPixel(x, y);
        floatPixels[idx++] = px.r / 255.0; // R
        floatPixels[idx++] = px.g / 255.0; // G
        floatPixels[idx++] = px.b / 255.0; // B
      }
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
        'percentage': (predictions[index] * 100).toStringAsFixed(2),
        'index': index,
      };
    }).toList();
  }
  
  List<String> get labels => _labels;
  bool get isInitialized => _isInitialized;
  
  void dispose() {
    try {
      _interpreter.close();
    } catch (e) {
      print('⚠️ Error closing interpreter: $e');
    }
    _isInitialized = false;
  }
}