import 'package:flutter/material.dart';

/// Ultra High-Definition Material 3 Theme definitions for Tindahan.
/// Styled with lush Filipino emeralds, warm amber, obsidian darks, and crisp glass surfaces.
class AppTheme {
  AppTheme._();

  // Curated Color Palette
  static const Color primaryGreen = Color(0xFF059669); // Vivid Emerald Green
  static const Color primaryGreenDark = Color(0xFF10B981); // Bright Mint Emerald
  static const Color primaryGreenContainer = Color(0xFFD1FAE5);
  static const Color primaryForest = Color(0xFF064E3B);

  static const Color accentAmber = Color(0xFFF59E0B); // Golden Harvest Amber
  static const Color accentBlue = Color(0xFF2563EB); // Royal Sapphire
  static const Color accentPurple = Color(0xFF7C3AED); // Deep Violet
  static const Color dangerRed = Color(0xFFEF4444); // Crimson Coral
  static const Color warningOrange = Color(0xFFF97316); // Bright Tangerine

  // High-End Light Neutral Surfaces
  static const Color bgLight = Color(0xFFF8F9FB); // Crisp warm porcelain
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A); // Deep Slate
  static const Color textMuted = Color(0xFF64748B);

  // High-End Obsidian Dark Surfaces
  static const Color bgDark = Color(0xFF0B0F19); // Deep Obsidian
  static const Color cardDark = Color(0xFF151E2E); // Deep Slate Navy
  static const Color borderDark = Color(0xFF263345);
  static const Color textLight = Color(0xFFF8FAFC);
  static const Color textDarkMuted = Color(0xFF94A3B8);

  /// Helper to get consistent Category Accent Colors with icons
  static (Color, IconData) getCategoryStyle(String category) {
    switch (category.toLowerCase()) {
      case 'noodles':
        return (const Color(0xFFF59E0B), Icons.ramen_dining_rounded);
      case 'drinks':
        return (const Color(0xFF0284C7), Icons.local_drink_rounded);
      case 'snacks':
        return (const Color(0xFFEA580C), Icons.cookie_rounded);
      case 'coffee':
        return (const Color(0xFF92400E), Icons.coffee_rounded);
      case 'toiletries':
        return (const Color(0xFF0D9488), Icons.clean_hands_rounded);
      case 'household':
        return (const Color(0xFF6366F1), Icons.cleaning_services_rounded);
      case 'cigarettes':
        return (const Color(0xFF64748B), Icons.smoking_rooms_rounded);
      case 'condiments':
        return (const Color(0xFFDC2626), Icons.soup_kitchen_rounded);
      case 'canned goods':
        return (const Color(0xFF059669), Icons.takeout_dining_rounded);
      default:
        return (const Color(0xFF475569), Icons.category_rounded);
    }
  }

  /// Returns customized container surface and border color based on user's selected container theme preset.
  static (Color, Color) getCustomContainerStyle(String preset, {required bool isDark}) {
    switch (preset) {
      case 'emerald':
        return isDark
            ? (const Color(0xFF0E2923), const Color(0xFF10B981).withOpacity(0.35))
            : (const Color(0xFFECFDF5), const Color(0xFF6EE7B7));
      case 'blue':
        return isDark
            ? (const Color(0xFF112240), const Color(0xFF3B82F6).withOpacity(0.35))
            : (const Color(0xFFEFF6FF), const Color(0xFF93C5FD));
      case 'purple':
        return isDark
            ? (const Color(0xFF22153B), const Color(0xFF8B5CF6).withOpacity(0.35))
            : (const Color(0xFFF5F3FF), const Color(0xFFC4B5FD));
      case 'amber':
        return isDark
            ? (const Color(0xFF2B1F11), const Color(0xFFF59E0B).withOpacity(0.35))
            : (const Color(0xFFFFFBEB), const Color(0xFFFCD34D));
      case 'rose':
        return isDark
            ? (const Color(0xFF2D1420), const Color(0xFFF43F5E).withOpacity(0.35))
            : (const Color(0xFFFFF1F2), const Color(0xFFFDA4AF));
      default:
        return isDark ? (cardDark, borderDark) : (cardLight, borderLight);
    }
  }

  /// Light Theme Definition (HD)
  static ThemeData get lightTheme => getLightTheme('default');

  static ThemeData getLightTheme(String containerPreset) {
    final (customCardColor, customBorderColor) =
        getCustomContainerStyle(containerPreset, isDark: false);
    final colorScheme = ColorScheme.light(
      primary: primaryGreen,
      onPrimary: Colors.white,
      primaryContainer: primaryGreenContainer,
      onPrimaryContainer: primaryForest,
      secondary: accentAmber,
      onSecondary: Colors.white,
      error: dangerRed,
      onError: Colors.white,
      surface: bgLight,
      onSurface: textDark,
      surfaceContainerHighest: customCardColor,
      outline: customBorderColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgLight,
      cardTheme: CardThemeData(
        color: customCardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: customBorderColor, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen, width: 1.5),
          minimumSize: const Size(88, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: customBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: customBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll(false),
        trackVisibility: WidgetStatePropertyAll(false),
        thickness: WidgetStatePropertyAll(0.0),
      ),
    );
  }

  /// Dark Theme Definition (Obsidian HD)
  static ThemeData get darkTheme => getDarkTheme('default');

  static ThemeData getDarkTheme(String containerPreset) {
    final (customCardColor, customBorderColor) =
        getCustomContainerStyle(containerPreset, isDark: true);
    final colorScheme = ColorScheme.dark(
      primary: primaryGreenDark,
      onPrimary: const Color(0xFF042F2C),
      primaryContainer: const Color(0xFF064E3B),
      onPrimaryContainer: const Color(0xFFA7F3D0),
      secondary: const Color(0xFFFBBF24),
      onSecondary: Colors.black,
      error: const Color(0xFFF87171),
      onError: Colors.black,
      surface: bgDark,
      onSurface: textLight,
      surfaceContainerHighest: customCardColor,
      outline: customBorderColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgDark,
      cardTheme: CardThemeData(
        color: customCardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: customBorderColor, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: textLight,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreenDark,
          foregroundColor: const Color(0xFF064E3B),
          minimumSize: const Size(88, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryGreenDark, width: 2),
        ),
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll(false),
        trackVisibility: WidgetStatePropertyAll(false),
        thickness: WidgetStatePropertyAll(0.0),
      ),
    );
  }
}
