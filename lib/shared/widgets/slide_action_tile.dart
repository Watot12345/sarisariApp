import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// Reusable Long-Press + Slide-Left action drawer widget.
/// Maximizes row space by hiding Edit and Delete action buttons until the user
/// long-presses or slides the item to the left.
class SlideActionTile extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String editLabel;
  final String deleteLabel;

  const SlideActionTile({
    super.key,
    required this.child,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.editLabel = 'Edit',
    this.deleteLabel = 'Delete',
  });

  @override
  State<SlideActionTile> createState() => _SlideActionTileState();
}

class _SlideActionTileState extends State<SlideActionTile> {
  bool _isOpen = false;
  double _dragOffset = 0.0;

  double get _maxSlideExtent {
    int count = 0;
    if (widget.onEdit != null) count++;
    if (widget.onDelete != null) count++;
    return count * 64.0;
  }

  void _openDrawer() {
    if (_maxSlideExtent <= 0) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isOpen = true;
      _dragOffset = -_maxSlideExtent;
    });
  }

  void _closeDrawer() {
    if (!_isOpen && _dragOffset == 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isOpen = false;
      _dragOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxExtent = _maxSlideExtent;
    if (maxExtent <= 0) {
      return GestureDetector(
        onTap: widget.onTap,
        child: widget.child,
      );
    }

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        // Background Revealed Actions (Edit & Delete)
        Positioned.fill(
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onEdit != null)
                  _ActionButton(
                    icon: Icons.edit_rounded,
                    label: widget.editLabel,
                    color: AppTheme.accentBlue,
                    onTap: () {
                      _closeDrawer();
                      widget.onEdit?.call();
                    },
                  ),
                if (widget.onDelete != null) ...[
                  const SizedBox(width: 4),
                  _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: widget.deleteLabel,
                    color: AppTheme.dangerRed,
                    onTap: () {
                      _closeDrawer();
                      widget.onDelete?.call();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),

        // Foreground Slidable Card (AnimatedPadding shifts hit-test bounds left so right-side buttons are tappable)
        AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(right: (-_dragOffset).clamp(0.0, maxExtent)),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_isOpen) {
                _closeDrawer();
              } else {
                widget.onTap?.call();
              }
            },
            onLongPress: () {
              if (_isOpen) {
                _closeDrawer();
              } else {
                _openDrawer();
              }
            },
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragOffset = (_dragOffset + details.delta.dx).clamp(-maxExtent, 0.0);
                _isOpen = _dragOffset <= -(maxExtent * 0.45);
              });
            },
            onHorizontalDragEnd: (_) {
              if (_dragOffset <= -(maxExtent * 0.35)) {
                _openDrawer();
              } else {
                _closeDrawer();
              }
            },
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
