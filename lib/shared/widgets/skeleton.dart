import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Static placeholder block. No shimmer: the design system forbids looping
/// animations.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = AppSpace.md,
    this.radius = AppRadius.control,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.skeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder for a list of card rows while the first load runs.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6}) : inline = false;

  /// For use inside another scrolling list: sized to its rows, no padding.
  const SkeletonList.inline({super.key, this.itemCount = 3}) : inline = true;

  final int itemCount;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: inline,
        padding: inline ? EdgeInsets.zero : const EdgeInsets.all(AppSpace.md),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
        itemBuilder: (_, _) => const SkeletonListTile(),
      ),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpace.md),
        child: Row(
          children: [
            SkeletonBox(width: AppSpace.xxl, height: AppSpace.xxl),
            SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 160),
                  SizedBox(height: AppSpace.sm),
                  SkeletonBox(width: 96, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
