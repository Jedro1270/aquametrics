import 'package:flutter/material.dart';

import '../models/count_batch.dart';
import '../theme/app_theme.dart';
import '../widgets/count_widgets.dart';
import '../widgets/species_pills.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Species _defaultSpecies = Species.tilapia;
  double _defaultSensitivity = 0.72;
  bool _keepPhotos = true;
  bool _confirmBeforeSave = true;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Text('Settings', style: text.headlineMedium),
        const SizedBox(height: 20),
        _Group(
          title: 'Counting',
          children: [
            _Block(
              label: 'Default species',
              caption: 'Pre-selected when you open the camera.',
              child: SpeciesPills(
                selected: _defaultSpecies,
                onChanged: (s) => setState(() => _defaultSpecies = s),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            _Block(
              label: 'Default sensitivity',
              caption: 'Where the slider starts on a new count.',
              child: Slider(
                value: _defaultSensitivity,
                onChanged: (v) => setState(() => _defaultSensitivity = v),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            _SwitchRow(
              label: 'Check the count before saving',
              caption: 'Opens the review step every time. Recommended.',
              value: _confirmBeforeSave,
              onChanged: (v) => setState(() => _confirmBeforeSave = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Group(
          title: 'Storage',
          children: [
            _SwitchRow(
              label: 'Keep captured photos',
              caption: 'Lets you re-check a count later. Uses more space.',
              value: _keepPhotos,
              onChanged: (v) => setState(() => _keepPhotos = v),
            ),
            const Divider(height: 1, color: AppColors.line),
            _TapRow(
              label: 'Export all counts',
              caption: 'CSV you can open in a spreadsheet.',
              icon: Icons.ios_share_rounded,
              onTap: () => _soon(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.phone_iphone_rounded,
                size: 20,
                color: AppColors.teal,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Counts stay on this phone. No account, no upload, works '
                  'with no signal.',
                  style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: Text(
            'AquaMetrics 0.1.0  ·  UI preview',
            style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
          ),
        ),
      ],
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Not wired up yet')),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 9),
          child: Eyebrow(title),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.label,
    required this.caption,
    required this.child,
  });

  final String label;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.titleMedium),
          const SizedBox(height: 3),
          Text(caption, style: text.bodySmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.caption,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String caption;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.titleMedium),
                const SizedBox(height: 3),
                Text(caption, style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.teal,
          ),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow({
    required this.label,
    required this.caption,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String caption;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: text.titleMedium),
                  const SizedBox(height: 3),
                  Text(caption, style: text.bodySmall),
                ],
              ),
            ),
            Icon(icon, size: 19, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
