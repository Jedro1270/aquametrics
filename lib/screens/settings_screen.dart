import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/batch_store.dart';
import '../models/count_batch.dart';
import '../theme/app_theme.dart';
import '../widgets/count_widgets.dart';
import '../widgets/species_pills.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final BatchStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Species _defaultSpecies = widget.store.settings.defaultSpecies;
  late double _defaultSensitivity = widget.store.settings.defaultSensitivity;

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
                onChanged: (species) {
                  setState(() => _defaultSpecies = species);
                  _saveSettings();
                },
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            _Block(
              label: 'Default sensitivity',
              caption: 'Where the slider starts on a new count.',
              child: Slider(
                value: _defaultSensitivity,
                onChanged: (value) =>
                    setState(() => _defaultSensitivity = value),
                onChangeEnd: (_) => _saveSettings(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Group(
          title: 'Storage',
          children: [
            _TapRow(
              label: 'Export all counts',
              caption: 'CSV you can open in a spreadsheet.',
              icon: Icons.ios_share_rounded,
              onTap: _export,
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
                  'Counts stay on this phone. No account, no upload.',
                  style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: Text(
            'AquaMetrics 0.1.0  ·  Local database',
            style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
          ),
        ),
      ],
    );
  }

  Future<void> _saveSettings() async {
    await widget.store.updateSettings(
      AppSettings(
        defaultSpecies: _defaultSpecies,
        defaultSensitivity: _defaultSensitivity,
      ),
    );
  }

  Future<void> _export() async {
    if (widget.store.batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no counts to export yet.')),
      );
      return;
    }
    try {
      final bytes = Uint8List.fromList(utf8.encode(widget.store.exportCsv()));
      await SharePlus.instance.share(
        ShareParams(
          subject: 'AquaMetrics count history',
          files: [XFile.fromData(bytes, mimeType: 'text/csv')],
          fileNameOverrides: ['aquametrics-counts.csv'],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export count history.')),
      );
    }
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
