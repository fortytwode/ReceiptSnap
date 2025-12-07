import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling image capture and processing
class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request photo library permission
  Future<bool> requestPhotoLibraryPermission() async {
    final status = await Permission.photos.request();
    return status.isGranted || status.isLimited;
  }

  /// Check if camera permission is granted
  Future<bool> hasCameraPermission() async {
    return await Permission.camera.isGranted;
  }

  /// Check if photo library permission is granted
  Future<bool> hasPhotoLibraryPermission() async {
    final status = await Permission.photos.status;
    return status.isGranted || status.isLimited;
  }

  /// Capture image from camera
  /// Returns a tuple of (File?, errorMessage?)
  Future<(File?, String?)> captureFromCamera() async {
    try {
      final hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        return (null, 'Camera permission denied. Please enable in Settings.');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );

      if (image == null) return (null, null); // User cancelled

      return (File(image.path), null);
    } catch (e) {
      debugPrint('Error capturing image: $e');
      // Check for specific errors
      if (e.toString().contains('camera_access_denied')) {
        return (null, 'Camera access denied. Please enable in Settings.');
      }
      return (null, 'Could not access camera: ${e.toString()}');
    }
  }

  /// Pick image from gallery
  /// Returns a tuple of (File?, errorMessage?)
  Future<(File?, String?)> pickFromGallery() async {
    try {
      final hasPermission = await requestPhotoLibraryPermission();
      if (!hasPermission) {
        return (null, 'Photo library permission denied. Please enable in Settings.');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) return (null, null); // User cancelled

      return (File(image.path), null);
    } catch (e) {
      debugPrint('Error picking image: $e');
      return (null, 'Could not access photo library: ${e.toString()}');
    }
  }

  /// Compress image for upload
  Future<File?> compressImage(File file) async {
    try {
      final filePath = file.absolute.path;
      final lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
      final targetPath =
          '${filePath.substring(0, lastIndex)}_compressed.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 80,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result == null) return file;

      return File(result.path);
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return file;
    }
  }

  /// Capture and compress image in one call
  Future<(File?, String?)> captureAndCompress() async {
    final (file, error) = await captureFromCamera();
    if (file == null) return (null, error);

    final compressed = await compressImage(file);
    return (compressed, null);
  }

  /// Pick and compress image in one call
  Future<(File?, String?)> pickAndCompress() async {
    final (file, error) = await pickFromGallery();
    if (file == null) return (null, error);

    final compressed = await compressImage(file);
    return (compressed, null);
  }
}

/// Provider for ImageService
final imageServiceProvider = Provider<ImageService>((ref) {
  return ImageService();
});
