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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: isLoading ? null : onCameraPressed,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Open Camera'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isLoading ? null : onGalleryPressed,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choose from Gallery'),
        ),
        if (isLoading) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ]
      ],
    );
  }
}
