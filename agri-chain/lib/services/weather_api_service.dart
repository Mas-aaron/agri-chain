import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherSnapshot {
  final double temperatureC;
  final double windSpeed;
  final int weatherCode;

  const WeatherSnapshot({
    required this.temperatureC,
    required this.windSpeed,
    required this.weatherCode,
  });

  factory WeatherSnapshot.fromOpenMeteo(Map<String, dynamic> json) {
    final current = json['current'];
    if (current is! Map) {
      throw Exception('Invalid weather data');
    }

    final rawTemp = current['temperature_2m'];
    final rawWind = current['wind_speed_10m'];
    final rawCode = current['weather_code'];

    final temp = rawTemp is num ? rawTemp.toDouble() : double.tryParse('$rawTemp');
    final wind = rawWind is num ? rawWind.toDouble() : double.tryParse('$rawWind');
    final code = rawCode is int ? rawCode : int.tryParse('$rawCode');

    if (temp == null || wind == null || code == null) {
      throw Exception('Invalid weather data');
    }

    return WeatherSnapshot(
      temperatureC: temp,
      windSpeed: wind,
      weatherCode: code,
    );
  }
}

class WeatherApiService {
  const WeatherApiService();

  Uri _url({required double latitude, required double longitude}) {
    return Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'temperature_2m,wind_speed_10m,weather_code',
      'timezone': 'auto',
    });
  }

  Future<WeatherSnapshot> fetchCurrent({required double latitude, required double longitude}) async {
    final resp = await http.get(_url(latitude: latitude, longitude: longitude));

    if (resp.statusCode >= 400) {
      throw Exception('Weather request failed (${resp.statusCode})');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw Exception('Invalid weather response');
    }

    return WeatherSnapshot.fromOpenMeteo(decoded.cast<String, dynamic>());
  }
}
