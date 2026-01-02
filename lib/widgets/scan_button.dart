import 'package:flutter/material.dart';

class ScanButton extends StatelessWidget {
  final VoidCallback onCameraPressed;
  final VoidCallback onGalleryPressed;
  final bool isLoading;

  const ScanButton({
    super.key,
    required this.onCameraPressed,
    required this.onGalleryPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: isLoading ? null : onCameraPressed,
          icon: const Icon(Icons.photo_camera),
          label: const Text('Take Photo'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isLoading ? null : onGalleryPressed,
          icon: const Icon(Icons.photo_library),
          label: const Text('Pick from Gallery'),
        ),
        if (isLoading) ...[
          const SizedBox(height: 16),
          const CircularProgressIndicator(),
        ]
      ],
    );
  }
}
