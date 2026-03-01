import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agri_chain/services/mindspore_service.dart';
import 'package:agri_chain/services/recommendation_service.dart';
import 'package:agri_chain/providers/alerts_provider.dart';
import 'package:agri_chain/providers/fields_provider.dart';
import 'package:agri_chain/providers/scan_provider.dart';
import 'package:agri_chain/screens/camera_screen.dart';
import 'package:agri_chain/screens/results_screen.dart';
import 'package:agri_chain/widgets/disease_card.dart';
import 'package:agri_chain/widgets/scan_button.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

class HomeScreen extends StatefulWidget {
  final bool embedded;
  const HomeScreen({super.key, this.embedded = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MindSporeService _msService = MindSporeService();
  bool _isLoading = false;
  CropModel _cropModel = CropModel.maize;

  String _formatConfidence(dynamic confidence) {
    final asDouble = confidence is num ? confidence.toDouble() : double.tryParse('$confidence');
    if (asDouble == null) return '—';
    final pct = asDouble <= 1.0 ? (asDouble * 100.0) : asDouble;
    return '${pct.toStringAsFixed(1)}%';
  }

  String _displayLabel(String label) {
    return label.replaceAll('_', ' ').trim();
  }

  @override
  void initState() {
    super.initState();
    // Model initializes on first scan — pre-warming here caused startup jank
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
      // Initialize MindSpore Lite with the correct local .ms model asset
      final modelType = _cropModel == CropModel.maize ? 'maize' : 'coffee';
      await _msService.initialize(modelType: modelType);

      // Run offline inference — no network, no downloads
      final result = await _msService.predictImage(imageFile);

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

            final normalizedKey = label.replaceAll('_', ' ').trim().toLowerCase();
            final isNonMaize = _cropModel == CropModel.maize
                ? RecommendationService.isNonMaizeLabel(normalizedKey)
                : false;

            final severity = (lower.contains('healthy') || isNonMaize)
                ? 'Low'
                : (topPct >= 90.0
                    ? 'Critical'
                    : (topPct >= 70.0 ? 'High' : 'Medium'));

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
                    title: isNonMaize
                        ? 'AI Scan: Not a maize leaf'
                        : 'AI Health Alert: ${_displayLabel(label)}',
                    message: isNonMaize
                        ? 'Result: Not a maize leaf. Please scan a clear maize leaf image (good lighting, in focus).'
                        : 'Diagnosis result: ${_displayLabel(label)} (confidence: ${_formatConfidence(confidence)}).',
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

        final predictionsList = (result['predictions'] as List?)?.cast<Map<dynamic, dynamic>>() ?? [];
        final typedPredictions = predictionsList.map((e) => e.cast<String, dynamic>()).toList();

        if (typedPredictions.isEmpty) {
          _showError('No predictions returned from the model.');
          setState(() => _isLoading = false);
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsScreen(
              imageFile: imageFile,
              predictions: typedPredictions,
              inferenceTime: result['inferenceTime'] ?? 0,
              selectedFieldId: selectedFieldId,
              cropModel: _cropModel,
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
                            initialValue: effectiveSelectedFieldId,
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

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.eco_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<CropModel>(
                        initialValue: _cropModel,
                        decoration: const InputDecoration(
                          labelText: 'Crop model',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: CropModel.maize,
                            child: Text('Maize'),
                          ),
                          DropdownMenuItem(
                            value: CropModel.coffee,
                            child: Text('Coffee'),
                          ),
                        ],
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _cropModel = value;
                                });
                              },
                      ),
                    ),
                  ],
                ),
              ),
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
    return const ImageHeroCard(
      assetPath: 'assets/images/corn-field-sunset.jpg',
      title: 'AI Leaf Scanner',
      subtitle: 'Detect maize diseases instantly and get treatment advice.',
    );
  }

  Widget _buildDiseaseInfo() {
    final scheme = Theme.of(context).colorScheme;

    final isCoffee = _cropModel == CropModel.coffee;
    final headerTitle = isCoffee ? 'Common coffee diseases' : 'Common maize diseases';
    final headerSubtitle = isCoffee
        ? 'Know what to look for on coffee leaves before symptoms spread.'
        : 'Know what to look for before symptoms spread.';

    final cards = isCoffee
        ? <Widget>[
            DiseaseCard(
              diseaseName: 'Coffee Leaf Rust',
              severity: 'High',
              color: Colors.orange,
              icon: Icons.local_fire_department_outlined,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scan a leaf photo to get an exact diagnosis and treatment advice.')),
              ),
            ),
            DiseaseCard(
              diseaseName: 'Coffee Berry Disease',
              severity: 'High',
              color: Colors.red,
              icon: Icons.bug_report_outlined,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scan a leaf photo to get an exact diagnosis and treatment advice.')),
              ),
            ),
            DiseaseCard(
              diseaseName: 'Cercospora Leaf Spot',
              severity: 'Medium',
              color: Colors.blue,
              icon: Icons.grain_outlined,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scan a leaf photo to get an exact diagnosis and treatment advice.')),
              ),
            ),
            DiseaseCard(
              diseaseName: 'Healthy',
              severity: 'None',
              color: scheme.primary,
              icon: Icons.check_circle_outline,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Great! Keep scouting weekly and scan if you see new spots.')),
              ),
            ),
          ]
        : <Widget>[
            DiseaseCard(
              diseaseName: 'Northern Leaf Blight',
              severity: 'High',
              color: Colors.orange,
              icon: Icons.local_fire_department_outlined,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scan a leaf photo to get an exact diagnosis and treatment advice.')),
              ),
            ),
            DiseaseCard(
              diseaseName: 'Common Rust',
              severity: 'Medium',
              color: Colors.red,
              icon: Icons.bug_report_outlined,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scan a leaf photo to get an exact diagnosis and treatment advice.')),
              ),
            ),
            DiseaseCard(
              diseaseName: 'Gray Leaf Spot',
              severity: 'High',
              color: Colors.blue,
              icon: Icons.grain_outlined,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scan a leaf photo to get an exact diagnosis and treatment advice.')),
              ),
            ),
            DiseaseCard(
              diseaseName: 'Healthy',
              severity: 'None',
              color: scheme.primary,
              icon: Icons.check_circle_outline,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Great! Keep scouting weekly and scan if you see new spots.')),
              ),
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: headerTitle,
          subtitle: headerSubtitle,
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: cards,
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
                  'Powered by MindSpore Lite',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Offline AI • On-Device • Fast',
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

