import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Static placeholder pill. No shimmer: nothing loops while loading.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.circle = false});

  final double? width;
  final double height;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.palette.skeleton,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(AppRadius.pill),
        ),
      );
}

/// Placeholder rows while the first load runs.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6}) : inline = false;

  /// For use inside another scrolling list: sized to its rows.
  const SkeletonList.inline({super.key, this.itemCount = 3}) : inline = true;

  final int itemCount;
  final bool inline;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading',
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: inline,
          padding: inline ? EdgeInsets.zero : const EdgeInsets.only(top: AppSpace.lg),
          itemCount: itemCount,
          itemBuilder: (_, _) => const SkeletonListTile(),
        ),
      );
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppGutter.rows + 10, vertical: 10),
        child: Row(children: [
          SkeletonBox(width: 42, height: 42, circle: true),
          SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(width: 150),
              SizedBox(height: AppSpace.sm),
              SkeletonBox(width: 96, height: 10),
            ]),
          ),
        ]),
      );
}
