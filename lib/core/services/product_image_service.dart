import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service for picking, compressing, and managing offline product images.
/// Applies high-efficiency 512x512 resolution limits and 70% JPEG quality
/// so that photos only occupy ~25 KB to 50 KB on the store owner's phone.
class ProductImageService {
  static final ImagePicker _picker = ImagePicker();

  /// Picks an image from camera or gallery, compresses it, and saves it in app documents.
  /// Returns the absolute persistent file path, or null if cancelled.
  static Future<String?> pickAndCompressImage({
    required ImageSource source,
  }) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70, // 70% quality compresses phone camera images down to ~30KB
      );

      if (picked == null) return null;

      if (kIsWeb) {
        // In web preview, return the blob/memory url
        return picked.path;
      }

      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory imagesDir = Directory(p.join(appDir.path, 'product_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final String fileName = 'prod_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String destinationPath = p.join(imagesDir.path, fileName);

      final File pickedFile = File(picked.path);
      final File savedFile = await pickedFile.copy(destinationPath);

      debugPrint('ProductImageService: Image saved and compressed to ${savedFile.path} (${await savedFile.length()} bytes)');
      return savedFile.path;
    } catch (e) {
      debugPrint('ProductImageService error picking image: $e');
      return null;
    }
  }

  /// Deletes a previously stored image file to prevent orphaned files from taking space.
  static Future<void> deleteImageFile(String? path) async {
    if (path == null || path.isEmpty || kIsWeb) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('ProductImageService: Deleted previous image file $path');
      }
    } catch (e) {
      debugPrint('ProductImageService: Could not delete image $path: $e');
    }
  }

  /// Returns the formatted file size string (e.g., "34 KB") for UI transparency.
  static Future<String?> getFormattedFileSize(String? path) async {
    if (path == null || path.isEmpty || kIsWeb) return null;
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.length();
        if (bytes < 1024) return '$bytes B';
        final kb = (bytes / 1024).toStringAsFixed(1);
        return '$kb KB';
      }
    } catch (_) {}
    return null;
  }
}
