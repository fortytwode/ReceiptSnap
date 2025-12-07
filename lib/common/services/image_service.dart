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
  Future<(bool, bool)> requestCameraPermission() async {
    var status = await Permission.camera.status;

    // If permanently denied, user needs to go to Settings
    if (status.isPermanentlyDenied) {
      return (false, true); // (granted, needsSettings)
    }

    // Request permission
    status = await Permission.camera.request();

    if (status.isPermanentlyDenied) {
      return (false, true);
    }

    return (status.isGranted, false);
  }

  /// Request photo library permission
  Future<(bool, bool)> requestPhotoLibraryPermission() async {
    var status = await Permission.photos.status;

    // If permanently denied, user needs to go to Settings
    if (status.isPermanentlyDenied) {
      return (false, true); // (granted, needsSettings)
    }

    // Request permission
    status = await Permission.photos.request();

    if (status.isPermanentlyDenied) {
      return (false, true);
    }

    return (status.isGranted || status.isLimited, false);
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
  /// Returns a tuple of (File?, errorMessage?, needsSettings?)
  Future<(File?, String?, bool)> captureFromCamera() async {
    try {
      final (hasPermission, needsSettings) = await requestCameraPermission();
      if (!hasPermission) {
        if (needsSettings) {
          return (null, 'Camera access denied. Tap to open Settings.', true);
        }
        return (null, 'Camera permission denied.', false);
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );

      if (image == null) return (null, null, false); // User cancelled

      return (File(image.path), null, false);
    } catch (e) {
      debugPrint('Error capturing image: $e');
      // Check for specific errors
      if (e.toString().contains('camera_access_denied')) {
        return (null, 'Camera access denied. Tap to open Settings.', true);
      }
      return (null, 'Could not access camera: ${e.toString()}', false);
    }
  }

  /// Pick image from gallery
  /// Returns a tuple of (File?, errorMessage?, needsSettings?)
  Future<(File?, String?, bool)> pickFromGallery() async {
    try {
      final (hasPermission, needsSettings) = await requestPhotoLibraryPermission();
      if (!hasPermission) {
        if (needsSettings) {
          return (null, 'Photo access denied. Tap to open Settings.', true);
        }
        return (null, 'Photo library permission denied.', false);
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) return (null, null, false); // User cancelled

      return (File(image.path), null, false);
    } catch (e) {
      debugPrint('Error picking image: $e');
      return (null, 'Could not access photo library: ${e.toString()}', false);
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
  Future<(File?, String?, bool)> captureAndCompress() async {
    final (file, error, needsSettings) = await captureFromCamera();
    if (file == null) return (null, error, needsSettings);

    final compressed = await compressImage(file);
    return (compressed, null, false);
  }

  /// Pick and compress image in one call
  Future<(File?, String?, bool)> pickAndCompress() async {
    final (file, error, needsSettings) = await pickFromGallery();
    if (file == null) return (null, error, needsSettings);

    final compressed = await compressImage(file);
    return (compressed, null, false);
  }
}

/// Provider for ImageService
final imageServiceProvider = Provider<ImageService>((ref) {
  return ImageService();
});
