import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/router_service.dart';
import '../services/services.dart';
import '../theme/app_theme.dart';
import '../../features/receipts/providers/receipts_provider.dart';

/// Main scaffold with bottom navigation and FAB
class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const MainScaffold({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  bool _isProcessing = false;

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.receipts)) return 0;
    if (location.startsWith(AppRoutes.reports)) return 1;
    if (location.startsWith(AppRoutes.account)) return 2;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.receipts);
        break;
      case 1:
        context.go(AppRoutes.reports);
        break;
      case 2:
        context.go(AppRoutes.account);
        break;
    }
  }

  void _showCaptureOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Add Receipt',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              subtitle: const Text('Capture with camera'),
              onTap: () {
                Navigator.pop(context);
                _captureFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select existing photo'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _captureFromCamera() async {
    setState(() => _isProcessing = true);

    final imageService = ref.read(imageServiceProvider);
    final (file, error, needsSettings) = await imageService.captureFromCamera();

    if (!mounted) return;

    if (error != null) {
      setState(() => _isProcessing = false);
      _showPermissionError(error, needsSettings);
      return;
    }

    if (file != null) {
      await _processImage(file);
    } else {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isProcessing = true);

    final imageService = ref.read(imageServiceProvider);
    final (file, error, needsSettings) = await imageService.pickFromGallery();

    if (!mounted) return;

    if (error != null) {
      setState(() => _isProcessing = false);
      _showPermissionError(error, needsSettings);
      return;
    }

    if (file != null) {
      await _processImage(file);
    } else {
      setState(() => _isProcessing = false);
    }
  }

  void _showPermissionError(String error, bool needsSettings) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: AppColors.error,
        action: needsSettings
            ? SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              )
            : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _processImage(File file) async {
    // Compress the image
    final imageService = ref.read(imageServiceProvider);
    final compressed = await imageService.compressImage(file);

    if (!mounted) return;

    // Upload and process
    final receipt = await ref
        .read(uploadReceiptProvider.notifier)
        .uploadReceipt(compressed ?? file);

    if (!mounted) return;

    setState(() => _isProcessing = false);

    // Refresh receipts list
    ref.read(receiptsProvider.notifier).refresh();

    if (receipt != null) {
      // Navigate to receipt detail
      context.push('/receipt/${receipt.id}');
    } else {
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
    final selectedIndex = _calculateSelectedIndex(context);
    final showFab = selectedIndex == 0 || selectedIndex == 1;
    final uploadState = ref.watch(uploadReceiptProvider);

    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          // Loading overlay
          if (_isProcessing || uploadState.isUploading || uploadState.isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          uploadState.isProcessing
                              ? uploadState.statusMessage
                              : 'Processing...',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => _onItemTapped(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Receipts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
      floatingActionButton: showFab
          ? FloatingActionButton(
              onPressed: _showCaptureOptions,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
