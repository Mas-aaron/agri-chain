import 'package:flutter/material.dart' hide Route;
import 'package:provider/provider.dart';
import '../models/waypoint_model.dart';
import '../providers/path_recording_provider.dart';
import 'autonomous_navigation_screen.dart';

class RouteManagementScreen extends StatefulWidget {
  const RouteManagementScreen({super.key});

  @override
  State<RouteManagementScreen> createState() => _RouteManagementScreenState();
}

class _RouteManagementScreenState extends State<RouteManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Management'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Consumer<PathRecordingProvider>(
        builder: (context, recordingProvider, _) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.teal.shade50, Colors.white],
              ),
            ),
            child: SafeArea(
              child: recordingProvider.savedRoutes.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: recordingProvider.savedRoutes.length,
                      itemBuilder: (context, index) {
                        final route = recordingProvider.savedRoutes[index];
                        return _buildRouteCard(
                          context,
                          route,
                          recordingProvider,
                        );
                      },
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Routes Saved',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Record and save a path to see it here',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(
    BuildContext context,
    Route route,
    PathRecordingProvider recordingProvider,
  ) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.teal.shade300, Colors.teal.shade500],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.route, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          route.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRouteStats(route),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRouteDetails(context, route),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _navigateToRoute(context, route, recordingProvider),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Navigate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStats(Route route) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '${route.waypointCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Waypoints',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                '${(route.getTotalDistance() / 1000).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'km',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                route.createdAt.day.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Saved',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRouteDetails(BuildContext context, Route route) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(route.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Waypoints', route.waypointCount.toString()),
              _buildDetailRow(
                'Total Distance',
                '${(route.getTotalDistance() / 1000).toStringAsFixed(2)} km',
              ),
              _buildDetailRow(
                'Created',
                '${route.createdAt.day}/${route.createdAt.month}/${route.createdAt.year}',
              ),
              const SizedBox(height: 16),
              const Text(
                'Waypoint List:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: route.waypointCount,
                  itemBuilder: (context, index) {
                    final wp = route.waypoints[index];
                    return Text(
                      '${index + 1}. ${wp.latitude.toStringAsFixed(6)}, ${wp.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 11),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _navigateToRoute(
    BuildContext context,
    Route route,
    PathRecordingProvider recordingProvider,
  ) {
    recordingProvider.loadRoute(route);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AutonomousNavigationScreen(route: route),
      ),
    );
  }
}
