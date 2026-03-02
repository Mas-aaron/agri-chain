import 'dart:convert';

import 'package:http/http.dart' as http;

class YieldPredictionRequest {
  final String farmerId;
  final String cropType;
  final int season;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double temperature;
  final double humidity;
  final double ph;
  final double rainfall;
  final double pesticide;

  const YieldPredictionRequest({
    this.farmerId = 'FARMER_001',
    this.cropType = 'Maize',
    this.season = 2026,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.temperature,
    required this.humidity,
    required this.ph,
    required this.rainfall,
    required this.pesticide,
  });

  Map<String, dynamic> toJson() => {
        'farmerId': farmerId,
        'cropType': cropType,
        'season': season,
        'nitrogen': nitrogen,
        'phosphorus': phosphorus,
        'potassium': potassium,
        'temperature': temperature,
        'humidity': humidity,
        'ph': ph,
        'rainfall': rainfall,
        'pesticide': pesticide,
      };
}

class TokenInfo {
  final String assetId;
  final String tokenId;
  final double tokenAmount;
  final double currentValue;
  final String status;

  const TokenInfo({
    required this.assetId,
    required this.tokenId,
    required this.tokenAmount,
    required this.currentValue,
    required this.status,
  });

  factory TokenInfo.fromJson(Map<String, dynamic> json) {
    return TokenInfo(
      assetId: json['assetId'] ?? '',
      tokenId: json['tokenId'] ?? '',
      tokenAmount: (json['tokenAmount'] as num?)?.toDouble() ?? 0,
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? '',
    );
  }
}

class PredictAndTokenizeResponse {
  final double predictedYield;
  final String model;
  final double confidence;
  final TokenInfo token;
  final String message;

  const PredictAndTokenizeResponse({
    required this.predictedYield,
    required this.model,
    required this.confidence,
    required this.token,
    required this.message,
  });

  factory PredictAndTokenizeResponse.fromJson(Map<String, dynamic> json) {
    final pred = json['prediction'] as Map<String, dynamic>? ?? {};
    final tok = json['token'] as Map<String, dynamic>? ?? {};

    return PredictAndTokenizeResponse(
      predictedYield: (pred['predicted_yield'] as num?)?.toDouble() ?? 0,
      model: pred['model'] as String? ?? 'unknown',
      confidence: (pred['confidence'] as num?)?.toDouble() ?? 0,
      token: TokenInfo.fromJson(tok),
      message: json['message'] as String? ?? '',
    );
  }
}

class YieldApiService {
  final Uri baseUri;

  const YieldApiService(this.baseUri);

  Map<String, String> _headers() {
    return <String, String>{
      'Content-Type': 'application/json',
    };
  }

  factory YieldApiService.fromBaseUrl(String baseUrl) {
    return YieldApiService(Uri.parse(baseUrl.trim()));
  }

  Uri _url(String path) {
    return baseUri.replace(
      path: baseUri.path.endsWith('/')
          ? '${baseUri.path}${path.startsWith('/') ? path.substring(1) : path}'
          : '${baseUri.path}${path.startsWith('/') ? path : '/$path'}',
    );
  }

  Future<PredictAndTokenizeResponse> predictAndTokenize(YieldPredictionRequest request) async {
    final resp = await http.post(
      _url('/predict-and-tokenize'),
      headers: _headers(),
      body: jsonEncode(request.toJson()),
    );

    if (resp.statusCode >= 400) {
      String message = 'Request failed (${resp.statusCode})';
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['detail'] != null) {
          message = '${decoded['detail']}';
        }
      } catch (_) {}
      throw Exception(message);
    }

    final decoded = jsonDecode(resp.body);
    return PredictAndTokenizeResponse.fromJson(decoded.cast<String, dynamic>());
  }
}
