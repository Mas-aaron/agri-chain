import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rover_model.dart';
import '../providers/rover_provider.dart';

class GPSDataScreen extends StatefulWidget {
  const GPSDataScreen({super.key});

  @override
  State<GPSDataScreen> createState() => _GPSDataScreenState();
}

class _GPSDataScreenState extends State<GPSDataScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RoverProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Data'),
        elevation: 0,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGPSStatusCard(provider.gpsData),
                const SizedBox(height: 20),
                if (provider.gpsData.isValid) ...[
                  _buildLocationCard(provider.gpsData),
                  const SizedBox(height: 20),
                  _buildMovementCard(provider.gpsData),
                  const SizedBox(height: 20),
                  _buildSatelliteCard(provider.gpsData),
                ] else
                  _buildNoGPSCard(),
                const SizedBox(height: 20),
                _buildRefreshButton(provider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGPSStatusCard(GPSData gps) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: gps.isValid
                ? [Colors.green.shade400, Colors.green.shade600]
                : [Colors.red.shade400, Colors.red.shade600],
          ),
        ),
        child: Row(
          children: [
            Icon(
              gps.isValid ? Icons.gps_fixed : Icons.gps_off,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gps.isValid ? 'GPS Signal Active' : 'No GPS Signal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gps.isValid
                        ? 'Location data available'
                        : 'Searching for satellites...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
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

  Widget _buildLocationCard(GPSData gps) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.orange.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDataRow('Latitude', '${gps.latitude.toStringAsFixed(8)}°'),
            const SizedBox(height: 12),
            _buildDataRow('Longitude', '${gps.longitude.toStringAsFixed(8)}°'),
            const SizedBox(height: 12),
            _buildDataRow('Altitude', '${gps.altitude.toStringAsFixed(2)} meters'),
            const SizedBox(height: 12),
            _buildDataRow('Coordinates', gps.coordinatesString),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementCard(GPSData gps) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_run,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Movement',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDataRow('Speed', gps.speedKmh),
            const SizedBox(height: 12),
            _buildDataRow('Course', '${gps.course.toStringAsFixed(1)}° (${gps.courseString})'),
            const SizedBox(height: 12),
            _buildDataRow('Last Update',
                '${gps.timestamp.hour.toString().padLeft(2, '0')}:${gps.timestamp.minute.toString().padLeft(2, '0')}:${gps.timestamp.second.toString().padLeft(2, '0')}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSatelliteCard(GPSData gps) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.satellite,
                  color: Colors.purple.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Satellite Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDataRow('Satellites', '${gps.satellites}'),
            const SizedBox(height: 12),
            _buildDataRow('HDOP', '${gps.hdop.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            _buildDataRow('Signal Quality',
                gps.hdop < 1 ? 'Excellent' :
                gps.hdop < 2 ? 'Good' :
                gps.hdop < 5 ? 'Fair' : 'Poor'),
          ],
        ),
      ),
    );
  }

  Widget _buildNoGPSCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.location_off,
              color: Colors.grey.shade400,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'GPS Data Unavailable',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The rover is currently unable to acquire GPS signals. This may be due to:\n\n'
              '• Poor satellite visibility\n'
              '• GPS module not connected\n'
              '• Rover not outdoors\n'
              '• GPS module not powered',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildRefreshButton(RoverProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await provider.fetchGPSData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('GPS data refreshed'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh GPS Data'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}