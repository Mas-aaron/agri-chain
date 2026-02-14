import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/providers/alerts_provider.dart';
import 'package:agri_chain/widgets/confidence_bar.dart';
import 'package:agri_chain/services/recommendation_service.dart';

class ResultsScreen extends StatelessWidget {
  final File imageFile;
  final List<Map<String, dynamic>> predictions;
  final int inferenceTime;
  final String? selectedFieldId;

  const ResultsScreen({
    super.key,
    required this.imageFile,
    required this.predictions,
    required this.inferenceTime,
    this.selectedFieldId,
  });

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatPercent(dynamic value) {
    final v = _asDouble(value);
    return '${v.toStringAsFixed(1)}%';
  }

  String _normalizeLabel(String label) {
    return label.replaceAll('_', ' ').trim().toLowerCase();
  }

  String _displayLabel(String label) {
    return label.replaceAll('_', ' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    final topPrediction = predictions.first;
    final rec = RecommendationService.recommendForLabel((topPrediction['label'] as String?) ?? '');
    final isHealthy = rec.isHealthy;
    final isNonMaize = rec.isNonMaize;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        actions: [
          IconButton(
            onPressed: () => _shareResults(context),
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview
            _buildImagePreview(),
            const SizedBox(height: 24),

            // Diagnosis Card
            _buildDiagnosisCard(isHealthy, isNonMaize, topPrediction),
            const SizedBox(height: 24),

            // Confidence Bars
            _buildConfidenceSection(),
            const SizedBox(height: 24),

            // Treatment Advice
            _buildTreatmentAdvice(topPrediction['label']),
            const SizedBox(height: 24),

            // Recommendations
            _buildRecommendations(context, rec),
            const SizedBox(height: 24),

            // Stats
            _buildStatsSection(),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionButtons(context),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(imageFile, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildDiagnosisCard(
    bool isHealthy,
    bool isNonMaize,
    Map<String, dynamic> prediction,
  ) {
    final percentage = _asDouble(prediction['percentage']);
    final label = (prediction['label'] as String?) ?? '';
    final display = _displayLabel(label);

    final header = isNonMaize
        ? 'Scan not recognized'
        : (isHealthy ? 'Healthy Leaf' : 'Disease detected');

    final icon = isNonMaize
        ? Icons.info_outline
        : (isHealthy ? Icons.check_circle : Icons.warning);

    final iconColor = isNonMaize
        ? Colors.orange
        : (isHealthy ? Colors.green : Colors.orange);

    final cardColor = isNonMaize
        ? Colors.orange[50]
        : (isHealthy ? Colors.green[50] : Colors.orange[50]);

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 40,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    header,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    display.isEmpty ? 'Unknown' : display,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (isNonMaize) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Try scanning a clear maize leaf image in good lighting.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    'Confidence: ${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confidence Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...predictions.map((pred) {
          return ConfidenceBar(
            label: _displayLabel((pred['label'] as String?) ?? 'Unknown'),
            percentage: _asDouble(pred['percentage']),
            isTop: predictions.indexOf(pred) == 0,
          );
        }),
      ],
    );
  }

  Widget _buildTreatmentAdvice(String disease) {
    final advice = _getTreatmentAdvice(disease);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.medical_services, color: Colors.green),
                SizedBox(width: 12),
                Text(
                  'Treatment Advice',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              advice,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          icon: Icons.timer,
          label: 'Inference Time',
          value: '${inferenceTime}ms',
        ),
        _buildStatItem(
          icon: Icons.analytics,
          label: 'Model Version',
          value: '1.0',
        ),
        _buildStatItem(
          icon: Icons.device_hub,
          label: 'Platform',
          value: 'TFLite',
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.green),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Scan Another'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => _createAlert(context),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_active_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('Create alert'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createAlert(BuildContext context) async {
    try {
      final top = predictions.first;
      final label = (top['label'] as String?) ?? 'Unknown';
      final confidence = top['percentage'] ?? top['confidence'];

      final lower = _normalizeLabel(label);
      final pct = _asDouble(confidence);
      final isNonMaize = RecommendationService.isNonMaizeLabel(lower);
      final severity = (lower.contains('healthy') || isNonMaize)
          ? 'Low'
          : (pct >= 90.0 ? 'Critical' : (pct >= 70.0 ? 'High' : 'Medium'));

      final top3 = predictions.take(3).map((p) {
        final pLabel = (p['label'] as String?) ?? 'Unknown';
        return {
          'label': pLabel,
          'confidence': p['percentage'] ?? p['confidence'],
          'confidenceText': _formatPercent(p['percentage'] ?? p['confidence']),
        };
      }).toList();

      await context.read<AlertsProvider>().addAlert(
            AlertItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: isNonMaize
                  ? 'Manual Scan: Not a maize leaf'
                  : 'Manual Alert: ${_displayLabel(label)}',
              message: isNonMaize
                  ? 'Result: Not a maize leaf. Please scan a clear maize leaf image.'
                  : 'Result: ${_displayLabel(label)} (confidence: ${_formatPercent(confidence)}).',
              category: 'Health',
              severity: severity,
              createdAt: DateTime.now(),
              fieldId: selectedFieldId,
              imagePath: imageFile.path,
              extra: {
                'top': top,
                'top3': top3,
                'source': 'manual',
              },
            ),
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert created.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create alert: $e')),
        );
      }
    }
  }

  String _getTreatmentAdvice(String disease) {
    final key = RecommendationService.normalizeLabel(disease);

    if (RecommendationService.isNonMaizeLabel(key)) {
      return 'This image does not look like a maize leaf. Please scan a clear maize leaf image in good lighting and try again.';
    }
    if (key.contains('healthy')) {
      return 'Your maize plant appears healthy. Continue with regular monitoring, watering, and fertilization.';
    }
    if (key.contains('maize streak') || (key.contains('streak') && key.contains('virus')) || key.contains('msv')) {
      return 'Maize streak virus is viral and cannot be cured with fungicides. Remove severely infected plants early, control leafhoppers (vectors) using approved insect control methods, keep fields weed-free, and plant resistant/tolerant varieties where available.';
    }
    if (key.contains('blight')) {
      return 'Remove heavily infected leaves. Avoid overhead irrigation. Consider an approved fungicide and rotate crops next season.';
    }
    if (key.contains('common rust') || key.contains('rust')) {
      return 'Remove infected leaves where possible. Use resistant varieties and consider a triazole fungicide at early infection.';
    }
    if (key.contains('gray leaf spot') || key.contains('leaf spot')) {
      return 'Reduce residue (tillage/rotation). Improve airflow with proper spacing. Consider a strobilurin fungicide if severe.';
    }
    return 'Consult with an agricultural expert for specific treatment recommendations.';
  }

  Widget _buildRecommendations(BuildContext context, RecommendationResult rec) {
    final scheme = Theme.of(context).colorScheme;

    if (rec.isNonMaize) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.info_outline, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No recommendations available for this image. Please scan a clear maize leaf.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (rec.isHealthy) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Leaf looks healthy. No chemicals recommended. Continue monitoring and good agronomic practices.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (rec.normalizedKey.contains('maize streak') ||
        (rec.normalizedKey.contains('streak') && rec.normalizedKey.contains('virus')) ||
        rec.normalizedKey.contains('msv')) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Maize streak virus is viral. No fungicides are recommended. Focus on resistant varieties, vector (leafhopper) control, and removing heavily infected plants early.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_pharmacy_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Credited agrochemicals & approved sellers',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Choose products from approved sellers to reduce counterfeit risk.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (rec.chemicals.isEmpty)
              Text(
                'No recommendations available yet for “${rec.normalizedKey}”.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...rec.chemicals.map((chem) {
                final sellers = rec.sellersByChemicalId[chem.id] ?? const <ApprovedSeller>[];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.primary.withOpacity(0.12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                chem.name,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: scheme.primary.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified, size: 16, color: scheme.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    chem.isCredited ? 'Credited' : 'Unverified',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Active ingredient: ${chem.activeIngredient}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          chem.usage,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Approved sellers',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        if (sellers.isEmpty)
                          Text('No sellers linked yet.', style: Theme.of(context).textTheme.bodySmall)
                        else
                          ...sellers.map((s) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.storefront_outlined, size: 18, color: scheme.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${s.location} • ${s.phone}${s.licenseId == null ? '' : ' • License: ${s.licenseId}'}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () => _callPhone(s.phone),
                                              icon: const Icon(Icons.call_outlined, size: 18),
                                              label: const Text('Call'),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () => _smsPhone(s.phone),
                                              icon: const Icon(Icons.sms_outlined, size: 18),
                                              label: const Text('SMS'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final normalized = phone.replaceAll(' ', '');
    final uri = Uri(scheme: 'tel', path: normalized);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _smsPhone(String phone) async {
    final normalized = phone.replaceAll(' ', '');
    final uri = Uri(scheme: 'sms', path: normalized);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _shareResults(BuildContext context) {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing feature coming soon!')),
    );
  }

  void _saveResult(BuildContext context) {
    // Implement save functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Result saved to history'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
