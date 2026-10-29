import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/members.dart';
import 'tag.dart';

/// The member's photo in a circle, or their initials on one of three tints
/// (sage, terracotta, sand), picked from [seed] so a person keeps theirs.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.initials, this.size = 42, this.photoUrl, this.seed});

  final String initials;
  final double size;
  final String? photoUrl;

  /// Usually the member's id; the initials when there is none.
  final int? seed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tones = [p.avatarSage, p.avatarTerra, p.avatarSand];
    final tone = tones[(seed ?? initials.codeUnits.fold<int>(0, (a, b) => a + b)) % tones.length];
    final text = Theme.of(context).textTheme;
    // Figtree bold in lists, Caprasimo once the circle is big enough.
    final large = size >= 60;
    final style = (large ? text.headlineMedium : text.labelLarge)?.copyWith(
      color: tone.on,
      fontSize: size * (large ? 0.36 : 0.34),
      fontWeight: large ? FontWeight.w400 : FontWeight.w700,
      height: 1,
    );
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tone.fill, shape: BoxShape.circle),
      child: Text(initials, style: style),
    );
    final url = photoUrl;
    if (url == null) return fallback;

    // Its size, but square whatever room it is given, so a photo is never
    // an oval.
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

/// Where a membership stands, as a tag (design.md §3): the plan name while
/// active, "Ends {date}" in its last week, "Expired", or "No plan".
class MembershipTag extends StatelessWidget {
  const MembershipTag({super.key, required this.member});

  final MemberCard member;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = membershipStatus(member);
    return AppTag(label: label, tone: tone);
  }
}

/// The words and tone for [MembershipTag], also used in subtitles.
(String, Tone) membershipStatus(MemberCard member) {
  final m = member.membership;
  if (member.status == 'suspended') return ('Suspended', Tone.danger);
  if (member.status == 'inactive') return ('Inactive', Tone.neutral);
  if (m == null) return ('No plan', Tone.neutral);
  if (!m.current) return ('Expired', Tone.danger);
  if (m.daysLeft <= 7) return ('Ends ${formatShortDate(m.expiresAt)}', Tone.warning);
  return (m.plan ?? 'Active', Tone.success);
}

/// A membership that has ended, or ends within the week.
bool needsRenewal(MemberCard member) {
  final m = member.membership;
  return m == null || !m.current || m.daysLeft <= 7;
}

/// One member in a list: avatar, name, a subtitle and their status tag.
/// With [inAt], the subtitle reads "07:42 · QR" for people in today.
class MemberRow extends StatelessWidget {
  const MemberRow({
    super.key,
    required this.member,
    this.onTap,
    this.subtitle,
    this.inAt,
    this.inBy,
    this.trailing,
    this.avatarSize = 42,
  });

  final MemberCard member;
  final VoidCallback? onTap;
  final String? subtitle;
  final DateTime? inAt;

  /// The check-in method with [inAt]: 'qr' or by hand.
  final String? inBy;

  /// Replaces the status tag.
  final Widget? trailing;
  final double avatarSize;

  static String defaultSubtitle(MemberCard m, {DateTime? inAt, String? inBy}) => inAt != null
      ? '${DateFormat.Hm().format(inAt)} · ${inBy == 'qr' ? 'QR' : 'By hand'}'
      : ['#${m.memberNumber}', if (m.phone.isNotEmpty) formatLocalPhone(m.phone)].join(' · ');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppGutter.rows),
      child: Material(
        color: Organic.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          hoverColor: p.hover,
          highlightColor: p.hover,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              MemberAvatar(initials: member.initials, photoUrl: member.photoUrl, size: avatarSize, seed: member.id),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(member.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                  Text(
                    subtitle ?? defaultSubtitle(member, inAt: inAt, inBy: inBy),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ]),
              ),
              const SizedBox(width: AppSpace.sm),
              trailing ?? MembershipTag(member: member),
            ]),
          ),
        ),
      ),
    );
  }
}
