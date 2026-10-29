import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/day_bars.dart';
import '../../shared/widgets/member_tile.dart';
import '../../shared/widgets/page.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_message.dart';
import '../../shared/widgets/tag.dart';
import '../../shared/widgets/toast.dart';

/// Every component of the Organic system on one screen, in both themes
/// (debug builds only).
class DesignGalleryScreen extends ConsumerStatefulWidget {
  const DesignGalleryScreen({super.key});

  @override
  ConsumerState<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends ConsumerState<DesignGalleryScreen> {
  String _seg = 'mpesa';
  String _chip = 'all';
  int _plan = 1;
  bool _switch = true;
  bool _tick = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    Widget section(String title) => SectionHeading(title, padding: const EdgeInsets.only(top: AppSpace.xxl, bottom: AppSpace.sm));

    return AppPage(
      title: 'Design system',
      actions: [
        CircleIconButton(
          icon: AppIcons.theme,
          tooltip: isDark ? 'Light theme' : 'Dark theme',
          onPressed: () => ref.read(themeModeProvider.notifier).set(isDark ? ThemeMode.light : ThemeMode.dark),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppGutter.cards, 0, AppGutter.cards, AppSpace.xxxl),
        children: [
          section('Type'),
          Text('Morning,\nMary.', style: text.displayLarge),
          Text('Headline large', style: text.headlineLarge),
          Text('Headline medium', style: text.headlineMedium),
          Text('Needs you now', style: text.titleLarge),
          Text('List title, Figtree 600', style: text.titleSmall),
          Text('Body: plain, short, human.', style: text.bodyMedium),
          Text('Helper and subtitles, muted', style: text.bodySmall),
          section('Buttons'),
          FilledButton(onPressed: () {}, child: const Text('Send KES 4,000 request')),
          const SizedBox(height: AppSpace.sm),
          OutlinedButton(onPressed: () {}, child: const Text('Send receipt')),
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            TextButton(onPressed: () {}, child: const Text('See all 14')),
            const FilledButton(onPressed: null, child: Text('Disabled')),
          ]),
          const SizedBox(height: AppSpace.lg),
          Row(children: [
            ScanButton(onPressed: () {}),
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(children: [
                QuickAction(icon: AppIcons.search, label: 'Find', onPressed: () {}),
                const SizedBox(height: AppSpace.md),
                QuickAction(icon: AppIcons.register, label: 'Register', onPressed: () {}),
              ]),
            ),
          ]),
          section('Tags'),
          const Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
            AppTag(label: 'Monthly', tone: Tone.success),
            AppTag(label: 'Ends 28 Nov', tone: Tone.warning),
            AppTag(label: 'Expired', tone: Tone.danger),
            AppTag(label: 'No plan'),
          ]),
          section('Controls'),
          PillSegmented<String>(
            options: const [('mpesa', 'M-Pesa'), ('cash', 'Cash'), ('bank', 'Bank')],
            selected: _seg,
            onChanged: (v) => setState(() => _seg = v),
          ),
          const SizedBox(height: AppSpace.md),
          ChipRow(padding: EdgeInsets.zero, children: [
            for (final (v, l) in const [('all', 'All'), ('in', 'In today'), ('ending', 'Ending soon')])
              PillChip(label: l, selected: _chip == v, onTap: () => setState(() => _chip = v)),
          ]),
          const SizedBox(height: AppSpace.md),
          RoleSwitcher<String>(
            options: const [('desk', 'Desk'), ('owner', 'Owner')],
            selected: _chip == 'all' ? 'desk' : 'owner',
            onChanged: (v) => setState(() => _chip = v == 'desk' ? 'all' : 'in'),
          ),
          const SizedBox(height: AppSpace.md),
          for (final (i, name) in const ['Monthly', 'Quarterly'].indexed) ...[
            RadioPillRow(
              title: name,
              detail: i == 0 ? '30 days' : '90 days',
              trailing: i == 0 ? '4,000' : '10,500',
              selected: _plan == i,
              onTap: () => setState(() => _plan = i),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
          SwitchRow(title: 'Send a WhatsApp confirmation', value: _switch, onChanged: (v) => setState(() => _switch = v)),
          Row(children: [
            CheckToggle(value: _tick, onChanged: (v) => setState(() => _tick = v), semanticLabel: 'Came'),
            const SizedBox(width: AppSpace.md),
            const Text('Check toggle'),
          ]),
          const SizedBox(height: AppSpace.md),
          const AppField(label: 'M-Pesa number', hint: '0712 345 678', prefixIcon: AppIcons.phone, helper: 'A payment request goes to this phone.'),
          const SizedBox(height: AppSpace.md),
          const AppField(label: 'Amount received (KES)', error: 'Enter the amount received.'),
          section('Cards'),
          ActionCard(tone: Tone.warning, badge: const Text('BO'), title: 'Brian is in', subtitle: 'Monthly ends 28 Nov', actionLabel: 'Renew', onAction: () {}),
          const SizedBox(height: AppSpace.sm),
          const ActionCard(tone: Tone.danger, badge: Icon(AppIcons.refused), title: 'Refused when sent', subtitle: 'Membership ended'),
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            const Expanded(child: StatTile(value: 'KES 18,500', caption: 'Revenue today')),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: StatTile(value: '6', caption: 'Expiring in 7 days', onTap: () {})),
          ]),
          const SizedBox(height: AppSpace.sm),
          const InfoCard(message: 'Enter a Safaricom number, like 0712 345 678.', tone: Tone.warning),
          const SizedBox(height: AppSpace.sm),
          const DayBars(values: [12, 18, 9, 22, 15, 8, 14], labels: ['Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue', 'Today'], semanticTitle: 'Check-ins'),
          section('Rows'),
          const MemberAvatar(initials: 'MW', size: 74, seed: 1),
          const SkeletonListTile(),
          section('States'),
          StateMessage.offline(onAction: () {}),
          section('Sheet and toast'),
          OutlinedButton(
            onPressed: () => showAppSheet<void>(
              context,
              builder: (context) => SheetBody(children: [
                const SheetTitle('Take payment', subtitle: 'Mary Wanjiku · Ends 28 Nov'),
                FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Record KES 4,000')),
              ]),
            ),
            child: const Text('Open a sheet'),
          ),
          const SizedBox(height: AppSpace.sm),
          OutlinedButton(onPressed: () => showToast(context, 'Brian is checked in'), child: const Text('Show a toast')),
        ],
      ),
    );
  }
}
