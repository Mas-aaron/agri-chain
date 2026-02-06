import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

class FirebaseModelDownloader {
  // Hosted files live under /models
  static const String baseUrl = 'https://agri-chain-models.web.app/models';

  static Future<Map<String, File>> downloadModelFiles() async {
    try {
      final modelFile = await _downloadFile(
        Uri.parse('$baseUrl/maize_disease.tflite'),
        'maize_disease.tflite',
      );
      final labelsFile = await _downloadFile(
        Uri.parse('$baseUrl/labels.txt'),
        'labels.txt',
      );
      return {
        'model': modelFile,
        'labels': labelsFile,
      };
    } catch (e) {
      // Fallback: try to copy bundled assets if present
      try {
        final dir = await getApplicationDocumentsDirectory();

        // Attempt model from assets (if developer bundled it temporarily)
        final modelBytes = await _tryLoadAssetBytes('assets/maize_disease.tflite');
        File? modelFile;
        if (modelBytes != null) {
          modelFile = File('${dir.path}/maize_disease.tflite');
          await modelFile.writeAsBytes(modelBytes, flush: true);
        }

        // Labels from assets (commonly bundled)
        final labelsBytes = await _tryLoadAssetBytes('assets/labels.txt');
        File? labelsFile;
        if (labelsBytes != null) {
          labelsFile = File('${dir.path}/labels.txt');
          await labelsFile.writeAsBytes(labelsBytes, flush: true);
        }

        if (modelFile != null && labelsFile != null) {
          return {'model': modelFile, 'labels': labelsFile};
        }
      } catch (_) {}

      throw Exception('Failed to download model files: $e');
    }
  }

  static Future<String> getModelVersion() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/model_info.json'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        return (data['version'] ?? '1.0.0').toString();
      }
    } catch (_) {}
    return '1.0.0';
  }

  static Future<File> _downloadFile(Uri url, String fileName) async {
    const int maxRetries = 5;
    Exception? lastError;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final res = await http
            .get(
              url,
              headers: const {
                'User-Agent': 'agri-chain/1.0 (Flutter)'
              },
            )
            .timeout(Duration(seconds: 10 + attempt * 5));
        if (res.statusCode == 200) {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(res.bodyBytes, flush: true);
          return file;
        } else {
          lastError = Exception('HTTP ${res.statusCode} for $url');
        }
      } catch (e) {
        lastError = Exception('Download failed on attempt $attempt: $e');
      }
      // Exponential backoff with jitter
      await Future.delayed(Duration(milliseconds: 400 * attempt + (50 * attempt)));
    }
    throw lastError ?? Exception('Unknown download error for $url');
  }

  static Future<List<int>?> _tryLoadAssetBytes(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
