import 'package:flutter/material.dart' hide Route;
import 'package:provider/provider.dart';
import '../models/waypoint_model.dart' as waypoint_model;
import '../providers/path_recording_provider.dart';
import '../providers/rover_provider.dart';

class AutonomousNavigationScreen extends StatefulWidget {
  final waypoint_model.Route route;

  const AutonomousNavigationScreen({super.key, required this.route});

  @override
  State<AutonomousNavigationScreen> createState() =>
      _AutonomousNavigationScreenState();
}

class _AutonomousNavigationScreenState
    extends State<AutonomousNavigationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Autonomous Navigation'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Consumer2<RoverProvider, PathRecordingProvider>(
        builder: (context, roverProvider, navigationProvider, _) {
          final status = navigationProvider.navigationStatus;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.purple.shade50, Colors.white],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRouteInfo(widget.route),
                    const SizedBox(height: 20),
                    _buildNavigationStatus(status),
                    const SizedBox(height: 20),
                    _buildProgressCard(status),
                    const SizedBox(height: 20),
                    _buildNavigationControls(navigationProvider, roverProvider),
                    const SizedBox(height: 20),
                    _buildWaypointsList(widget.route, status),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRouteInfo(waypoint_model.Route route) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.purple.shade400, Colors.purple.shade600],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              route.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Waypoints: ${route.waypointCount}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Distance: ${(route.getTotalDistance() / 1000).toStringAsFixed(2)} km',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.route, color: Colors.white, size: 32),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationStatus(waypoint_model.NavigationStatus status) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: status.isNavigating
                ? [Colors.green.shade300, Colors.green.shade500]
                : [Colors.grey.shade300, Colors.grey.shade500],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status.isNavigating ? '🗺️ NAVIGATING' : '⏸️ IDLE',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            if (status.isNavigating) ...[
              Text(
                'Current Waypoint: ${status.currentWaypoint} / ${status.totalWaypoints}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              if (status.distanceToTarget != null)
                Text(
                  'Distance to Target: ${status.distanceToTarget!.toStringAsFixed(1)}m',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              if (status.bearing != null)
                Text(
                  'Bearing: ${status.bearing!.toStringAsFixed(1)}°',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              if (status.targetReached == true)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade700,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '🎯 Target Reached - Moving to next waypoint',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(waypoint_model.NavigationStatus status) {
    final progress = status.progressPercentage / 100;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Navigation Progress',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.purple.shade400,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${status.progressPercentage.toStringAsFixed(1)}% Complete',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationControls(
    PathRecordingProvider navigationProvider,
    RoverProvider roverProvider,
  ) {
    final isNavigating = navigationProvider.navigationStatus.isNavigating;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: !roverProvider.isConnected || isNavigating
                    ? null
                    : () => _startNavigation(navigationProvider),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Navigation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: !isNavigating
                    ? null
                    : () => _stopNavigation(navigationProvider),
                icon: const Icon(Icons.stop),
                label: const Text('Stop Navigation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaypointsList(
    waypoint_model.Route route,
    waypoint_model.NavigationStatus status,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Route Waypoints (${route.waypointCount})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: route.waypointCount,
            itemBuilder: (context, index) {
              final waypoint = route.waypoints[index];
              final isCurrent = index == status.currentWaypoint;
              final isCompleted = index < status.currentWaypoint;

              return Container(
                color: isCurrent
                    ? Colors.blue.shade50
                    : isCompleted
                    ? Colors.green.shade50
                    : Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrent
                        ? Colors.blue
                        : isCompleted
                        ? Colors.green
                        : Colors.grey,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    '${waypoint.latitude.toStringAsFixed(6)}, ${waypoint.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    'Alt: ${waypoint.altitude.toStringAsFixed(1)}m',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.location_on, color: Colors.blue)
                      : isCompleted
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _startNavigation(PathRecordingProvider navigationProvider) async {
    final success = await navigationProvider.startNavigation();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '🗺️ Navigation started' : '❌ Failed to start navigation',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _stopNavigation(PathRecordingProvider navigationProvider) async {
    final success = await navigationProvider.stopNavigation();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '⏹️ Navigation stopped' : '❌ Failed to stop navigation',
          ),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
    }
  }
}
