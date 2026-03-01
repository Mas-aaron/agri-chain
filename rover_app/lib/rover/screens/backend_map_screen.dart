import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/backend_sensor_point.dart';
import '../services/agrichain_backend_service.dart';

class BackendMapScreen extends StatefulWidget {
  final String baseUrl;
  final String deviceId;

  const BackendMapScreen({
    super.key,
    required this.baseUrl,
    required this.deviceId,
  });

  @override
  State<BackendMapScreen> createState() => _BackendMapScreenState();
}

class _BackendMapScreenState extends State<BackendMapScreen> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();

  bool _isLoading = false;
  String? _error;
  List<BackendSensorPoint> _points = const [];
  DateTime? _lastFetchAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = AgriChainBackendService(baseUrl: widget.baseUrl);
      final points = await service.fetchSensorPoints(deviceId: widget.deviceId);
      final cleaned = _removeNearDuplicates(points);

      setState(() {
        _points = cleaned;
        _lastFetchAt = DateTime.now();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitToRoute();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<BackendSensorPoint> _removeNearDuplicates(List<BackendSensorPoint> input) {
    if (input.length < 2) return input;

    const minDistanceMeters = 1.5;
    final out = <BackendSensorPoint>[];

    BackendSensorPoint? last;
    for (final p in input) {
      if (!p.isValidLatLon) continue;

      if (last == null) {
        out.add(p);
        last = p;
        continue;
      }

      final a = LatLng(last.latitude, last.longitude);
      final b = LatLng(p.latitude, p.longitude);
      final meters = _distance.as(LengthUnit.Meter, a, b);
      if (meters >= minDistanceMeters) {
        out.add(p);
        last = p;
      }
    }

    // Ensure last point kept.
    final lastIn = input.isNotEmpty ? input.last : null;
    if (lastIn != null && out.isNotEmpty) {
      final outLast = out.last;
      if (outLast.latitude != lastIn.latitude || outLast.longitude != lastIn.longitude) {
        out.add(lastIn);
      }
    }

    return out;
  }

  void _fitToRoute() {
    if (_points.isEmpty) return;

    final latLngs = _points
        .where((p) => p.isValidLatLon)
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    if (latLngs.isEmpty) return;

    if (latLngs.length == 1) {
      _mapController.move(latLngs.first, 18);
      return;
    }

    final bounds = LatLngBounds.fromPoints(latLngs);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latLngs = _points
        .where((p) => p.isValidLatLon)
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    final start = latLngs.isNotEmpty ? latLngs.first : null;
    final end = latLngs.length >= 2 ? latLngs.last : start;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rover Route Map'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _points.isEmpty ? null : _fitToRoute,
            icon: const Icon(Icons.my_location),
            tooltip: 'Fit to route',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(0, 0),
              initialZoom: 2,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'rover_app',
              ),
              if (latLngs.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: latLngs,
                      strokeWidth: 5,
                      color: Colors.blue,
                    ),
                  ],
                ),
              if (start != null || end != null)
                MarkerLayer(
                  markers: [
                    if (start != null)
                      Marker(
                        point: start,
                        width: 48,
                        height: 48,
                        child: const _MapPin(
                          color: Colors.green,
                          label: 'START',
                        ),
                      ),
                    if (end != null)
                      Marker(
                        point: end,
                        width: 48,
                        height: 48,
                        child: const _MapPin(
                          color: Colors.red,
                          label: 'END',
                        ),
                      ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _BottomInfoCard(
              deviceId: widget.deviceId,
              pointCount: latLngs.length,
              lastFetchAt: _lastFetchAt,
              isLoading: _isLoading,
              error: _error,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomInfoCard extends StatelessWidget {
  final String deviceId;
  final int pointCount;
  final DateTime? lastFetchAt;
  final bool isLoading;
  final String? error;

  const _BottomInfoCard({
    required this.deviceId,
    required this.pointCount,
    required this.lastFetchAt,
    required this.isLoading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Device: $deviceId',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Points plotted: $pointCount'),
            if (lastFetchAt != null)
              Text(
                'Last updated: ${lastFetchAt!.hour.toString().padLeft(2, '0')}:${lastFetchAt!.minute.toString().padLeft(2, '0')}:${lastFetchAt!.second.toString().padLeft(2, '0')}',
              ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Legend: START (green), END (red), Route (blue)',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final String label;

  const _MapPin({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Icon(Icons.location_pin, color: color, size: 32),
      ],
    );
  }
}
