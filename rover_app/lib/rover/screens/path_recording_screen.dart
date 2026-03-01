import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/waypoint_model.dart';
import '../providers/path_recording_provider.dart';
import '../providers/rover_provider.dart';

class PathRecordingScreen extends StatefulWidget {
  const PathRecordingScreen({super.key});

  @override
  State<PathRecordingScreen> createState() => _PathRecordingScreenState();
}

class _PathRecordingScreenState extends State<PathRecordingScreen> {
  String? _routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Path Recording'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Consumer2<RoverProvider, PathRecordingProvider>(
        builder: (context, roverProvider, recordingProvider, _) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(recordingProvider),
                    const SizedBox(height: 20),
                    _buildRecordingControls(recordingProvider, roverProvider),
                    const SizedBox(height: 20),
                    _buildWaypointsList(recordingProvider),
                    const SizedBox(height: 20),
                    _buildSaveRouteSection(recordingProvider),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(PathRecordingProvider provider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: provider.isRecording
                ? [Colors.orange.shade400, Colors.orange.shade600]
                : [Colors.grey.shade400, Colors.grey.shade600],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  provider.isRecording
                      ? Icons.fiber_manual_record
                      : Icons.stop_circle,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.isRecording
                            ? 'Recording in Progress'
                            : 'Ready to Record',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Waypoints: ${provider.waypointCount}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingControls(
    PathRecordingProvider provider,
    RoverProvider roverProvider,
  ) {
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
                onPressed:
                    !roverProvider.isConnected ||
                        roverProvider.gpsData.isValid == false
                    ? null
                    : () => _startRecording(provider),
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Start Recording'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  disabledBackgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: !provider.isRecording
                    ? null
                    : () => _stopRecording(provider),
                icon: const Icon(Icons.stop_circle),
                label: const Text('Stop Recording'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (!roverProvider.gpsData.isValid)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '⚠️ GPS Not Active - Recording requires GPS fix',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaypointsList(PathRecordingProvider provider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Recorded Waypoints (${provider.waypointCount})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (provider.recordedWaypoints.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No waypoints recorded yet',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.recordedWaypoints.length,
              itemBuilder: (context, index) {
                final waypoint = provider.recordedWaypoints[index];
                return ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(
                    '${waypoint.latitude.toStringAsFixed(6)}, ${waypoint.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  subtitle: Text(
                    'Alt: ${waypoint.altitude.toStringAsFixed(1)}m',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.location_on, size: 16),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSaveRouteSection(PathRecordingProvider provider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save Route',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => _routeName = value,
              decoration: InputDecoration(
                hintText: 'Enter route name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    provider.recordedWaypoints.isEmpty ||
                        (_routeName?.isEmpty ?? true)
                    ? null
                    : () => _saveRoute(provider),
                icon: const Icon(Icons.save),
                label: const Text('Save as Route'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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

  void _startRecording(PathRecordingProvider provider) async {
    final success = await provider.startRecording();
    if (mounted) {
      final errorMessage = provider.lastError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '🔴 Recording started'
                : (errorMessage == null || errorMessage.isEmpty)
                    ? '❌ Failed to start recording'
                    : '❌ $errorMessage',
          ),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
    }
  }

  void _stopRecording(PathRecordingProvider provider) async {
    final success = await provider.stopRecording();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '⏹️ Recording stopped' : '❌ Failed to stop recording',
          ),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
    }
  }

  void _saveRoute(PathRecordingProvider provider) async {
    if (_routeName == null || _routeName!.isEmpty) return;

    final routeName = _routeName!;
    final success = await provider.saveRoute(routeName);
    if (mounted) {
      if (success) {
        _routeName = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Route "$routeName" saved'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to save route'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
