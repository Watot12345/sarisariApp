import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Reusable widget for displaying an offline product thumbnail image with fallback.
class ProductImageThumbnail extends StatelessWidget {
  final String? imagePath;
  final double width;
  final double height;
  final double borderRadius;
  final Widget? fallback;
  final BoxFit fit;

  const ProductImageThumbnail({
    super.key,
    this.imagePath,
    this.width = 44,
    this.height = 44,
    this.borderRadius = 8,
    this.fallback,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && imagePath!.isNotEmpty) {
      if (kIsWeb) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.network(
            imagePath!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildFallback(context),
          ),
        );
      }

      final file = File(imagePath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildFallback(context),
          ),
        );
      }
    }

    return _buildFallback(context);
  }

  Widget _buildFallback(BuildContext context) {
    if (fallback != null) return fallback!;

    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        size: width * 0.5,
        color: theme.colorScheme.onSurface.withOpacity(0.4),
      ),
    );
  }
}
