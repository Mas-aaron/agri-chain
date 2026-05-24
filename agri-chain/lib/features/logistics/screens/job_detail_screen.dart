/// Job Detail Screen for the Logistics Aggregation feature.
///
/// Displays the full route map, stop list, route statistics, and job
/// acceptance controls for an [AggregatedJob].
///
/// Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/logistics_models.dart';
import '../providers/logistics_provider.dart';
import '../services/logistics_api_service.dart';

/// Detail screen for a single [AggregatedJob].
///
/// Shows:
/// - A job info header (destination, origin, farmer count, total kg, status)
/// - A route map with stop markers and connecting polyline (flutter_map)
/// - Route statistics (total distance, estimated hours)
/// - A scrollable stop list
/// - An "Accept Job" button when the job is OPEN
class JobDetailScreen extends StatefulWidget {
  final AggregatedJob job;

  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  /// Local copy of the job so we can update it after a successful accept.
  late AggregatedJob _job;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
  }

  // ── Status chip colour ────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return Colors.green;
      case 'ASSIGNED':
        return Colors.blue;
      case 'IN_TRANSIT':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.grey;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ── Accept Job bottom sheet ───────────────────────────────────────────────

  void _showAcceptSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _AcceptJobSheet(
        job: _job,
        onAccepted: (updatedJob) {
          setState(() => _job = updatedJob);
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final route = _job.route;
    final stops = route?.orderedStops ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_job.destinationMarket),
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          // ── Job info header ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _JobInfoHeader(job: _job, statusColor: _statusColor),
          ),

          // ── Route map ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _RouteMapSection(job: _job, stops: stops),
          ),

          // ── Route stats ─────────────────────────────────────────────────
          if (route != null)
            SliverToBoxAdapter(
              child: _RouteStatsRow(route: route),
            ),

          // ── Stop list header ─────────────────────────────────────────────
          if (stops.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Pickup Stops (${stops.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),

          // ── Stop list ────────────────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _StopListTile(stop: stops[index]),
              childCount: stops.length,
            ),
          ),

          // Bottom padding so FAB doesn't overlap last item
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),

      // ── Accept button (only when OPEN) ───────────────────────────────────
      floatingActionButton: _job.status.toUpperCase() == 'OPEN'
          ? FloatingActionButton.extended(
              onPressed: () => _showAcceptSheet(context),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Accept Job'),
              backgroundColor: Colors.green,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ── Job Info Header ──────────────────────────────────────────────────────────

class _JobInfoHeader extends StatelessWidget {
  final AggregatedJob job;
  final Color Function(String) statusColor;

  const _JobInfoHeader({required this.job, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row: destination + status chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.destinationMarket,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'From ${job.originRegion}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    job.status,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: statusColor(job.status),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            // Stats row
            Row(
              children: [
                _InfoChip(
                  icon: Icons.people,
                  label: '${job.farmerCount} farmers',
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: Icons.scale,
                  label: '${job.totalQuantityKg.toStringAsFixed(0)} kg',
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 13, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Route Map Section ────────────────────────────────────────────────────────

class _RouteMapSection extends StatelessWidget {
  final AggregatedJob job;
  final List<RouteStop> stops;

  const _RouteMapSection({required this.job, required this.stops});

  @override
  Widget build(BuildContext context) {
    if (job.route == null) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Route not yet computed',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Build LatLng lists for markers and polyline
    final points = stops
        .map((s) => LatLng(s.lat, s.lng))
        .toList(growable: false);

    // Compute map centre: use centroid if available, else average of stops
    final LatLng centre;
    if (job.centroidLat != null && job.centroidLng != null) {
      centre = LatLng(job.centroidLat!, job.centroidLng!);
    } else if (points.isNotEmpty) {
      final avgLat = points.map((p) => p.latitude).reduce((a, b) => a + b) /
          points.length;
      final avgLng = points.map((p) => p.longitude).reduce((a, b) => a + b) /
          points.length;
      centre = LatLng(avgLat, avgLng);
    } else {
      // Default to Uganda centre
      centre = const LatLng(1.3733, 32.2903);
    }

    // Build markers — numbered badges for each stop
    final markers = stops.map((stop) {
      return Marker(
        point: LatLng(stop.lat, stop.lng),
        width: 36,
        height: 36,
        child: _StopMarker(stopOrder: stop.stopOrder),
      );
    }).toList();

    return Container(
      height: 280,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: centre,
          initialZoom: stops.length > 20 ? 9.0 : 11.0,
          minZoom: 5,
          maxZoom: 18,
        ),
        children: [
          // OpenStreetMap tile layer
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.agrichain.app',
          ),
          // Polyline connecting stops in order
          if (points.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 3.0,
                  color: Colors.blue.shade700,
                ),
              ],
            ),
          // Markers
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}

/// Numbered circular badge used as a map marker for each stop.
class _StopMarker extends StatelessWidget {
  final int stopOrder;

  const _StopMarker({required this.stopOrder});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          '$stopOrder',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ── Route Stats Row ──────────────────────────────────────────────────────────

class _RouteStatsRow extends StatelessWidget {
  final RouteResult route;

  const _RouteStatsRow({required this.route});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.route,
              label: 'Total Distance',
              value: '${route.totalDistanceKm.toStringAsFixed(1)} km',
              color: Colors.teal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.access_time,
              label: 'Est. Duration',
              value: '${route.estimatedHours.toStringAsFixed(1)} hrs',
              color: Colors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stop List Tile ───────────────────────────────────────────────────────────

class _StopListTile extends StatelessWidget {
  final RouteStop stop;

  const _StopListTile({required this.stop});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stop order badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${stop.stopOrder}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Stop details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.farmerName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stop.parish,
                    style: TextStyle(
                        color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stop.quantityKg.toStringAsFixed(0)} kg',
                    style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stop.lat.toStringAsFixed(5)}, ${stop.lng.toStringAsFixed(5)}',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Accept Job Bottom Sheet ──────────────────────────────────────────────────

/// Bottom sheet form for accepting a job.
///
/// Fields:
/// - Truck capacity (kg) — required number field
/// - Driver phone — required text field
/// - Planned pickup date — optional date picker
class _AcceptJobSheet extends StatefulWidget {
  final AggregatedJob job;
  final void Function(AggregatedJob updatedJob) onAccepted;

  const _AcceptJobSheet({required this.job, required this.onAccepted});

  @override
  State<_AcceptJobSheet> createState() => _AcceptJobSheetState();
}

class _AcceptJobSheetState extends State<_AcceptJobSheet> {
  final _formKey = GlobalKey<FormState>();
  final _capacityController = TextEditingController();
  final _phoneController = TextEditingController();

  DateTime? _plannedPickupDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _capacityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _plannedPickupDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final provider =
        Provider.of<LogisticsProvider>(context, listen: false);
    final jobId = widget.job.id;
    final truckCapacity = double.parse(_capacityController.text.trim());
    final driverPhone = _phoneController.text.trim();

    try {
      // Use the provider's acceptJob which updates internal state too.
      // We also need the returned job — call the service directly so we
      // can capture the updated job object for the parent screen.
      final updatedJob = await provider.service.acceptJob(
        jobId: jobId,
        companyId: 'self', // company_id resolved server-side from auth token
        truckCapacityKg: truckCapacity,
        driverPhone: driverPhone,
        plannedPickupAt: _plannedPickupDate,
      );

      if (!mounted) return;
      widget.onAccepted(updatedJob);
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job accepted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } on JobAlreadyAssignedException {
      setState(() {
        _errorMessage =
            'This job was already accepted by another company.';
        _isSubmitting = false;
      });
    } on CapacityInsufficientException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isSubmitting = false;
      });
    } on LogisticsApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _plannedPickupDate != null
        ? DateFormat('dd MMM yyyy').format(_plannedPickupDate!)
        : 'Select date (optional)';

    return Padding(
      // Shift sheet up when keyboard appears
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sheet handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Accept Job',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total load: ${widget.job.totalQuantityKg.toStringAsFixed(0)} kg',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),

                // Truck capacity field
                TextFormField(
                  controller: _capacityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Truck capacity (kg) *',
                    hintText: 'e.g. 10000',
                    prefixIcon: Icon(Icons.local_shipping),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Truck capacity is required';
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Driver phone field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Driver phone *',
                    hintText: 'e.g. +256700000000',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Driver phone is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Planned pickup date picker
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(dateLabel),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 20),

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Confirm Acceptance',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
