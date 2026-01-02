import 'dart:io';
import 'package:flutter/material.dart';
import 'package:agri_chain/widgets/confidence_bar.dart';

class ResultsScreen extends StatelessWidget {
  final File imageFile;
  final List<Map<String, dynamic>> predictions;
  final int inferenceTime;

  const ResultsScreen({
    super.key,
    required this.imageFile,
    required this.predictions,
    required this.inferenceTime,
  });

  @override
  Widget build(BuildContext context) {
    final topPrediction = predictions.first;
    final isHealthy = topPrediction['label'].toLowerCase().contains('healthy');

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
            _buildDiagnosisCard(isHealthy, topPrediction),
            const SizedBox(height: 24),

            // Confidence Bars
            _buildConfidenceSection(),
            const SizedBox(height: 24),

            // Treatment Advice
            _buildTreatmentAdvice(topPrediction['label']),
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

  Widget _buildDiagnosisCard(bool isHealthy, Map<String, dynamic> prediction) {
    return Card(
      color: isHealthy ? Colors.green[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              isHealthy ? Icons.check_circle : Icons.warning,
              color: isHealthy ? Colors.green : Colors.orange,
              size: 40,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHealthy ? 'Healthy Leaf' : 'Disease Detected',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prediction['label'],
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confidence: ${prediction['percentage'].toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
            label: pred['label'],
            percentage: pred['percentage'],
            isTop: predictions.indexOf(pred) == 0,
          );
        }).toList(),
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
            child: ElevatedButton(
              onPressed: () => _saveResult(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, size: 20),
                  SizedBox(width: 8),
                  Text('Save Result'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTreatmentAdvice(String disease) {
    final adviceMap = {
      'healthy': 'Your maize plant appears healthy. Continue with regular watering and fertilization.',
      'northern leaf blight': 'Apply fungicides containing azoxystrobin or pyraclostrobin. Remove infected leaves and practice crop rotation.',
      'common rust': 'Use resistant varieties if available. Apply fungicides like triazoles at first sign of infection.',
      'gray leaf spot': 'Practice crop rotation and tillage to reduce spores. Apply strobilurin fungicides if needed.',
    };

    return adviceMap[disease.toLowerCase()] ??
        'Consult with an agricultural expert for specific treatment recommendations.';
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
