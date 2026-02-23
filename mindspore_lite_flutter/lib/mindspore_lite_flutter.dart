import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/services.dart';

/// Public Dart interface for the MindSpore Lite Flutter plugin.
///
/// Channel: "com.agrichain.mindspore"
///
/// For most use-cases in the agri-chain app, prefer using [MindSporeService]
/// in `lib/services/mindspore_service.dart` which wraps this API with label
/// loading, top-K processing, and error handling.
class MindsporeLiteFlutter {
  static const MethodChannel _channel =
      MethodChannel('com.agrichain.mindspore');

  /// Initialize MindSpore Lite with an asset model path.
  ///
  /// [modelPath] must be a Flutter asset path, e.g.
  ///   `"assets/models/maize_model.ms"`
  ///
  /// The plugin will copy the `.ms` file from Flutter assets to the app's
  /// internal storage on first use (subsequent calls use a cached copy).
  ///
  /// Returns `true` on success.
  static Future<bool> initModel(String modelPath) async {
    try {
      final bool? result =
          await _channel.invokeMethod('initModel', {'modelPath': modelPath});
      return result ?? false;
    } on PlatformException catch (e) {
      print('MindsporeLiteFlutter.initModel failed: ${e.message}');
      return false;
    }
  }

  /// Run inference on an image at [imagePath] (absolute device file path).
  ///
  /// Returns a map with:
  ///   - `predictions`: `List<double>` — raw softmax scores per class
  ///   - `inferenceMs`: `int`          — inference time in milliseconds
  static Future<Map<String, dynamic>> predictImage(String imagePath) async {
    try {
      final Map<dynamic, dynamic>? result = await _channel
          .invokeMethod('predictImage', {'imagePath': imagePath});
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      print('MindsporeLiteFlutter.predictImage failed: ${e.message}');
      return {'error': e.message};
    }
  }

  /// Release all native resources (model + context).
  ///
  /// Call this when you are done with inference to free memory.
  static Future<bool> disposeModel() async {
    try {
      final bool? result = await _channel.invokeMethod('disposeModel');
      return result ?? false;
    } on PlatformException catch (e) {
      print('MindsporeLiteFlutter.disposeModel failed: ${e.message}');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────
  // Legacy API (kept for backward compatibility)
  // ──────────────────────────────────────────────────────────

  /// @deprecated Use [initModel] instead.
  static Future<bool> initialize(String modelPath) => initModel(modelPath);

  /// @deprecated Use [predictImage] instead.
  static Future<Map<String, dynamic>> runInference({
    required Uint8List imageBytes,
    required int width,
    required int height,
  }) async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod('runInference', {
        'imageBytes': imageBytes,
        'width': width,
        'height': height,
      });
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      print('MindsporeLiteFlutter.runInference failed: ${e.message}');
      return {'error': e.message};
    }
  }

  /// @deprecated Use [disposeModel] instead.
  static Future<bool> close() => disposeModel();
}
