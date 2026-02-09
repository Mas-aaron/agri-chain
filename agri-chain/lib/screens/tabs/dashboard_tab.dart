import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agri_chain/providers/alerts_provider.dart';
import 'package:agri_chain/providers/fields_provider.dart';
import 'package:agri_chain/screens/blockchain/blockchain_hub_screen.dart';
import 'package:agri_chain/screens/yield_prediction_screen.dart';
import 'package:agri_chain/services/weather_api_service.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

Color _alpha(Color c, double opacity) {
  final a = (opacity * 255).round().clamp(0, 255);
  return c.withAlpha(a);
}

class _WeatherFeatureCard extends StatefulWidget {
  const _WeatherFeatureCard();

  @override
  State<_WeatherFeatureCard> createState() => _WeatherFeatureCardState();
}

class _WeatherFeatureCardState extends State<_WeatherFeatureCard> {
  static const double _fallbackLat = -1.286389;
  static const double _fallbackLon = 36.817223;
  static const String _gpsLatKey = 'agri_chain_weather_lat_v1';
  static const String _gpsLonKey = 'agri_chain_weather_lon_v1';
  static const Duration _gpsTimeout = Duration(seconds: 6);

  final WeatherApiService _api = WeatherApiService();
  late Future<WeatherSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({double lat, double lon})> _resolveCoordinates(String rawLocation) async {
    final saved = await _readSavedCoordinates();
    if (saved != null) return saved;

    final parsed = _tryParseLatLon(rawLocation);
    if (parsed != null) return parsed;
    return (lat: _fallbackLat, lon: _fallbackLon);
  }

