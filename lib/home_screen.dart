import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agri_chain/services/tflite_service.dart';
import 'package:agri_chain/screens/camera_screen.dart';
import 'package:agri_chain/screens/results_screen.dart';
import 'package:agri_chain/widgets/disease_card.dart';
import 'package:agri_chain/widgets/scan_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TFLiteService _tfliteService;
  bool _isLoading = false;

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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsScreen(
              imageFile: imageFile,
              predictions: result['predictions'],
              inferenceTime: result['inferenceTime'],
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 32),
              
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
              
              const Spacer(),
              
              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
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

