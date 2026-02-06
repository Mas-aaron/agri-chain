import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'firebase_model_downloader.dart';

class TFLiteService {
  static const String _modelFileName = 'maize_disease.tflite';
  static const String _labelsFileName = 'labels.txt';

  static const MethodChannel _channel = MethodChannel('agri_chain/tflite');
  List<String> _labels = const [];
  bool _isInitialized = false;
  List<int> _inputShape = const [];
  List<int> _outputShape = const [];
  String _outputType = '';

  int get _inputHeight => _inputShape.length >= 4 ? _inputShape[1] : 224;
  int get _inputWidth => _inputShape.length >= 4 ? _inputShape[2] : 224;

  // Singleton
  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Ensure model and labels exist locally
    final appDir = await getApplicationDocumentsDirectory();
    final modelPath = File('${appDir.path}/$_modelFileName');
    final labelsPath = File('${appDir.path}/$_labelsFileName');

    bool shouldRefreshFromAssets = false;
    try {
      final assetModelData = await rootBundle.load('assets/maize_disease.tflite');
      final assetLabelsText = await rootBundle.loadString('assets/labels.txt');
      final assetLabels = assetLabelsText
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (!await modelPath.exists() || !await labelsPath.exists()) {
        shouldRefreshFromAssets = true;
      } else {
        final localModelLength = await modelPath.length();
        final assetModelLength = assetModelData.lengthInBytes;
        if (localModelLength != assetModelLength) {
          shouldRefreshFromAssets = true;
        }

        final localLabels = (await labelsPath.readAsLines())
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        if (localLabels.length != assetLabels.length) {
          shouldRefreshFromAssets = true;
        } else {
          for (var i = 0; i < assetLabels.length; i++) {
            if (localLabels[i] != assetLabels[i]) {
              shouldRefreshFromAssets = true;
              break;
            }
          }
        }
      }

      if (shouldRefreshFromAssets) {
        await modelPath.writeAsBytes(assetModelData.buffer.asUint8List(), flush: true);
        await labelsPath.writeAsString(assetLabelsText, flush: true);
      }
    } catch (_) {
      // Assets might not be bundled; fall back to downloader if needed.
    }

    if (!await modelPath.exists() || !await labelsPath.exists()) {
      final downloaded = await FirebaseModelDownloader.downloadModelFiles();
      await downloaded['model']!.copy(modelPath.path);
      await downloaded['labels']!.copy(labelsPath.path);
    }

    // Load labels
    _labels = await labelsPath.readAsLines();
    _labels = _labels.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // Load model with proper configuration
    final info = await _channel.invokeMethod<Map<dynamic, dynamic>>('loadModel', {
      'modelPath': modelPath.path,
      'threads': 2,  // Optimal for most devices
      'useGPU': false,  // Disable GPU first for debugging
    });
    
    if (info == null) {
      throw Exception('Failed to load model (no response from platform).');
    }
    
    _inputShape = (info['inputShape'] as List).cast<int>();
    _outputShape = (info['outputShape'] as List).cast<int>();
    _outputType = (info['outputType'] as String?) ?? '';
    
    print('🎯 Model Loaded Successfully');
    print('   Input Shape: $_inputShape');
    print('   Output Shape: $_outputShape');
    print('   Output Type: $_outputType');
    print('   Number of Labels: ${_labels.length}');
    
