import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_message.dart';

/// Review screen for the design system. Shown as the home screen until the
/// login feature lands, then kept as a debug-only route.
class DesignGalleryScreen extends StatelessWidget {
  const DesignGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design system'),
        actions: const [_ThemeToggle()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.md),
        children: [
          const _Section('Typography'),
          Text('Display small', style: text.displaySmall),
          Text('Headline medium', style: text.headlineMedium),
          Text('Title large', style: text.titleLarge),
          Text('Title medium', style: text.titleMedium),
          Text('Body large 18sp', style: text.bodyLarge),
          Text('Body medium 16sp, the default body size.', style: text.bodyMedium),
          Text('Body small 16sp, muted', style: text.bodySmall),
          const _Section('Buttons'),
          FilledButton(onPressed: () {}, child: const Text('Book class')),
          const SizedBox(height: AppSpace.sm),
          OutlinedButton(onPressed: () {}, child: const Text('View schedule')),
          const SizedBox(height: AppSpace.sm),
          TextButton(onPressed: () {}, child: const Text('See all payments')),
          const SizedBox(height: AppSpace.sm),
          const FilledButton(onPressed: null, child: Text('Disabled')),
          const _Section('Badges'),
          const Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              AppBadge(label: '5 day streak', icon: Icons.local_fire_department_rounded),
              AppBadge(label: 'Active', tone: BadgeTone.success),
              AppBadge(label: 'Expires in 3 days', tone: BadgeTone.warning),
              AppBadge(label: 'Failed', tone: BadgeTone.danger),
              AppBadge(label: 'Pending', tone: BadgeTone.neutral, icon: Icons.schedule_rounded),
            ],
          ),
          const _Section('Inputs'),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Phone number',
              hintText: '0712 345 678',
              prefixIcon: Icon(Icons.phone_rounded),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Code',
              errorText: 'The code must be 6 digits.',
            ),
          ),
          const _Section('Card'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fitness_center_rounded),
              title: const Text('HIIT Blast'),
              subtitle: const Text('Mon 6:00 PM · 4 spots left'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {},
            ),
          ),
          const _Section('Skeleton'),
          const SkeletonListTile(),
          const _Section('States'),
          Card(
            child: StateMessage.offline(onAction: () {}),
          ),
          const _Section('Bottom sheet'),
          OutlinedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md, 0, AppSpace.md, AppSpace.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Confirm booking', style: text.headlineSmall),
                    const SizedBox(height: AppSpace.sm),
                    Text('HIIT Blast, Monday 6:00 PM', style: text.bodyMedium),
                    const SizedBox(height: AppSpace.lg),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              ),
            ),
            child: const Text('Open bottom sheet'),
          ),
          const SizedBox(height: AppSpace.xxl),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.sm),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return IconButton(
      tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
      icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
      onPressed: () => ref
          .read(themeModeProvider.notifier)
          .set(isDark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}
