import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shimmer animation controller provider that animates across its descendants
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final double value = _controller.value;
            return LinearGradient(
              begin: const Alignment(-1.5, -0.3),
              end: const Alignment(1.5, 0.3),
              stops: [
                (value - 0.3).clamp(0.0, 1.0),
                value.clamp(0.0, 1.0),
                (value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [
                Colors.black.withValues(alpha: 0.08),
                Colors.black.withValues(alpha: 0.02),
                Colors.black.withValues(alpha: 0.08),
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Basic placeholder box with configurable dimensions and rounded corners
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.65),
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(borderRadius)
            : null,
      ),
    );
  }
}

/// Full Profile page skeleton matching the user profile layout
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Photo & Avatar Area
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover
                const ShimmerBox(
                  width: double.infinity,
                  height: 160,
                  borderRadius: 0,
                ),
                // Avatar
                Positioned(
                  bottom: -40,
                  left: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 4),
                    ),
                    child: const ShimmerBox(
                      width: 88,
                      height: 88,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Follow / Edit Profile Button Placeholder
                const Positioned(
                  bottom: -32,
                  right: 20,
                  child: ShimmerBox(
                    width: 105,
                    height: 38,
                    borderRadius: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 52),

            // Profile info padding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display name
                  const ShimmerBox(width: 170, height: 22, borderRadius: 6),
                  const SizedBox(height: 8),
                  // Username
                  const ShimmerBox(width: 100, height: 14, borderRadius: 4),
                  const SizedBox(height: 14),

                  // Bio lines
                  const ShimmerBox(width: double.infinity, height: 13, borderRadius: 4),
                  const SizedBox(height: 6),
                  const ShimmerBox(width: 220, height: 13, borderRadius: 4),
                  const SizedBox(height: 20),

                  // Stats row (Posts, Followers, Following)
                  Row(
                    children: [
                      _buildStatBox(),
                      const SizedBox(width: 24),
                      _buildStatBox(),
                      const SizedBox(width: 24),
                      _buildStatBox(),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // My Pets Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      ShimmerBox(width: 80, height: 18, borderRadius: 6),
                      ShimmerBox(width: 50, height: 14, borderRadius: 4),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pet Avatars / Cards row
                  Row(
                    children: List.generate(
                      3,
                      (i) => Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Column(
                          children: const [
                            ShimmerBox(width: 62, height: 62, shape: BoxShape.circle),
                            SizedBox(height: 6),
                            ShimmerBox(width: 48, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tab bar placeholder
                  Row(
                    children: const [
                      Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
                      SizedBox(width: 12),
                      Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Post Grid items
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                    ),
                    itemCount: 6,
                    itemBuilder: (_, _) => const ShimmerBox(
                      borderRadius: 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        ShimmerBox(width: 32, height: 18, borderRadius: 4),
        SizedBox(height: 4),
        ShimmerBox(width: 55, height: 12, borderRadius: 4),
      ],
    );
  }
}

/// Shimmer skeleton for lists (Followers, Following, Search results)
class UserListSkeleton extends StatelessWidget {
  final int itemCount;

  const UserListSkeleton({
    super.key,
    this.itemCount = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              const ShimmerBox(
                width: 46,
                height: 46,
                shape: BoxShape.circle,
              ),
              const SizedBox(width: 12),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(width: 120, height: 15, borderRadius: 4),
                    SizedBox(height: 6),
                    ShimmerBox(width: 75, height: 12, borderRadius: 4),
                  ],
                ),
              ),
              // Button
              const ShimmerBox(
                width: 78,
                height: 32,
                borderRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
