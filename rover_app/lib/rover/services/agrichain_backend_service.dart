import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/backend_sensor_point.dart';

class AgriChainBackendService {
  final String baseUrl;

  const AgriChainBackendService({required this.baseUrl});

  Uri _buildUri({required String path, Map<String, String>? query}) {
    final trimmed = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$trimmed$path').replace(queryParameters: query);
  }

  Future<List<BackendSensorPoint>> fetchSensorPoints({
    String? deviceId,
    int? limit,
  }) async {
    final uri = _buildUri(
      path: '/sensor-data',
      query: {
        if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
        if (limit != null) 'limit': limit.toString(),
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Backend error (${response.statusCode})');
    }

    final decoded = json.decode(response.body);

    List<dynamic> items;
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is List) {
        items = data;
      } else {
        final items2 = decoded['items'];
        if (items2 is List) {
          items = items2;
        } else {
          throw Exception('Unexpected backend response shape');
        }
      }
    } else {
      throw Exception('Unexpected backend response type');
    }

    final points = items
        .whereType<Map>()
        .map((e) => BackendSensorPoint.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.isValidLatLon)
        .toList();

    points.sort((a, b) {
      final at = a.createdAt;
      final bt = b.createdAt;
      if (at == null && bt == null) return 0;
      if (at == null) return -1;
      if (bt == null) return 1;
      return at.compareTo(bt);
    });

    return points;
  }
}
