import 'package:flutter/material.dart';

/// A shimmer skeleton loader for placeholder content during loading
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final highlightColor = theme.colorScheme.surface;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                0.0,
                _animation.value.clamp(0.0, 1.0),
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton loader for track chips in horizontal lists
class SkeletonTrackChip extends StatelessWidget {
  const SkeletonTrackChip({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(width: 160, height: 100, borderRadius: 12),
          SizedBox(height: 8),
          SkeletonLoader(width: 120, height: 14, borderRadius: 4),
          SizedBox(height: 4),
          SkeletonLoader(width: 80, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Skeleton loader for album cards in horizontal lists
class SkeletonAlbumCard extends StatelessWidget {
  const SkeletonAlbumCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(width: 150, height: 150, borderRadius: 12),
          SizedBox(height: 8),
          SkeletonLoader(width: 120, height: 14, borderRadius: 4),
          SizedBox(height: 4),
          SkeletonLoader(width: 90, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Horizontal list of skeleton track chips
class SkeletonTrackShelf extends StatelessWidget {
  const SkeletonTrackShelf({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => const SkeletonTrackChip(),
      ),
    );
  }
}

/// Horizontal list of skeleton album cards
class SkeletonAlbumShelf extends StatelessWidget {
  const SkeletonAlbumShelf({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => const SkeletonAlbumCard(),
      ),
    );
  }
}
