import 'dart:convert';

import 'package:http/http.dart' as http;

class YieldPredictionRequest {
  final String region;
  final String soilType;
  final double rainfallMm;
  final double temperatureCelsius;
  final bool fertilizerUsed;
  final bool irrigationUsed;
  final String weatherCondition;
  final int daysToHarvest;

  const YieldPredictionRequest({
    required this.region,
    required this.soilType,
    required this.rainfallMm,
    required this.temperatureCelsius,
    required this.fertilizerUsed,
    required this.irrigationUsed,
    required this.weatherCondition,
    required this.daysToHarvest,
  });

  Map<String, dynamic> toJson() => {
        'region': region,
        'soil_type': soilType,
        'rainfall_mm': rainfallMm,
        'temperature_celsius': temperatureCelsius,
        'fertilizer_used': fertilizerUsed,
        'irrigation_used': irrigationUsed,
        'weather_condition': weatherCondition,
        'days_to_harvest': daysToHarvest,
      };
}

class YieldPredictionResponse {
  final double predictedYield;
  final double? confidence;
  final String? message;

  const YieldPredictionResponse({
    required this.predictedYield,
    required this.confidence,
    required this.message,
  });

  factory YieldPredictionResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['predicted_yield'];
    final predicted = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0.0;

    final rawConf = json['confidence'];
    final conf = rawConf == null ? null : (rawConf is num ? rawConf.toDouble() : double.tryParse('$rawConf'));

    return YieldPredictionResponse(
      predictedYield: predicted,
      confidence: conf,
      message: json['message'] as String?,
    );
  }
}

class YieldApiService {
  final Uri baseUri;

  const YieldApiService(this.baseUri);

  static Uri _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('baseUrl is empty');
    }
    return Uri.parse(trimmed);
  }

  factory YieldApiService.fromBaseUrl(String baseUrl) {
    return YieldApiService(_normalizeBaseUrl(baseUrl));
  }

  Uri _url(String path) {
    return baseUri.replace(
      path: baseUri.path.endsWith('/')
          ? '${baseUri.path}${path.startsWith('/') ? path.substring(1) : path}'
          : '${baseUri.path}${path.startsWith('/') ? path : '/$path'}',
    );
  }

  Future<YieldPredictionResponse> predict(YieldPredictionRequest request) async {
    final resp = await http.post(
      _url('/predict'),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (resp.statusCode >= 400) {
      String message = 'Request failed (${resp.statusCode})';
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['detail'] != null) {
          message = '${decoded['detail']}';
        }
      } catch (_) {
        // ignore
      }
      throw Exception(message);
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw Exception('Invalid response from server');
    }

    return YieldPredictionResponse.fromJson(decoded.cast<String, dynamic>());
  }
}
