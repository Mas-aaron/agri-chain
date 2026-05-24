/// Farmer-facing screen for submitting and tracking a transport request.
///
/// Features:
/// - Map pin picker (flutter_map) centred on Uganda with GPS support
/// - Form fields: destination market, crop type, quantity, harvest date, notes
/// - Submit → calls LogisticsProvider.submitRequest, shows success card
/// - Inline error display for OUTSIDE_UGANDA_BOUNDS and other API errors
/// - Status chip (PENDING / AGGREGATED / ASSIGNED) with colour coding
/// - Cancel button for PENDING / AGGREGATED requests with confirmation dialog
///
/// Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:agri_chain/widgets/modern_ui.dart';
import '../providers/logistics_provider.dart';
import '../models/logistics_models.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Default map centre: geographic centre of Uganda.
const _ugandaCenter = LatLng(1.3733, 32.2903);
const _defaultZoom = 7.0;
const _pinZoom = 12.0;

/// Uganda bounding box (same as backend validation).
const _ugandaMinLat = -1.5;
const _ugandaMaxLat = 4.2;
const _ugandaMinLng = 29.5;
const _ugandaMaxLng = 35.0;

// ---------------------------------------------------------------------------
// TransportRequestScreen
// ---------------------------------------------------------------------------

/// Screen where a farmer submits a new transport request or views/cancels
/// their most recent one.
///
/// Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6
class TransportRequestScreen extends StatefulWidget {
  const TransportRequestScreen({super.key});

  @override
  State<TransportRequestScreen> createState() =>
      _TransportRequestScreenState();
}

class _TransportRequestScreenState extends State<TransportRequestScreen> {
  // ── Form ──────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _destinationCtrl = TextEditingController();
  final _cropCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _parishCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _harvestReadyAt;

  // ── Map / location ────────────────────────────────────────────────────────
  final _mapController = MapController();
  LatLng? _pickedLocation;
  bool _gpsLoading = false;
  String? _locationError;

