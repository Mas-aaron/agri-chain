import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/yield_asset.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';

  static Future<List<YieldAsset>> getYieldAssets(String farmerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/assets/$farmerId'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((asset) => YieldAsset.fromJson(asset)).toList();
      } else {
        throw Exception('Failed to load assets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading assets: $e');
    }
  }

  static Future<YieldAsset> createYieldAsset(YieldAsset asset) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/assets'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(asset.toJson()),
          )
          .timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode == 201) {
        return YieldAsset.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create asset: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating asset: $e');
    }
  }

  static Future<YieldAsset> updateYieldAsset(
      String assetId, YieldAsset asset) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/assets/$assetId'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(asset.toJson()),
          )
          .timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode == 200) {
        return YieldAsset.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update asset: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating asset: $e');
    }
  }

  static Future<void> deleteYieldAsset(String assetId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/assets/$assetId'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete asset: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting asset: $e');
    }
  }
}
