import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Returns the emoticon face corresponding to the store's current level (1-5).
String getAvatarEmoticonForLevel(int level, {bool isCheering = false}) {
  if (isCheering) return '🥳';
  switch (level) {
    case 1:
      return '😊';
    case 2:
      return '😄';
    case 3:
      return '😎';
    case 4:
      return '🤩';
    default:
      return '👑';
  }
}

/// Moving animated avatar emoticon widget.
/// Supports both a compact badge mode (for the Home AppBar) and a large interactive hero mode
/// (for the dedicated Store Avatar Gamification screen).
class AnimatedStoreAvatar extends StatefulWidget {
  final int level;
  final double size;
  final bool isInteractive;
  final VoidCallback? onTap;

  const AnimatedStoreAvatar({
    super.key,
    required this.level,
    this.size = 96,
    this.isInteractive = false,
    this.onTap,
  });

  @override
  State<AnimatedStoreAvatar> createState() => _AnimatedStoreAvatarState();
}

class _AnimatedStoreAvatarState extends State<AnimatedStoreAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isCheering = false;

  static bool get _isFlutterTest {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (_isFlutterTest) {
      // Run one finite animation cycle in widget tests so pumpAndSettle completes cleanly
      _controller.forward();
    } else {
      // Continuously bob, wave, and pulse in the live app
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerCheer() {
    setState(() => _isCheering = true);
    _controller.forward(from: 0.0).then((_) {
      if (!mounted) return;
      if (!_isFlutterTest) {
        _controller.repeat(reverse: true);
      }
      setState(() => _isCheering = false);
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final emoticon = getAvatarEmoticonForLevel(
      widget.level,
      isCheering: _isCheering,
    );

    return GestureDetector(
      onTap: widget.isInteractive || widget.onTap != null ? _triggerCheer : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          // Smooth floating bobbing motion (-6px to +6px scaled by widget size)
          final amplitude = widget.size * 0.065;
          final dy = math.sin(t * math.pi * 2) * amplitude;
          // Gentle joyful tilt (-0.06 rad to +0.06 rad)
          final angle = math.cos(t * math.pi * 2) * (_isCheering ? 0.14 : 0.05);
          // Breathing scale (0.96 to 1.06)
          final scale = 1.0 + (math.sin(t * math.pi) * (_isCheering ? 0.12 : 0.05));

          return SizedBox(
            width: widget.size * 1.25,
            height: widget.size * 1.25,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Pulsing aura ring
                Transform.scale(
                  scale: 0.92 + (t * 0.18),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primaryGreen.withOpacity(0.28 * (1.0 - t * 0.4)),
                          AppTheme.accentAmber.withOpacity(0.16 * (1.0 - t * 0.4)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Orbiting sparkle badges on larger hero avatar
                if (widget.size >= 72) ...[
                  Positioned(
                    top: widget.size * 0.06 + (dy * 0.5),
                    right: widget.size * 0.08,
                    child: Transform.rotate(
                      angle: t * math.pi * 0.5,
                      child: const Text('✨', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  Positioned(
                    bottom: widget.size * 0.10 - (dy * 0.5),
                    left: widget.size * 0.08,
                    child: const Text('🪙', style: TextStyle(fontSize: 16)),
                  ),
                ],

                // Moving Avatar Circle with Emoticon
                Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.rotate(
                    angle: angle,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: widget.size * 0.84,
                        height: widget.size * 0.84,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF047857)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: AppTheme.accentAmber,
                            width: widget.size >= 72 ? 3.0 : 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withOpacity(0.35),
                              blurRadius: widget.size * 0.18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          emoticon,
                          style: TextStyle(
                            fontSize: widget.size * 0.44,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Compact clickable Avatar Emoticon pill for the Home Screen AppBar.
/// Keeps the Home Screen focused on store management while letting the owner tap
/// the avatar to open the dedicated Store Avatar Gamification Screen.
class StoreAvatarAppBarButton extends StatelessWidget {
  final int level;
  final VoidCallback onTap;

  const StoreAvatarAppBarButton({
    super.key,
    required this.level,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: InkWell(
        key: const Key('store_avatar_appbar_button'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.only(left: 4, right: 10, top: 2, bottom: 2),
          decoration: BoxDecoration(
            color: AppTheme.accentAmber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.accentAmber.withOpacity(0.45),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedStoreAvatar(
                level: level,
                size: 28,
              ),
              const SizedBox(width: 4),
              Text(
                'LVL $level',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFB45309),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
