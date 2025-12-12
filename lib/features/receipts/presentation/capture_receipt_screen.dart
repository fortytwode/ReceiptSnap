import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/services/router_service.dart';
import '../../../common/services/services.dart';
import '../../../common/theme/app_theme.dart';
import '../providers/receipts_provider.dart';

class CaptureReceiptScreen extends ConsumerStatefulWidget {
  const CaptureReceiptScreen({super.key});

  @override
  ConsumerState<CaptureReceiptScreen> createState() => _CaptureReceiptScreenState();
}

class _CaptureReceiptScreenState extends ConsumerState<CaptureReceiptScreen> {
  File? _capturedImage;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Don't auto-start camera - let user choose
  }

  Future<void> _startCapture() async {
    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    final imageService = ref.read(imageServiceProvider);
    final (file, error, _) = await imageService.captureFromCamera();

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isCapturing = false;
        _errorMessage = error;
      });
      return;
    }

    if (file == null) {
      // User cancelled
      setState(() {
        _isCapturing = false;
      });
      return;
    }

    setState(() {
      _capturedImage = file;
      _isCapturing = false;
    });
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    final imageService = ref.read(imageServiceProvider);
    final (file, error, _) = await imageService.pickFromGallery();

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isCapturing = false;
        _errorMessage = error;
      });
      return;
    }

    if (file == null) {
      setState(() {
        _isCapturing = false;
      });
      return;
    }

    setState(() {
      _capturedImage = file;
      _isCapturing = false;
    });
  }

  Future<void> _retake() async {
    setState(() {
      _capturedImage = null;
      _errorMessage = null;
    });
  }

  Future<void> _usePhoto() async {
    if (_capturedImage == null) return;

    // Compress the image
    final imageService = ref.read(imageServiceProvider);
    final compressed = await imageService.compressImage(_capturedImage!);

    if (!mounted) return;

    // Upload and process
    final receipt = await ref
        .read(uploadReceiptProvider.notifier)
        .uploadReceipt(compressed ?? _capturedImage!);

    if (!mounted) return;

    // Refresh receipts list
    ref.read(receiptsProvider.notifier).refresh();

    if (receipt != null) {
      // Navigate to receipt detail
      context.pop();
      context.push('/receipt/${receipt.id}');
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(uploadReceiptProvider).error ?? 'Failed to upload receipt',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadReceiptProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Add Receipt'),
      ),
      body: _buildBody(uploadState),
    );
  }

  Widget _buildBody(UploadReceiptState uploadState) {
    // Loading states - uploading/processing
    if (uploadState.isUploading || uploadState.isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 24),
            Text(
              uploadState.statusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Currently capturing
    if (_isCapturing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // No image captured yet - show options
    if (_capturedImage == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.receipt_long,
                size: 80,
                color: Colors.white38,
              ),
              const SizedBox(height: 24),
              const Text(
                'Add a Receipt',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Take a photo or choose from your gallery',
                style: TextStyle(color: Colors.white60),
                textAlign: TextAlign.center,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.warning),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Camera button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startCapture,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Gallery button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose from Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Manual entry button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.pop();
                    context.push(AppRoutes.manualEntry);
                  },
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Manual Entry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'For cash expenses without a receipt',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Preview captured image
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _capturedImage!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),

        // Actions
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _retake,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Choose Again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _usePhoto,
                  icon: const Icon(Icons.check),
                  label: const Text('Use Photo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
