import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agri_chain/services/tflite_service.dart';
import 'package:agri_chain/providers/alerts_provider.dart';
import 'package:agri_chain/providers/fields_provider.dart';
import 'package:agri_chain/providers/scan_provider.dart';
import 'package:agri_chain/screens/camera_screen.dart';
import 'package:agri_chain/screens/results_screen.dart';
import 'package:agri_chain/widgets/disease_card.dart';
import 'package:agri_chain/widgets/scan_button.dart';

class HomeScreen extends StatefulWidget {
  final bool embedded;
  const HomeScreen({super.key, this.embedded = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TFLiteService _tfliteService;
  bool _isLoading = false;

  String _formatConfidence(dynamic confidence) {
    final asDouble = confidence is num ? confidence.toDouble() : double.tryParse('$confidence');
    if (asDouble == null) return '—';
    final pct = asDouble <= 1.0 ? (asDouble * 100.0) : asDouble;
    return '${pct.toStringAsFixed(1)}%';
  }

  @override
  void initState() {
    super.initState();
    _tfliteService = Provider.of<TFLiteService>(context, listen: false);
  }

  Future<void> _pickImageFromGallery() async {
    setState(() => _isLoading = true);
    
    try {
      final imagePicker = ImagePicker();
      final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        await _processImage(File(pickedFile.path));
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _takePhoto() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );
    
    if (result != null && result is File) {
      await _processImage(result);
    }
  }

  Future<void> _processImage(File imageFile) async {
    setState(() => _isLoading = true);
    
    try {
      final result = await _tfliteService.predictImage(imageFile);
      
      if (result['success'] == true) {
        final selectedFieldId = context.read<ScanProvider>().selectedFieldId;
        try {
          final predictions = (result['predictions'] as List).cast<Map<String, dynamic>>();
          if (predictions.isNotEmpty) {
            final top = predictions.first;
            final label = (top['label'] as String?) ?? 'Unknown';
            final confidence = top['confidence'];
            final lower = label.toLowerCase();
            final topPct = (confidence is num)
                ? (confidence.toDouble() <= 1.0 ? confidence.toDouble() * 100.0 : confidence.toDouble())
                : (double.tryParse('$confidence') ?? 0.0);

            final severity = lower.contains('healthy')
                ? 'Low'
                : (topPct >= 90.0 ? 'Critical' : (topPct >= 70.0 ? 'High' : 'Medium'));

            final top3 = predictions.take(3).map((p) {
              final pLabel = (p['label'] as String?) ?? 'Unknown';
              return {
                'label': pLabel,
                'confidence': p['confidence'],
                'confidenceText': _formatConfidence(p['confidence']),
              };
            }).toList();

            await context.read<AlertsProvider>().addAlert(
                  AlertItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: 'AI Health Alert: $label',
                    message: 'Diagnosis result: $label (confidence: ${_formatConfidence(confidence)}).',
                    category: 'Health',
                    severity: severity,
                    createdAt: DateTime.now(),
                    fieldId: selectedFieldId,
                    imagePath: imageFile.path,
                    extra: {
                      'top': top,
                      'top3': top3,
                    },
                  ),
                );
          }
        } catch (_) {
          // Ignore alert creation failures
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsScreen(
              imageFile: imageFile,
              predictions: result['predictions'],
              inferenceTime: result['inferenceTime'],
              selectedFieldId: selectedFieldId,
            ),
          ),
        );
      } else {
        _showError('Prediction failed: ${result['error']}');
      }
    } catch (e) {
      _showError('Error processing image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = context.watch<FieldsProvider>().fields;
    final selectedFieldId = context.watch<ScanProvider>().selectedFieldId;
    final selectedExists = selectedFieldId == null ? true : fields.any((f) => f.id == selectedFieldId);
    final effectiveSelectedFieldId = selectedExists ? selectedFieldId : null;

    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 32),

            FutureBuilder<void>(
              future: Future.wait([
                context.read<FieldsProvider>().ensureLoaded(),
                context.read<ScanProvider>().ensureLoaded(),
              ]),
              builder: (context, snapshot) {
                if (!selectedExists) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!context.mounted) return;
                    context.read<ScanProvider>().setSelectedFieldId(null);
                  });
                }

                final items = [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No field selected'),
                  ),
                  ...fields.map(
                    (f) => DropdownMenuItem<String?>(
                      value: f.id,
                      child: Text(f.name),
                    ),
                  ),
                ];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.map_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: effectiveSelectedFieldId,
                            items: items,
                            decoration: const InputDecoration(
                              labelText: 'Selected field (optional)',
                            ),
                            onChanged: (value) => context.read<ScanProvider>().setSelectedFieldId(value),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Scan Button
            Center(
              child: ScanButton(
                onCameraPressed: _takePhoto,
                onGalleryPressed: _pickImageFromGallery,
                isLoading: _isLoading,
              ),
            ),

            const SizedBox(height: 40),

            // Disease Info
            _buildDiseaseInfo(),

            const SizedBox(height: 24),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );

    if (widget.embedded) return content;
    return Scaffold(body: content);
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.agriculture,
                color: Colors.green,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '🌽 Maize Disease\nDetector',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Detect diseases in maize leaves using AI. Scan leaves for instant diagnosis and treatment recommendations.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDiseaseInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Common Maize Diseases',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            DiseaseCard(
              diseaseName: 'Northern Leaf Blight',
              severity: 'High',
              color: Colors.orange,
            ),
            DiseaseCard(
              diseaseName: 'Common Rust',
              severity: 'Medium',
              color: Colors.red,
            ),
            DiseaseCard(
              diseaseName: 'Gray Leaf Spot',
              severity: 'High',
              color: Colors.blue,
            ),
            DiseaseCard(
              diseaseName: 'Healthy',
              severity: 'None',
              color: Colors.green,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Powered by TensorFlow Lite',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Offline AI • Fast • Accurate',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () {
                // Show about dialog
                showAboutDialog(
                  context: context,
                  applicationName: 'Maize Disease Detector',
                  applicationVersion: '1.0.0',
                  children: [
                    const SizedBox(height: 16),
                    const Text('AI-powered disease detection for maize farmers.'),
                  ],
                );
              },
              icon: Icon(
                Icons.info_outline,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

