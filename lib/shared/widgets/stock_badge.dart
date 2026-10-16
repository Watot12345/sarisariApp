import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Visual status badge showing product stock health with glowing dot indicator.
class StockBadge extends StatelessWidget {
  final int stockQty;
  final int lowStockLevel;
  final bool showDot;

  const StockBadge({
    super.key,
    required this.stockQty,
    this.lowStockLevel = 5,
    this.showDot = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    final Color dotColor;
    final String label;

    if (stockQty <= 0) {
      dotColor = AppTheme.dangerRed;
      badgeColor = AppTheme.dangerRed.withOpacity(0.12);
      label = 'Out of Stock';
    } else if (stockQty <= lowStockLevel) {
      dotColor = AppTheme.warningOrange;
      badgeColor = AppTheme.warningOrange.withOpacity(0.15);
      label = 'Low: $stockQty';
    } else {
      dotColor = AppTheme.primaryGreen;
      badgeColor = AppTheme.primaryGreen.withOpacity(0.12);
      label = '$stockQty in stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dotColor.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withOpacity(0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: dotColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
