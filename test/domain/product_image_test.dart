import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindahan/core/services/product_image_service.dart';
import 'package:tindahan/data/models/product.dart';
import 'package:tindahan/features/products/providers/product_provider.dart';
import 'package:tindahan/shared/widgets/product_image_thumbnail.dart';

void main() {
  group('Product Image Feature Tests', () {
    test('Product model accurately serializes and deserializes imagePath', () {
      const p = Product(
        id: 101,
        name: 'Bear Brand Fortified 33g',
        priceCents: 1600,
        costCents: 1350,
        stockQty: 40,
        imagePath: '/data/user/0/com.example.tindahan/app_flutter/product_images/prod_101.jpg',
      );

      final map = p.toMap();
      expect(map['image_path'], '/data/user/0/com.example.tindahan/app_flutter/product_images/prod_101.jpg');

      final restored = Product.fromMap(map);
      expect(restored.id, 101);
      expect(restored.name, 'Bear Brand Fortified 33g');
      expect(restored.imagePath, '/data/user/0/com.example.tindahan/app_flutter/product_images/prod_101.jpg');

      final updated = restored.copyWith(imagePath: '/new/path.jpg');
      expect(updated.imagePath, '/new/path.jpg');

      final cleared = restored.copyWith(clearImagePath: true);
      expect(cleared.imagePath, isNull);
    });

    test('ProductImageService formatted file size calculates correctly', () async {
      // Test non-existent file
      final nullSize = await ProductImageService.getFormattedFileSize(null);
      expect(nullSize, isNull);

      final nonExistent = await ProductImageService.getFormattedFileSize('/does/not/exist.jpg');
      expect(nonExistent, isNull);

      // Create a temporary file
      final tempFile = File('${Directory.systemTemp.path}/test_image_compression.jpg');
      await tempFile.writeAsBytes(List.generate(35840, (i) => i % 256)); // ~35 KB

      final formatted = await ProductImageService.getFormattedFileSize(tempFile.path);
      expect(formatted, contains('KB'));

      // Test deletion
      await ProductImageService.deleteImageFile(tempFile.path);
      expect(await tempFile.exists(), isFalse);
    });

    testWidgets('ProductImageThumbnail renders fallback when imagePath is null or missing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImageThumbnail(
              imagePath: null,
              width: 50,
              height: 50,
              fallback: Icon(Icons.ramen_dining, key: Key('fallback_icon')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('fallback_icon')), findsOneWidget);
    });

    test('ProductProvider adds product with imagePath', () async {
      final provider = ProductProvider();
      await provider.addProduct(
        const Product(
          id: 0,
          name: 'Nissin Cup Noodles Seafood',
          priceCents: 3500,
          costCents: 2900,
          stockQty: 15,
          categoryName: 'Noodles',
          imagePath: '/app/doc/product_images/nissin.jpg',
        ),
        categoryName: 'Noodles',
      );

      final added = provider.allProducts.firstWhere((p) => p.name == 'Nissin Cup Noodles Seafood');
      expect(added.imagePath, '/app/doc/product_images/nissin.jpg');
      expect(added.priceCents, 3500);
    });
  });
}