  Future<({double lat, double lon})?> _readSavedCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_gpsLatKey);
    final lon = prefs.getDouble(_gpsLonKey);
    if (lat == null || lon == null) return null;
    return (lat: lat, lon: lon);
  }

  Future<void> _saveCoordinates({required double lat, required double lon}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_gpsLatKey, lat);
    await prefs.setDouble(_gpsLonKey, lon);
  }

  ({double lat, double lon})? _tryParseLatLon(String input) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) return null;
    final parts = cleaned.split(',');
    if (parts.length != 2) return null;

    final lat = double.tryParse(parts[0].trim());
    final lon = double.tryParse(parts[1].trim());
    if (lat == null || lon == null) return null;
    return (lat: lat, lon: lon);
  }

  Future<WeatherSnapshot> _load() async {
    final fields = context.read<FieldsProvider>().fields;
    final rawLocation = fields.isEmpty ? '' : fields.first.location;

    final gps = await _tryGetDeviceCoordinatesIfPermitted();
    if (gps != null) {
      await _saveCoordinates(lat: gps.lat, lon: gps.lon);
      return _api.fetchCurrent(latitude: gps.lat, longitude: gps.lon);
    }

    final coords = await _resolveCoordinates(rawLocation);
    return _api.fetchCurrent(latitude: coords.lat, longitude: coords.lon);
  }

  Future<({double lat, double lon})?> _tryGetDeviceCoordinatesIfPermitted() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    final permission = await Geolocator.checkPermission();
    final allowed = permission == LocationPermission.whileInUse || permission == LocationPermission.always;
    if (!allowed) return null;

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return (lat: last.latitude, lon: last.longitude);
    } catch (_) {
      // ignore
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(_gpsTimeout);
      return (lat: pos.latitude, lon: pos.longitude);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _useDeviceGps() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable location services to use GPS.')),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied.')),
      );
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission permanently denied. Enable it in Settings.')),
      );
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
    await _saveCoordinates(lat: pos.latitude, lon: pos.longitude);

    if (!mounted) return;
    setState(() {
      _future = _api.fetchCurrent(latitude: pos.latitude, longitude: pos.longitude);
    });
  }

  String _describeCode(int code) {
    if (code == 0) return 'Clear sky';
    if (code == 1 || code == 2) return 'Partly cloudy';
    if (code == 3) return 'Cloudy';
    if (code == 45 || code == 48) return 'Fog';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Weather';
  }

  IconData _iconForCode(int code) {
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code == 1 || code == 2) return Icons.cloud_outlined;
    if (code == 3) return Icons.cloud;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 51 && code <= 57) return Icons.grain_outlined;
    if (code >= 61 && code <= 67) return Icons.umbrella_outlined;
    if (code >= 71 && code <= 77) return Icons.ac_unit;
    if (code >= 80 && code <= 82) return Icons.water_drop_outlined;
    if (code >= 95) return Icons.thunderstorm_outlined;
    return Icons.cloud_outlined;
  }

  Color _accentForCode(BuildContext context, int code) {
    final scheme = Theme.of(context).colorScheme;
    if (code == 0) return const Color(0xFFF59E0B);
    if (code == 1 || code == 2) return scheme.primary;
    if (code == 3) return scheme.primary;
    if (code == 45 || code == 48) return scheme.onSurfaceVariant;
    if (code >= 51 && code <= 57) return const Color(0xFF06B6D4);
    if (code >= 61 && code <= 67) return const Color(0xFF3B82F6);
    if (code >= 71 && code <= 77) return const Color(0xFF60A5FA);
    if (code >= 80 && code <= 82) return const Color(0xFF3B82F6);
    if (code >= 95) return const Color(0xFF8B5CF6);
    return scheme.primary;
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openActionsSheet({required bool isLoading, required bool hasError, required bool hasData}) async {
    if (isLoading) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('Use device GPS'),
                subtitle: const Text('Get weather for your current location'),
                onTap: () {
                  Navigator.pop(context);
                  _useDeviceGps();
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Refresh weather'),
                subtitle: Text(hasError || !hasData ? 'Retry fetching weather' : 'Fetch the latest update'),
                onTap: () {
                  Navigator.pop(context);
                  _retry();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;
        final data = snapshot.data;

        String subtitle;
        Widget trailing;
        IconData icon;
        Color accent;

        if (isLoading) {
          subtitle = 'Loading…';
          trailing = const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2));
          icon = Icons.cloud_outlined;
          accent = Theme.of(context).colorScheme.primary;
        } else if (hasError || data == null) {
          subtitle = 'Tap to retry';
          trailing = const Icon(Icons.refresh);
          icon = Icons.cloud_off_outlined;
          accent = Theme.of(context).colorScheme.onSurfaceVariant;
        } else {
          final temp = data.temperatureC.toStringAsFixed(1);
          final wind = data.windSpeed.toStringAsFixed(0);
          subtitle = '${_describeCode(data.weatherCode)} • Wind ${wind}km/h';
          icon = _iconForCode(data.weatherCode);
          accent = _accentForCode(context, data.weatherCode);
          trailing = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$temp°C',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
            ),
          );
        }

        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            _openActionsSheet(
              isLoading: isLoading,
              hasError: hasError,
              hasData: data != null,
            );
          },
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: accent, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weather',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  trailing,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  String? _fieldName(BuildContext context, String? fieldId) {
    if (fieldId == null || fieldId.isEmpty) return null;
    final fields = context.read<FieldsProvider>().fields;
    final match = fields.where((f) => f.id == fieldId);
    if (match.isEmpty) return null;
    return match.first.name;
  }

  IconData _severityIcon(String severity) {
    final s = severity.toLowerCase();
    if (s.contains('critical')) return Icons.error;
    if (s.contains('high')) return Icons.warning;
    return Icons.info_outline;
  }

  Color? _severityColor(BuildContext context, String severity) {
    final s = severity.toLowerCase();
    if (s.contains('critical')) return Colors.red;
    if (s.contains('high')) return Colors.orange;
    if (s.contains('medium')) return Theme.of(context).colorScheme.tertiary;
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: Future.wait([
        context.read<FieldsProvider>().ensureLoaded(),
        context.read<AlertsProvider>().ensureLoaded(),
      ]),
      builder: (context, snapshot) {
        final fieldsCount = context.watch<FieldsProvider>().fields.length;
        final alertsCount = context.watch<AlertsProvider>().alerts.length;
        final alerts = context.watch<AlertsProvider>().alerts;

        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return RefreshIndicator(
          onRefresh: () async {
            final fieldsProvider = context.read<FieldsProvider>();
            final alertsProvider = context.read<AlertsProvider>();
            await fieldsProvider.ensureLoaded();
            await alertsProvider.ensureLoaded();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ImageHeroCard(
                assetPath: 'assets/images/beautiful-shot-cornfield-with-blue-sky.jpg',
                title: 'Welcome back',
                subtitle: isLoading ? 'Loading your farm summary…' : 'Monitor fields, predict yield, and sell safely.',
              ),
              const SizedBox(height: 16),

              const SectionHeader(
                title: 'Quick actions',
                subtitle: 'Most used tools for today',
              ),
              const SizedBox(height: 12),
              _QuickActionsRow(),
              const SizedBox(height: 10),
              const _SecondaryActionsRow(),
              const SizedBox(height: 18),

              const SectionHeader(
                title: 'Overview',
                subtitle: 'Your farm status at a glance',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: MiniStatTile(
                      label: 'Active fields',
                      value: '$fieldsCount',
                      icon: Icons.map_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MiniStatTile(
                      label: 'Pending alerts',
                      value: '$alertsCount',
                      icon: Icons.notifications_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              const SectionHeader(
                title: 'Tools',
                subtitle: 'Use AI + marketplace features',
              ),
              const SizedBox(height: 12),
              FeatureCard(
                icon: Icons.auto_graph_outlined,
                title: 'Yield forecast',
                subtitle: 'Predict maize yield using the online model',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const YieldPredictionScreen()),
                ),
              ),
              const SizedBox(height: 10),
              FeatureCard(
                icon: Icons.storefront_outlined,
                title: 'Agri‑Market',
                subtitle: 'Create, buy, and track Future Harvest Contracts',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BlockchainHubScreen()),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(child: _WeatherFeatureCard()),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: FeatureCard(
                      icon: Icons.show_chart,
                      title: 'Market prices',
                      subtitle: 'Coming soon',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _RecentActivityCard(
                alerts: alerts.take(6).toList(),
                formatTime: _formatTime,
                fieldName: (fieldId) => _fieldName(context, fieldId),
                severityIcon: _severityIcon,
                severityColor: (severity) => _severityColor(context, severity),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use the bottom bar to open Scan.')),
              );
            },
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Scan'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // Navigation is handled by the bottom nav; keep this as a gentle hint.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use the bottom bar to open Fields.')),
              );
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('Fields'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const YieldPredictionScreen()),
              );
            },
            icon: const Icon(Icons.auto_graph_outlined),
            label: const Text('Yield'),
          ),
        ),
      ],
    );
  }
}