  // ── Submission state ──────────────────────────────────────────────────────
  bool _submitting = false;
  String? _submitError;
  bool _showSuccess = false;

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _cropCtrl.dispose();
    _quantityCtrl.dispose();
    _parishCtrl.dispose();
    _notesCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  Future<void> _useGpsLocation() async {
    setState(() {
      _gpsLoading = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = 'Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationError = 'Location permission denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() =>
            _locationError = 'Location permission permanently denied. '
                'Please enable it in app settings.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final latlng = LatLng(pos.latitude, pos.longitude);
      _setPickedLocation(latlng);
      _mapController.move(latlng, _pinZoom);
    } catch (e) {
      setState(() => _locationError = 'Could not get GPS location: $e');
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  void _setPickedLocation(LatLng latlng) {
    setState(() {
      _pickedLocation = latlng;
      _locationError = null;
    });
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickHarvestDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _harvestReadyAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Select harvest ready date',
    );
    if (picked != null) {
      setState(() => _harvestReadyAt = picked);
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // Validate location first
    if (_pickedLocation == null) {
      setState(() => _locationError = 'Please pin your pickup location on the map.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _submitError = null;
      _locationError = null;
      _showSuccess = false;
    });

    final provider = context.read<LogisticsProvider>();

    await provider.submitRequest(
      pickupLat: _pickedLocation!.latitude,
      pickupLng: _pickedLocation!.longitude,
      pickupParish: _parishCtrl.text.trim(),
      destinationMarket: _destinationCtrl.text.trim(),
      cropType: _cropCtrl.text.trim(),
      quantityKg: double.parse(_quantityCtrl.text.trim()),
      harvestReadyAt: _harvestReadyAt,
      farmerNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (!mounted) return;

    final error = provider.errorMessage;
    if (error != null) {
      // Check if it's a location-related error
      if (error.toLowerCase().contains('uganda') ||
          error.toLowerCase().contains('bounds') ||
          error.toLowerCase().contains('outside')) {
        setState(() => _locationError = error);
      } else {
        setState(() => _submitError = error);
      }
    } else {
      setState(() => _showSuccess = true);
    }

    setState(() => _submitting = false);
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  Future<void> _cancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Transport Request'),
        content: const Text(
          'Are you sure you want to cancel this transport request? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Request'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final provider = context.read<LogisticsProvider>();
    await provider.cancelCurrentRequest();

    if (!mounted) return;

    if (provider.errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transport request cancelled.')),
      );
      // Reset form for a new submission
      setState(() {
        _showSuccess = false;
        _submitError = null;
        _pickedLocation = null;
        _harvestReadyAt = null;
        _destinationCtrl.clear();
        _cropCtrl.clear();
        _quantityCtrl.clear();
        _parishCtrl.clear();
        _notesCtrl.clear();
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Request'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<LogisticsProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Current request status card ──────────────────────────
                if (provider.currentRequest != null) ...[
                  _buildStatusCard(provider.currentRequest!),
                  const SizedBox(height: 16),
                ],

                // ── Success card ─────────────────────────────────────────
                if (_showSuccess && provider.currentRequest != null) ...[
                  _buildSuccessCard(provider.currentRequest!),
                  const SizedBox(height: 16),
                ],

                // ── Form (hidden after success unless user wants new) ─────
                if (!_showSuccess) ...[
                  _buildMapSection(),
                  const SizedBox(height: 16),
                  _buildFormSection(),
                ],

                // ── Global submit error ──────────────────────────────────
                if (_submitError != null) ...[
                  const SizedBox(height: 8),
                  _buildErrorBanner(_submitError!),
                ],

                // ── Provider-level error (e.g. cancel failed) ────────────
                if (provider.errorMessage != null && !_showSuccess) ...[
                  const SizedBox(height: 8),
                  _buildErrorBanner(provider.errorMessage!),
                ],

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Map section ───────────────────────────────────────────────────────────

  Widget _buildMapSection() {
    return ModernCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Pickup Location',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tap the map to pin your pickup location, or use GPS.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),

          // Map widget
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.zero),
            child: SizedBox(
              height: 240,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _ugandaCenter,
                  initialZoom: _defaultZoom,
                  onTap: (tapPosition, latlng) => _setPickedLocation(latlng),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.agrichain.app',
                  ),
                  if (_pickedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pickedLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // GPS button + coordinates display
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _gpsLoading ? null : _useGpsLocation,
                        icon: _gpsLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(
                            _gpsLoading ? 'Getting location…' : 'Use my GPS location'),
                      ),
                    ),
                  ],
                ),
                if (_pickedLocation != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Pinned: ${_pickedLocation!.latitude.toStringAsFixed(5)}, '
                    '${_pickedLocation!.longitude.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                if (_locationError != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _locationError!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.red[700],
                                  ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // Parish text field (manual entry; reverse geocoding optional)
                TextFormField(
                  controller: _parishCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pickup Parish / Village',
                    hintText: 'e.g. Nakawa, Mubende',
                    prefixIcon: Icon(Icons.place_outlined),
                    helperText: 'Type your parish or village name',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Form section ──────────────────────────────────────────────────────────

  Widget _buildFormSection() {
    return ModernCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transport Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Destination market
            TextFormField(
              controller: _destinationCtrl,
              decoration: const InputDecoration(
                labelText: 'Destination Market *',
                hintText: 'e.g. Kampala - St. Balikuddembe',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Destination market is required';
                }
                if (v.trim().length > 200) {
                  return 'Must be 200 characters or fewer';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Crop type
            TextFormField(
              controller: _cropCtrl,
              decoration: const InputDecoration(
                labelText: 'Crop Type *',
                hintText: 'e.g. Maize, Beans, Coffee',
                prefixIcon: Icon(Icons.grass_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Crop type is required';
                }
                if (v.trim().length > 100) {
                  return 'Must be 100 characters or fewer';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Quantity in kg
            TextFormField(
              controller: _quantityCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Quantity (kg) *',
                hintText: 'e.g. 500',
                prefixIcon: Icon(Icons.scale_outlined),
                suffixText: 'kg',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Quantity is required';
                }
                final qty = double.tryParse(v.trim());
                if (qty == null || qty <= 0) {
                  return 'Enter a quantity greater than 0';
                }
                if (qty > 50000) {
                  return 'Maximum quantity is 50,000 kg';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Harvest ready date (optional)
            InkWell(
              onTap: _pickHarvestDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Harvest Ready Date (optional)',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  _harvestReadyAt != null
                      ? DateFormat('dd MMM yyyy').format(_harvestReadyAt!)
                      : 'Tap to select date',
                  style: _harvestReadyAt != null
                      ? Theme.of(context).textTheme.bodyMedium
                      : Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes (optional)
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any special instructions for the driver…',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.local_shipping_outlined),
                label: Text(
                    _submitting ? 'Submitting…' : 'Submit Transport Request'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Success card ──────────────────────────────────────────────────────────

  Widget _buildSuccessCard(TransportRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Request Submitted!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('Request ID', request.id),
          const SizedBox(height: 4),
          _infoRow('Status', request.status),
          if (request.jobId != null) ...[
            const SizedBox(height: 4),
            _infoRow('Job ID', request.jobId!),
          ],
          const SizedBox(height: 12),
          Text(
            'You will be notified when your request is grouped with other '
            'farmers and a truck is assigned.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.green[700],
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _showSuccess = false;
                _pickedLocation = null;
                _harvestReadyAt = null;
                _destinationCtrl.clear();
                _cropCtrl.clear();
                _quantityCtrl.clear();
                _parishCtrl.clear();
                _notesCtrl.clear();
              }),
              icon: const Icon(Icons.add),
              label: const Text('Submit Another Request'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status card ───────────────────────────────────────────────────────────

  Widget _buildStatusCard(TransportRequest request) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: 8),
              Text(
                'Current Request',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              _statusChip(request.status),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow('Request ID', request.id),
          if (request.jobId != null) ...[
            const SizedBox(height: 4),
            _infoRow('Job ID', request.jobId!),
          ],
          const SizedBox(height: 4),
          _infoRow('Destination', request.destinationMarket),
          const SizedBox(height: 4),
          _infoRow('Crop', '${request.cropType} — ${request.quantityKg.toStringAsFixed(0)} kg'),

          // Cancel button for PENDING / AGGREGATED
          if (request.status == 'PENDING' || request.status == 'AGGREGATED') ...[
            const SizedBox(height: 14),
            Consumer<LogisticsProvider>(
              builder: (ctx, prov, _) => SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: prov.isLoading ? null : _cancelRequest,
                  icon: prov.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text(
                    'Cancel Request',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Error banner ──────────────────────────────────────────────────────────

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red[800],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case 'PENDING':
        bg = Colors.orange[100]!;
        fg = Colors.orange[800]!;
        icon = Icons.hourglass_empty;
        break;
      case 'AGGREGATED':
        bg = Colors.blue[100]!;
        fg = Colors.blue[800]!;
        icon = Icons.group_outlined;
        break;
      case 'ASSIGNED':
        bg = Colors.green[100]!;
        fg = Colors.green[800]!;
        icon = Icons.local_shipping;
        break;
      case 'COMPLETED':
        bg = Colors.teal[100]!;
        fg = Colors.teal[800]!;
        icon = Icons.check_circle_outline;
        break;
      case 'CANCELLED':
        bg = Colors.grey[200]!;
        fg = Colors.grey[700]!;
        icon = Icons.cancel_outlined;
        break;
      default:
        bg = Colors.grey[200]!;
        fg = Colors.grey[700]!;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
