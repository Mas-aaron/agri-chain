import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

// You might need to retrieve the available cameras list in main.dart first
// and pass one into this widget's constructor, or retrieve it within initState.
// For this example, we will retrieve it within initState as shown below.

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // Use nullable types instead of 'late'
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String? _error;
  bool _isInitializing = true;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // Update initialization to handle nullable controllers safely
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras found on this device.');
      }
      final firstCamera = cameras.first;

      final controller = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Assign the future immediately
      _initializeControllerFuture = controller.initialize();
      // Await the completion of the future
      await _initializeControllerFuture;

      if (!mounted) return;
      setState(() {
        _controller = controller; // Assign only after initialize() succeeds
        _isInitializing = false;
      });
    } on CameraException catch (e) {
      setState(() {
        _error = 'Camera error: ${e.code} ${e.description ?? ''}';
        _initializeControllerFuture = Future.error(e); // Ensure the Future fails
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize camera: $e';
        _initializeControllerFuture = Future.error(e); // Ensure the Future fails
        _isInitializing = false;
      });
    }
  }

  Future<void> _takePicture() async {
    try {
      if (_initializeControllerFuture == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera not ready yet')),
        );
        return;
      }
      await _initializeControllerFuture;

      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) {
        throw StateError('Camera not initialized');
      }
      if (controller.value.isTakingPicture) return;

      final image = await controller.takePicture();
      if (!mounted) return;

      // ── Dispose the camera safely ──────────────────────────────────────────
      // Unmount the CameraPreview first to prevent "disposed CameraController" crash
      setState(() {
        _controller = null; 
      });
      // Wait a frame so the flutter pipeline removes CameraPreview
      await Future.delayed(const Duration(milliseconds: 50)); 
      
      try {
        await controller.dispose();
      } catch (_) {}

      if (!mounted) return;
      Navigator.pop(context, File(image.path));

    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: ${e.code} ${e.description ?? ''}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    }
  }

  // Guarded use for toggling flash
  void _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      setState(() => _isFlashOn = !_isFlashOn);
      await controller.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    } catch (_) {
      // Handle potential errors silently or with a snackbar if needed
    }
  }
  
  @override
  void dispose() {
    // _controller may already be null if _takePicture() disposed it explicitly
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Picture'),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: FutureBuilder<void>(
        // The future is now nullable but assigned instantly in initState
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (_error != null) {
            // Show error message if initialization failed
            return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
          }
          
          final controller = _controller;
          
          if (snapshot.connectionState == ConnectionState.done &&
              controller != null &&
              controller.value.isInitialized) {
            // Show the preview if everything is ready
            return CameraPreview(controller);
          }
          
          // Show a loading spinner otherwise
          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePicture,
        child: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
