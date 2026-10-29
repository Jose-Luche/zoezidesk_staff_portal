import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/members.dart';
import 'app_badge.dart';

/// The member's photo in a circle, or their initials when there is none
/// (or it can't be loaded).
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.initials, this.size = 40, this.photoUrl});

  final String initials;
  final double size;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.accentTint, shape: BoxShape.circle),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: p.accentText, fontSize: size * 0.36),
      ),
    );
    final url = photoUrl;
    if (url == null) return fallback;

    // Its size, but square whatever room it is given (a ListTile caps the
    // leading widget's height), so a photo is never an oval.
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: size, maxHeight: size),
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipOval(
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            // Decoded at the size shown, not the camera's.
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            semanticLabel: 'Photo',
            errorBuilder: (_, _, _) => fallback,
            loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
          ),
        ),
      ),
    );
  }
}

/// Where a membership stands, in words and color.
class MembershipBadge extends StatelessWidget {
  const MembershipBadge({super.key, required this.member});

  final MemberCard member;

  @override
  Widget build(BuildContext context) {
    final m = member.membership;
    if (member.status == 'suspended') return const AppBadge(label: 'Suspended', tone: BadgeTone.danger);
    if (member.status == 'inactive') return const AppBadge(label: 'Inactive', tone: BadgeTone.neutral);
    if (m == null || !m.current) return const AppBadge(label: 'No active plan', tone: BadgeTone.danger);
    if (m.daysLeft <= 0) return const AppBadge(label: 'Ends today', tone: BadgeTone.warning);
    if (m.daysLeft <= 7) {
      return AppBadge(label: '${m.daysLeft} day${m.daysLeft == 1 ? '' : 's'} left', tone: BadgeTone.warning);
    }
    return AppBadge(label: 'Active to ${formatDate(m.expiresAt)}', tone: BadgeTone.success);
  }
}

/// One member in a list: avatar, name, number and membership.
class MemberTile extends StatelessWidget {
  const MemberTile({super.key, required this.member, this.onTap, this.trailing, this.subtitle, this.avatarSize = 40});

  final MemberCard member;

  /// Larger where staff check it is really the member (scan results).
  final double avatarSize;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Replaces the member number and plan line.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final plan = member.membership?.plan;
    return ListTile(
      onTap: onTap,
      // Room for a large avatar (the tile caps the leading widget's height).
      minTileHeight: max(AppSizes.minTouch + AppSpace.md, avatarSize + AppSpace.md),
      leading: MemberAvatar(initials: member.initials, photoUrl: member.photoUrl, size: avatarSize),
      title: Text(member.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpace.xs),
        child: Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(subtitle ?? [member.memberNumber, ?plan].join(' · ')),
            MembershipBadge(member: member),
          ],
        ),
      ),
      trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right_rounded)),
    );
  }
}
