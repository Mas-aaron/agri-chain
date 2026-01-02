import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

class TFLiteService {
  static const String _labelsPath = 'assets/labels.txt';

  bool _isInitialized = false;
  List<String> _labels = const [];

  // Singleton pattern (match existing usage)
  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      // Load labels if available
      final data = await rootBundle.loadString(_labelsPath);
      _labels = data
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      _labels = const ['Healthy', 'Common Rust', 'Gray Leaf Spot', 'NLB'];
    }
    _isInitialized = true;
  }

  Future<Map<String, dynamic>> predictImage(File imageFile, {int topK = 3}) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Stubbed predictions (since TFLite model isn't wired yet)
    final labels = _labels.isNotEmpty ? _labels : ['Class 0', 'Class 1', 'Class 2'];
    final results = List.generate(
      topK.clamp(1, labels.length),
      (i) => {
        'label': labels[i],
        'confidence': 0.5 - i * 0.1,
        'percentage': (0.5 - i * 0.1) * 100,
        'index': i,
      },
    );

    return {
      'success': true,
      'predictions': results,
      'inferenceTime': 0,
      'imagePath': imageFile.path,
    };
  }

  List<String> get labels => _labels;
  bool get isInitialized => _isInitialized;

  void dispose() {
    _isInitialized = false;
  }
}