    _isInitialized = true;
  }

  Future<void> verifyModelInputs() async {
  if (!_isInitialized) await initialize();
  
  print('=== MODEL VERIFICATION ===');
  print('Expected input size: ${_inputWidth} x ${_inputHeight} x 3');
  print('Model input shape: $_inputShape');
  print('Model output shape: $_outputShape');
  print('Model output type: $_outputType');
  
  // Calculate expected bytes
  final expectedBytes = _inputWidth * _inputHeight * 3 * 4; // float32 = 4 bytes
  print('Expected input bytes: $expectedBytes');
  
  // Test with a sample image
  final testImage = img.Image(width: _inputWidth, height: _inputHeight);
  img.fill(testImage, color: img.ColorRgb8(128, 128, 128));
  
  final input = Float32List(_inputWidth * _inputHeight * 3);
  for (int i = 0; i < input.length; i += 3) {
    input[i] = 0.5;   // R = 128/255
    input[i+1] = 0.5; // G
    input[i+2] = 0.5; // B
  }
  
  print('Test input bytes: ${input.buffer.asUint8List().length}');
  print('Test input first values: ${input.take(6).toList()}');
}

  Future<Map<String, dynamic>> predictImage(File imageFile, {int topK = 3}) async {
    if (!_isInitialized) await initialize();

    try {
      // 1. Load and decode image
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Failed to decode image');
      }

      final oriented = img.bakeOrientation(decoded);

      // 2. Resize to model input size with BILINEAR interpolation
      // CRITICAL: Must match TensorFlow's 'bilinear'
      final resized = img.copyResize(
        oriented,
        width: _inputWidth,
        height: _inputHeight,
        interpolation: img.Interpolation.linear,  // Matches TensorFlow's bilinear
      );

      // 3. Debug: Print first few pixels
      print('🔍 Preprocessing Debug:');
      print('   Original: ${decoded.width}x${decoded.height}');
      print('   Resized: ${resized.width}x${resized.height}');
      
      // Check first pixel
      final firstPixel = resized.getPixel(0, 0);
      print('   First Pixel Raw - R:${firstPixel.r} G:${firstPixel.g} B:${firstPixel.b}');
      print('   First Pixel Normalized - R:${firstPixel.r/255.0} G:${firstPixel.g/255.0} B:${firstPixel.b/255.0}');

      // 4. Build input tensor
      // TensorFlow uses NHWC format: [batch, height, width, channels]
      // We create [1, height, width, 3] with RGB order
      final input = Float32List(_inputHeight * _inputWidth * 3);
      int idx = 0;
      
      for (int y = 0; y < _inputHeight; y++) {
        for (int x = 0; x < _inputWidth; x++) {
          final pixel = resized.getPixel(x, y);
          
          // CRITICAL: Normalize to [0, 1] exactly like TensorFlow's Rescaling(1./255)
          // NO mean/std subtraction unless your training used it
          final r = pixel.r / 255.0;  // Normalize Red
          final g = pixel.g / 255.0;  // Normalize Green
          final b = pixel.b / 255.0;  // Normalize Blue
          
          input[idx++] = r;
          input[idx++] = g;
          input[idx++] = b;
        }
      }

      // 5. Verify input range
      final minVal = input.reduce(math.min);
      final maxVal = input.reduce(math.max);
      print('   Input Range: [$minVal, $maxVal]');
      print('   Expected: [0.0, 1.0]');

      // 6. Run inference
      final inputBytes = input.buffer.asUint8List();
      final stopwatch = Stopwatch()..start();
      
      final rawOutput = await _channel.invokeMethod<List<dynamic>>('run', {
        'input': inputBytes,
      });
      
      final inferenceTime = stopwatch.elapsedMilliseconds;

      if (rawOutput == null) {
        throw Exception('Native inference returned null output.');
      }

      // 7. Process output
      final scores = rawOutput.map((e) => (e as num).toDouble()).toList();
      
      print('📊 Output Analysis:');
      print('   Output length: ${scores.length}');
      print('   Scores: ${scores.take(3).toList()}');
      print('   Sum: ${scores.fold(0.0, (a, b) => a + b)}');
      print('   Inference time: ${inferenceTime}ms');

      // 8. Determine if outputs are logits or probabilities
      final sum = scores.fold(0.0, (a, b) => a + b.abs());
      List<double> finalScores;
      
      if (sum == 0) {
        // All zeros - something wrong
        throw Exception('All outputs are zero');
      } else if (sum < 0.99 || sum > 1.01) {
        // Not summing to ~1.0, likely logits - apply softmax
        print('   Applying softmax (detected logits)');
        finalScores = _softmax(scores);
      } else {
        // Already probabilities
        print('   Using raw outputs (detected probabilities)');
        finalScores = scores;
      }

      // 9. Get top K predictions
      final topPredictions = _topK(finalScores, topK);
      
      // 10. Build response
      final predictions = topPredictions.map((score) {
        final labelIndex = score.index;
        final label = labelIndex < _labels.length 
            ? _labels[labelIndex] 
            : 'Class $labelIndex';
            
        return {
          'label': label,
          'confidence': score.score,
          'percentage': (score.score * 100).toStringAsFixed(2),
          'index': labelIndex,
        };
      }).toList();

      return {
        'success': true,
        'predictions': predictions,
        'inferenceTime': inferenceTime,
        'imagePath': imageFile.path,
        'outputType': _outputType,
        'inputSize': '${_inputWidth}x$_inputHeight',
        'debug': {
          'inputRange': '[$minVal, $maxVal]',
          'outputSum': scores.fold(0.0, (a, b) => a + b),
          'needsSoftmax': (sum < 0.99 || sum > 1.01),
        },
      };

    } catch (e, stackTrace) {
      print('❌ Prediction error: $e');
      print('Stack trace: $stackTrace');
      
      return {
        'success': false,
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> testWithSampleImage() async {
    if (!_isInitialized) await initialize();

    final testImage = img.Image(width: _inputWidth, height: _inputHeight);
    for (int y = 0; y < _inputHeight; y++) {
      for (int x = 0; x < _inputWidth; x++) {
        testImage.setPixelRgba(x, y, 128, 128, 128, 255);
      }
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/test_gray.png');
    await tempFile.writeAsBytes(img.encodePng(testImage));

    return await predictImage(tempFile);
  }

  List<String> get labels => _labels;
  bool get isInitialized => _isInitialized;
  int get modelInputSize => _inputWidth;
  List<int> get inputShape => _inputShape;

  void dispose() {
    try {
      _channel.invokeMethod('close');
    } catch (_) {}
    _isInitialized = false;
  }

  List<Score> _topK(List<double> scores, int k) {
    final pairs = List.generate(scores.length, (i) => Score(i, scores[i]));
    pairs.sort((a, b) => b.score.compareTo(a.score));
    return pairs.take(math.min(k, pairs.length)).toList();
  }

  List<double> _softmax(List<double> x) {
    if (x.isEmpty) return x;
    final maxVal = x.reduce(math.max);
    final exps = x.map((v) => math.exp(v - maxVal)).toList();
    final sum = exps.fold(0.0, (a, b) => a + b);
    if (sum == 0) return x;
    return exps.map((e) => e / sum).toList();
  }
}

class Score {
  final int index;
  final double score;
  Score(this.index, this.score);
}