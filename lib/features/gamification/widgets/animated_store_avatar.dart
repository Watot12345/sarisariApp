import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Returns the emoticon face corresponding to the store's current level (1-5).
/// Features animated expressions including joy/cheering and playful winking.
String getAvatarEmoticonForLevel(
  int level, {
  bool isCheering = false,
  bool isWinking = false,
}) {
  if (isCheering) return '🥳';
  if (isWinking) return '😉';
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

/// Particle model for TikTok-style floating tap reactions (hearts, sparkles, fire).
class _ReactionParticle {
  final String emoji;
  final double xOffset;
  final double drift;
  final double scale;
  final double targetY;

  const _ReactionParticle({
    required this.emoji,
    required this.xOffset,
    required this.drift,
    required this.scale,
    required this.targetY,
  });
}

/// Moving TikTok-style animated avatar emoticon widget.
/// Features:
/// 1. Vibrant TikTok rotating multi-stop neon gradient ring (Hot Pink, Cyan, Violet, Gold).
/// 2. Outer pulsing radar wave radiating outward.
/// 3. Dynamic organic physics: floating bobbing, rotational head sway, and squash & stretch.
/// 4. Lifelike expressions with periodic playful winking and cheering.
/// 5. TikTok-style floating reaction heart bursts on tap.
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
    with TickerProviderStateMixin {
  late final AnimationController _continuousController;
  late final AnimationController _tapReactionController;
  bool _isCheering = false;
  final List<_ReactionParticle> _particles = [];
  final math.Random _random = math.Random();

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
    // Continuous TikTok rotating ring + bobbing & breathing
    _continuousController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // Tap reaction controller for pop bounce & floating TikTok hearts
    _tapReactionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    if (_isFlutterTest) {
      _continuousController.forward();
    } else {
      _continuousController.repeat();
    }
  }

  @override
  void dispose() {
    _continuousController.dispose();
    _tapReactionController.dispose();
    super.dispose();
  }

  void _triggerTap() {
    setState(() {
      _isCheering = true;
      _particles.clear();
      final emojis = ['❤️', '💖', '✨', '🔥', '🌟', '🎉'];
      for (int i = 0; i < 5; i++) {
        _particles.add(
          _ReactionParticle(
            emoji: emojis[_random.nextInt(emojis.length)],
            xOffset: (_random.nextDouble() - 0.5) * widget.size * 0.6,
            drift: (_random.nextDouble() - 0.5) * widget.size * 0.5,
            scale: 0.75 + (_random.nextDouble() * 0.45),
            targetY: -(widget.size * (0.65 + _random.nextDouble() * 0.55)),
          ),
        );
      }
    });

    _tapReactionController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() => _isCheering = false);
      }
    });

    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ringDiameter = widget.size;
    final ringStrokeWidth = widget.size >= 72 ? 3.5 : 2.2;
    final avatarDiameter = widget.size * 0.80;

    return GestureDetector(
      onTap: widget.isInteractive || widget.onTap != null ? _triggerTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_continuousController, _tapReactionController]),
        builder: (context, _) {
          final t = _continuousController.value;
          final tapT = _tapReactionController.value;

          // TikTok 360-degree continuous ring rotation
          final ringAngle = t * 2 * math.pi;

          // Continuous radar pulse wave
          final pulse = (t * 2) % 1.0;

          // Dynamic vertical bobbing (-amplitude to +amplitude)
          final amplitude = widget.size * 0.055;
          final dy = math.sin(t * 2 * math.pi) * amplitude;

          // Organic rotational head sway
          final headAngle = math.sin(t * 2 * math.pi) * (_isCheering ? 0.16 : 0.06);

          // Squash & stretch physics
          final squashX = 1.0 + math.cos(t * 2 * math.pi) * 0.04;
          final squashY = 1.0 - math.cos(t * 2 * math.pi) * 0.04;

          // Tap spring pop scale
          double popScale = 1.0;
          if (_isCheering && tapT > 0) {
            if (tapT < 0.25) {
              popScale = 1.0 + (tapT / 0.25) * 0.25;
            } else {
              popScale = 1.25 - ((tapT - 0.25) / 0.75) * 0.25;
            }
          }

          // Lifelike expression: wink playfully during natural idle cycle
          final isWinking = !_isCheering && !_isFlutterTest && t > 0.82 && t < 0.94;

          final emoticon = getAvatarEmoticonForLevel(
            widget.level,
            isCheering: _isCheering,
            isWinking: isWinking,
          );

          return SizedBox(
            width: widget.size * 1.3,
            height: widget.size * 1.3,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // 1. TikTok expanding radar pulse ripple
                Transform.scale(
                  scale: 1.0 + (pulse * 0.28),
                  child: Container(
                    width: ringDiameter,
                    height: ringDiameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFE2C55).withValues(alpha: 0.48 * (1.0 - pulse)),
                        width: widget.size >= 72 ? 2.5 : 1.4,
                      ),
                    ),
                  ),
                ),

                // 2. Rotating TikTok Multi-Stop Neon Gradient Ring
                Transform.rotate(
                  angle: ringAngle,
                  child: Container(
                    width: ringDiameter,
                    height: ringDiameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          Color(0xFFFE2C55), // Hot TikTok Neon Pink/Red
                          Color(0xFF25F4EE), // Electric Aqua/Cyan
                          Color(0xFF9333EA), // Electric Violet
                          Color(0xFFFBBF24), // Vibrant Amber/Gold
                          Color(0xFFFE2C55), // Loop back seamlessly
                        ],
                        stops: [0.0, 0.28, 0.58, 0.85, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFE2C55).withValues(alpha: 0.35),
                          blurRadius: widget.size >= 72 ? 10 : 5,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(ringStrokeWidth),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Orbiting Sparkles and Coins on Hero Avatar
                if (widget.size >= 72) ...[
                  Positioned(
                    top: widget.size * 0.05 + (dy * 0.5),
                    right: widget.size * 0.04,
                    child: Transform.rotate(
                      angle: ringAngle * 0.5,
                      child: const Text('✨', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  Positioned(
                    bottom: widget.size * 0.08 - (dy * 0.5),
                    left: widget.size * 0.04,
                    child: Transform.rotate(
                      angle: -ringAngle * 0.3,
                      child: const Text('🪙', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],

                // 4. Moving Avatar Body with Squash & Stretch
                Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.rotate(
                    angle: headAngle,
                    child: Transform.scale(
                      scaleX: squashX * popScale,
                      scaleY: squashY * popScale,
                      child: Container(
                        width: avatarDiameter,
                        height: avatarDiameter,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF047857)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: const Color(0xFFFBBF24),
                            width: widget.size >= 72 ? 2.5 : 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF059669).withValues(alpha: 0.4),
                              blurRadius: widget.size * 0.16,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          emoticon,
                          style: TextStyle(
                            fontSize: avatarDiameter * 0.54,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 5. TikTok Tap Floating Reactions Burst (Hearts, Stars, Fire)
                if (_particles.isNotEmpty && tapT > 0)
                  ..._particles.map((p) {
                    final particleY = p.targetY * tapT;
                    final particleX = p.xOffset + (p.drift * tapT);
                    final opacity = (1.0 - tapT).clamp(0.0, 1.0);
                    final particleScale = p.scale * (1.0 + tapT * 0.4);

                    return Positioned(
                      top: (widget.size * 0.5) + particleY,
                      left: (widget.size * 0.65) + particleX,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: particleScale,
                          child: Text(
                            p.emoji,
                            style: TextStyle(
                              fontSize: widget.size >= 72 ? 24 : 16,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// TikTok-style compact Avatar button for the Home Screen AppBar.
/// Renders an authentic circular profile avatar with the rotating neon gradient ring,
/// bobbing animation, and an overlapping bottom "LVL" pill badge with live pulsing dot.
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: InkWell(
        key: const Key('store_avatar_appbar_button'),
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Rotating & Bobbing TikTok Avatar
              AnimatedStoreAvatar(
                level: level,
                size: 34,
              ),

              // TikTok "LIVE" style overlapping bottom pill badge
              Positioned(
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFE2C55), Color(0xFFFF007A)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFE2C55).withValues(alpha: 0.45),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'LVL $level',
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
