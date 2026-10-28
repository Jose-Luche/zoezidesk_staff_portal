import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/members.dart';
import 'app_badge.dart';

/// Initials in a circle (member photos come later).
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.initials, this.size = 40});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.accentTint, shape: BoxShape.circle),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: p.accentText, fontSize: size * 0.36),
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
  const MemberTile({super.key, required this.member, this.onTap, this.trailing, this.subtitle});

  final MemberCard member;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Replaces the member number and plan line.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final plan = member.membership?.plan;
    return ListTile(
      onTap: onTap,
      minTileHeight: AppSizes.minTouch + AppSpace.md,
      leading: MemberAvatar(initials: member.initials),
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
