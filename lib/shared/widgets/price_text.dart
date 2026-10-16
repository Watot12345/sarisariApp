import 'package:flutter/material.dart';
import '../../core/utils/currency_formatter.dart';

/// Reusable widget for rendering money amounts strictly formatted from integer centavos.
class PriceText extends StatelessWidget {
  final int centavos;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final bool isCompact;

  const PriceText({
    super.key,
    required this.centavos,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = TextStyle(
      fontSize: fontSize ?? 16.0,
      fontWeight: fontWeight ?? FontWeight.bold,
      color: color ?? theme.colorScheme.onSurface,
      letterSpacing: -0.2,
    );

    final formatted = isCompact
        ? CurrencyFormatter.formatCompact(centavos)
        : CurrencyFormatter.format(centavos);

    return Text(
      formatted,
      style: textStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
