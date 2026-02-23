import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:agri_chain/config/app_config.dart';

/// Displays a map with the rover's GPS trail and field polygon.
/// Uses convex hull for accurate field boundary from noisy GPS data.
class FieldMapScreen extends StatefulWidget {
  const FieldMapScreen({super.key});

  @override
  State<FieldMapScreen> createState() => _FieldMapScreenState();
}

class _FieldMapScreenState extends State<FieldMapScreen> {
  List<LatLng> _pathPoints = [];    // smoothed time-ordered trail
  List<LatLng> _hullPoints = [];    // convex hull for polygon
  List<LatLng> _rawPoints = [];
  bool _loading = true;
  String? _error;
  bool _showPolygon = true;
  int _totalReadings = 0;
  LatLng? _lastPosition;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchMapData();
  }

  /// Haversine distance in meters
  double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final h = sinLat * sinLat +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            sinLon * sinLon;
    return 2 * R * math.asin(math.sqrt(h));
  }

  /// Moving-average smoothing for path view
  List<LatLng> _smooth(List<LatLng> pts, {int window = 5}) {
    if (pts.length < window * 2 + 1) return pts;
    final result = <LatLng>[];
    for (int i = 0; i < pts.length; i++) {
      final lo = (i - window).clamp(0, pts.length - 1);
      final hi = (i + window).clamp(0, pts.length - 1);
      double latSum = 0, lonSum = 0;
      int count = 0;
      for (int j = lo; j <= hi; j++) {
        latSum += pts[j].latitude;
        lonSum += pts[j].longitude;
        count++;
      }
      result.add(LatLng(latSum / count, lonSum / count));
    }
    return result;
  }

  /// Cross product for convex hull
  double _cross(LatLng O, LatLng A, LatLng B) {
    return (A.latitude - O.latitude) * (B.longitude - O.longitude) -
        (A.longitude - O.longitude) * (B.latitude - O.latitude);
  }

  /// Convex Hull — Andrew's monotone chain algorithm
  /// Returns the clean outermost boundary from scattered GPS points
  List<LatLng> _convexHull(List<LatLng> points) {
    if (points.length < 3) return points;

    final sorted = List<LatLng>.from(points)
      ..sort((a, b) {
        final cmp = a.latitude.compareTo(b.latitude);
        return cmp != 0 ? cmp : a.longitude.compareTo(b.longitude);
      });

    // Remove exact duplicates
    final unique = <LatLng>[sorted.first];
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].latitude != sorted[i - 1].latitude ||
          sorted[i].longitude != sorted[i - 1].longitude) {
        unique.add(sorted[i]);
      }
    }
    if (unique.length < 3) return unique;

    final n = unique.length;
    final hull = <LatLng>[];

    // Build lower hull
    for (final p in unique) {
      while (hull.length >= 2 &&
          _cross(hull[hull.length - 2], hull.last, p) <= 0) {
        hull.removeLast();
      }
      hull.add(p);
    }

    // Build upper hull
    final lowerLen = hull.length + 1;
    for (int i = n - 2; i >= 0; i--) {
      while (hull.length >= lowerLen &&
          _cross(hull[hull.length - 2], hull.last, unique[i]) <= 0) {
        hull.removeLast();
      }
      hull.add(unique[i]);
    }

    hull.removeLast(); // Remove duplicate of first point
    return hull;
  }

  Future<void> _fetchMapData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/sensor-data/map?limit=2000'),
      );

      if (resp.statusCode != 200) {
        throw Exception('Failed to load map data (${resp.statusCode})');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? [];

      final rawPoints = <LatLng>[];
      for (final feature in features) {
        final coords = feature['geometry']?['coordinates'] as List<dynamic>?;
        final props = feature['properties'] as Map<String, dynamic>? ?? {};
        final hdop = (props['hdop'] as num?)?.toDouble() ?? 99.0;

        // Skip poor GPS quality
        if (hdop > 8) continue;

        if (coords != null && coords.length >= 2) {
          final lon = (coords[0] as num).toDouble();
          final lat = (coords[1] as num).toDouble();
          if (lat != 0 && lon != 0) {
            rawPoints.add(LatLng(lat, lon));
          }
        }
      }

      // Dedup for path
      final deduped = <LatLng>[];
      for (final pt in rawPoints) {
        if (deduped.isEmpty || _distanceMeters(deduped.last, pt) >= 2.0) {
          deduped.add(pt);
        }
      }

      // Smoothed trail (time-order)
      final smoothed = _smooth(deduped, window: 5);

      // Convex hull for field boundary
      final hull = _convexHull(rawPoints);

      setState(() {
        _rawPoints = rawPoints;
        _pathPoints = smoothed;
        _hullPoints = hull;
        _totalReadings = rawPoints.length;
        _lastPosition = rawPoints.isNotEmpty ? rawPoints.last : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Map'),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showPolygon ? Icons.polyline : Icons.crop_square),
            tooltip: _showPolygon ? 'Show Path' : 'Show Polygon',
            onPressed: () => setState(() => _showPolygon = !_showPolygon),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMapData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _rawPoints.isEmpty
                  ? _buildEmpty()
                  : _buildMap(scheme),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _fetchMapData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.satellite_alt, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No GPS Data Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Drive the rover around your field to map its boundaries. '
              'GPS coordinates are sent to the server every 10 seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _fetchMapData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(ColorScheme scheme) {
    final center = _lastPosition ?? _rawPoints.first;
    final allPoints = _showPolygon ? _hullPoints : _pathPoints;
    final boundsPoints = allPoints.isNotEmpty ? allPoints : _rawPoints;
    final bounds = LatLngBounds.fromPoints(boundsPoints);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 18,
            maxZoom: 22,
            minZoom: 5,
          ),
          children: [
            // OSM tile layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.agrichain.app',
            ),

            // POLYGON MODE — convex hull (clean field boundary)
            if (_showPolygon && _hullPoints.length >= 3)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _hullPoints,
                    color: const Color(0xFF2E7D32).withOpacity(0.25),
                    borderColor: const Color(0xFF2E7D32),
                    borderStrokeWidth: 3,
                    isFilled: true,
                  ),
                ],
              ),

            // PATH MODE — smoothed trail
            if (!_showPolygon)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _pathPoints,
                    color: const Color(0xFF7B1FA2),
                    strokeWidth: 3,
                  ),
                ],
              ),

            // Markers
            MarkerLayer(
              markers: [
                // Start flag
                if (_rawPoints.isNotEmpty)
                  Marker(
                    point: _rawPoints.first,
                    width: 32,
                    height: 32,
                    child: const Icon(Icons.flag, color: Colors.green, size: 28),
                  ),
                // Rover position (latest)
                if (_rawPoints.length > 1)
                  Marker(
                    point: _rawPoints.last,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.my_location,
                          color: Colors.white, size: 22),
                    ),
                  ),
                // Hull vertex markers
                if (_showPolygon)
                  ..._hullPoints.map(
                    (pt) => Marker(
                      point: pt,
                      width: 14,
                      height: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF7B1FA2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Info overlay
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1), blurRadius: 10)
              ],
            ),
            child: Row(
              children: [
                Icon(
                  _showPolygon ? Icons.crop_square : Icons.polyline,
                  color: _showPolygon
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF7B1FA2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _showPolygon
                            ? 'Field Boundary (Convex Hull)'
                            : 'Rover Trail (Smoothed)',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      Text(
                        _showPolygon
                            ? '${_hullPoints.length} boundary vertices from $_totalReadings GPS points'
                            : '$_totalReadings GPS points, ${_pathPoints.length} after filtering',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.fit_screen),
                  tooltip: 'Fit to bounds',
                  onPressed: () {
                    _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(50),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Live coordinates
        if (_lastPosition != null)
          Positioned(
            bottom: 16,
            left: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surface.withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Last: ${_lastPosition!.latitude.toStringAsFixed(6)}, '
                    '${_lastPosition!.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                        fontSize: 12, fontFamily: 'monospace'),
                  ),
                  const Spacer(),
                  Text(
                    '$_totalReadings pts',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
