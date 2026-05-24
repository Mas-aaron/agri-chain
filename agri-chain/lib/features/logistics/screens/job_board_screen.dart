/// Job Board Screen — logistics company view of open aggregated transport jobs.
///
/// Displays a filterable, pull-to-refresh list of [AggregatedJob] cards.
/// Tapping a card navigates to [JobDetailScreen].
///
/// Requirements: 12.1, 12.2, 12.3, 12.4, 12.5

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/logistics_models.dart';
import '../providers/logistics_provider.dart';
import 'job_detail_screen.dart';

// ---------------------------------------------------------------------------
// JobBoardScreen
// ---------------------------------------------------------------------------

/// Logistics company screen for browsing aggregated transport jobs.
///
/// On first load it fetches jobs with `status = OPEN`. Filter controls allow
/// narrowing by status, destination market, and minimum quantity.
///
/// Requirements: 12.1, 12.2, 12.3, 12.4, 12.5
class JobBoardScreen extends StatefulWidget {
  const JobBoardScreen({super.key});

  @override
  State<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends State<JobBoardScreen> {
  // ── Filter state ──────────────────────────────────────────────────────────

  /// Currently selected status filter. `null` means "ALL".
  String? _selectedStatus = 'OPEN';

  /// Destination market text filter (empty = no filter).
  final TextEditingController _marketController = TextEditingController();

  /// Minimum quantity filter (0 = no filter).
  double _minQuantityKg = 0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Load jobs after the first frame so the provider is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadJobs();
    });
  }

  @override
  void dispose() {
    _marketController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  /// Calls [LogisticsProvider.loadJobs] with the current filter values.
  ///
  /// Requirements: 12.2, 12.3
  Future<void> _loadJobs() async {
    final provider = context.read<LogisticsProvider>();
    await provider.loadJobs(
      status: _selectedStatus,
      market: _marketController.text.trim().isEmpty
          ? null
          : _marketController.text.trim(),
      minQuantityKg: _minQuantityKg > 0 ? _minQuantityKg : null,
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  /// Navigates to [JobDetailScreen] for the given [job].
  ///
  /// Requirements: 12.4
  void _openJobDetail(AggregatedJob job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(job: job),
      ),
    );
  }

  // ── Filter sheet ──────────────────────────────────────────────────────────

  /// Opens a bottom sheet with filter controls.
  ///
  /// Requirements: 12.3
  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return _FilterSheet(
          selectedStatus: _selectedStatus,
          marketController: _marketController,
          minQuantityKg: _minQuantityKg,
          onApply: ({
            required String? status,
            required double minQuantityKg,
          }) {
            setState(() {
              _selectedStatus = status;
              _minQuantityKg = minQuantityKg;
            });
            Navigator.pop(sheetContext);
            _loadJobs();
          },
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter jobs',
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _ActiveFilterBar(
            selectedStatus: _selectedStatus,
            market: _marketController.text.trim(),
            minQuantityKg: _minQuantityKg,
          ),
          Expanded(
            child: Consumer<LogisticsProvider>(
              builder: (context, provider, _) {
                // Loading state — show spinner only on initial load (empty list).
                if (provider.isLoading && provider.jobs.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Error state.
                if (provider.errorMessage != null && provider.jobs.isEmpty) {
                  return _ErrorView(
                    message: provider.errorMessage!,
                    onRetry: _loadJobs,
                  );
                }

                // Empty state.
                if (provider.jobs.isEmpty) {
                  return _EmptyView(onRefresh: _loadJobs);
                }

                // Job list with pull-to-refresh.
                // Requirements: 12.5
                return RefreshIndicator(
                  onRefresh: _loadJobs,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: provider.jobs.length,
                    itemBuilder: (context, index) {
                      final job = provider.jobs[index];
                      return _JobCard(
                        job: job,
                        onTap: () => _openJobDetail(job),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ActiveFilterBar
// ---------------------------------------------------------------------------

/// A compact row showing the currently active filters.
class _ActiveFilterBar extends StatelessWidget {
  const _ActiveFilterBar({
    required this.selectedStatus,
    required this.market,
    required this.minQuantityKg,
  });

  final String? selectedStatus;
  final String market;
  final double minQuantityKg;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (selectedStatus != null) {
      chips.add(_filterChip('Status: $selectedStatus'));
    }
    if (market.isNotEmpty) {
      chips.add(_filterChip('Market: $market'));
    }
    if (minQuantityKg > 0) {
      chips.add(_filterChip(
          'Min: ${NumberFormat('#,##0').format(minQuantityKg)} kg'));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      ),
    );
  }

  Widget _filterChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _JobCard
// ---------------------------------------------------------------------------

/// Card widget displaying summary information for a single [AggregatedJob].
///
/// Requirements: 12.1
class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});

  final AggregatedJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberFmt = NumberFormat('#,##0');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row: destination + status chip ──────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      job.destinationMarket,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: job.status),
                ],
              ),
              const SizedBox(height: 6),

              // ── Origin region ──────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    job.originRegion,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Stats row: farmers + quantity ──────────────────────────
              Row(
                children: [
                  _StatBadge(
                    icon: Icons.people_outline,
                    label:
                        '${numberFmt.format(job.farmerCount)} farmer${job.farmerCount == 1 ? '' : 's'}',
                  ),
                  const SizedBox(width: 12),
                  _StatBadge(
                    icon: Icons.scale_outlined,
                    label: '${numberFmt.format(job.totalQuantityKg)} kg',
                  ),
                ],
              ),

              // ── Route summary (if available) ───────────────────────────
              if (job.route != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatBadge(
                      icon: Icons.route_outlined,
                      label:
                          '${job.route!.totalDistanceKm.toStringAsFixed(1)} km',
                    ),
                    const SizedBox(width: 12),
                    _StatBadge(
                      icon: Icons.access_time_outlined,
                      label:
                          '${job.route!.estimatedHours.toStringAsFixed(1)} h',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StatusChip
// ---------------------------------------------------------------------------

/// Coloured chip showing the job status.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  (Color bg, Color fg) _colors(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return (Colors.green.shade100, Colors.green.shade800);
      case 'ASSIGNED':
        return (Colors.orange.shade100, Colors.orange.shade800);
      case 'IN_TRANSIT':
        return (Colors.blue.shade100, Colors.blue.shade800);
      case 'COMPLETED':
        return (Colors.grey.shade200, Colors.grey.shade700);
      case 'CANCELLED':
        return (Colors.red.shade100, Colors.red.shade700);
      default:
        return (Colors.grey.shade200, Colors.grey.shade700);
    }
  }
}

// ---------------------------------------------------------------------------
// _StatBadge
// ---------------------------------------------------------------------------

/// Small icon + label pair used inside job cards.
class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ErrorView
// ---------------------------------------------------------------------------

/// Full-screen error message with a retry button.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  bool get _isOffline =>
      message.contains('backend') ||
      message.contains('server') ||
      message.contains('connection') ||
      message.contains('Connection') ||
      message.contains('TimeoutException');

  @override
  Widget build(BuildContext context) {
    final isOffline = _isOffline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOffline ? Icons.cloud_off_outlined : Icons.error_outline,
              size: 64,
              color: isOffline ? Colors.orange.shade300 : Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isOffline ? 'Backend not reachable' : 'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isOffline
                  ? 'The logistics server is not running yet.\n\nThe Go backend needs to be started before jobs can be loaded. Tap Retry once the server is up.'
                  : message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptyView
// ---------------------------------------------------------------------------

/// Friendly empty-state message shown when no jobs match the filters.
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No jobs found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'There are no transport jobs matching your filters right now.\n'
              'Pull down to refresh or adjust the filters.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FilterSheet
// ---------------------------------------------------------------------------

/// Bottom sheet with filter controls for status, market, and minimum quantity.
///
/// Requirements: 12.3
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.selectedStatus,
    required this.marketController,
    required this.minQuantityKg,
    required this.onApply,
  });

  final String? selectedStatus;
  final TextEditingController marketController;
  final double minQuantityKg;
  final void Function({
    required String? status,
    required double minQuantityKg,
  }) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  static const _statusOptions = [
    null, // ALL
    'OPEN',
    'ASSIGNED',
    'IN_TRANSIT',
    'COMPLETED',
  ];

  late String? _status;
  late double _minKg;

  @override
  void initState() {
    super.initState();
    _status = widget.selectedStatus;
    _minKg = widget.minQuantityKg;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sheet handle ───────────────────────────────────────────────
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

          Text('Filter Jobs', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),

          // ── Status dropdown ────────────────────────────────────────────
          Text('Status', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            value: _status,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: _statusOptions.map((s) {
              return DropdownMenuItem<String?>(
                value: s,
                child: Text(s ?? 'ALL'),
              );
            }).toList(),
            onChanged: (value) => setState(() => _status = value),
          ),
          const SizedBox(height: 16),

          // ── Destination market text field ──────────────────────────────
          Text('Destination Market', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: widget.marketController,
            decoration: const InputDecoration(
              hintText: 'e.g. Kampala - St. Balikuddembe',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),

          // ── Minimum quantity slider ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Minimum Quantity', style: theme.textTheme.labelLarge),
              Text(
                _minKg > 0
                    ? '${NumberFormat('#,##0').format(_minKg)} kg'
                    : 'Any',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ),
          Slider(
            value: _minKg,
            min: 0,
            max: 10000,
            divisions: 100,
            label: _minKg > 0
                ? '${NumberFormat('#,##0').format(_minKg)} kg'
                : 'Any',
            onChanged: (value) => setState(() => _minKg = value),
          ),
          const SizedBox(height: 20),

          // ── Apply button ───────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onApply(
                status: _status,
                minQuantityKg: _minKg,
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}