class _SecondaryActionsRow extends StatelessWidget {
  const _SecondaryActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockchainHubScreen()),
              );
            },
            icon: const Icon(Icons.hub_outlined),
            label: const Text('Blockchain'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use the bottom bar to open Alerts.')),
              );
            },
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('Alerts'),
          ),
        ),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final List<AlertItem> alerts;
  final String Function(DateTime) formatTime;
  final String? Function(String?) fieldName;
  final IconData Function(String) severityIcon;
  final Color? Function(String) severityColor;

  const _RecentActivityCard({
    required this.alerts,
    required this.formatTime,
    required this.fieldName,
    required this.severityIcon,
    required this.severityColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: SectionHeader(
                    title: 'Recent activity',
                    subtitle: 'Latest alerts and actions',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (alerts.isEmpty)
              Text(
                'No recent activity yet. Scan a leaf to generate an alert.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...alerts.map((a) {
                final color = severityColor(a.severity);
                final fName = fieldName(a.fieldId);
                final subtitle = [
                  if (fName != null) fName,
                  a.isResolved ? 'Resolved' : 'Open',
                  formatTime(a.createdAt),
                ].join(' • ');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      context.read<AlertsProvider>().markRead(a.id, isRead: true);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => _DashboardAlertDetailScreen(alertId: a.id)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _alpha(color ?? Theme.of(context).colorScheme.primary, 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              severityIcon(a.severity),
                              color: color ?? Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        a.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: a.isRead
                                            ? Theme.of(context).textTheme.bodyMedium
                                            : Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _alpha(color ?? Theme.of(context).colorScheme.primary, 0.10),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        a.severity,
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: color ?? Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _DashboardAlertDetailScreen extends StatelessWidget {
  final String alertId;

  const _DashboardAlertDetailScreen({required this.alertId});

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final alert = context.watch<AlertsProvider>().alerts.firstWhere((a) => a.id == alertId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            icon: Icon(alert.isResolved ? Icons.check_circle : Icons.check_circle_outline),
            onPressed: () => context.read<AlertsProvider>().markResolved(alert.id, isResolved: !alert.isResolved),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(alert.message),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Category: ${alert.category}')),
                      Chip(label: Text('Severity: ${alert.severity}')),
                      Chip(label: Text('Time: ${_formatTime(alert.createdAt)}')),
                      Chip(label: Text(alert.isResolved ? 'Resolved' : 'Open')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
