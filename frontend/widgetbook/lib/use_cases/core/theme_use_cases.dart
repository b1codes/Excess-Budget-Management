import 'package:flutter/material.dart';
import 'package:frontend/core/theme/llc_theme.dart';
import 'package:frontend/core/theme/mesh_backdrop.dart';
import 'package:frontend/core/theme/refractive_glass.dart';
import 'package:frontend/core/theme/thermal_glow.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../../catalog/catalog_addons.dart';

@widgetbook.UseCase(name: 'Playground', type: RefractiveGlass)
Widget refractiveGlassPlayground(BuildContext context) {
  return ComponentFrame(
    child: RefractiveGlass(
      borderRadius: context.knobs.double.slider(
        label: 'Border radius',
        initialValue: 16,
        max: 40,
      ),
      blurSigma: context.knobs.double.slider(
        label: 'Blur sigma',
        initialValue: 20,
        max: 40,
      ),
      fillOpacity: context.knobs.double.slider(
        label: 'Fill opacity',
        description: 'branding.md clamps glass fill to 0.05–0.15.',
        initialValue: 0.1,
        min: 0.05,
        max: 0.15,
        precision: 2,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.knobs.string(
            label: 'Content',
            initialValue: 'Refractive glass surface',
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Tappable card', type: ThermalGlow)
Widget thermalGlowCard(BuildContext context) {
  final hasTap = context.knobs.boolean(label: 'Enabled', initialValue: true);
  return ComponentFrame(
    child: ThermalGlow(
      borderRadius: context.knobs.double.slider(
        label: 'Border radius',
        initialValue: 16,
        max: 40,
      ),
      onTap: hasTap ? () {} : null,
      child: const RefractiveGlass(
        child: ListTile(
          leading: Icon(Icons.touch_app),
          title: Text('Press and hold'),
          subtitle: Text('Glow excites from the contact point, then cools.'),
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Ambient surface', type: MeshBackdrop)
Widget meshBackdropSurface(BuildContext context) {
  return SizedBox.expand(
    child: MeshBackdrop(
      child: Center(
        child: context.knobs.boolean(label: 'Show glass panel')
            ? const RefractiveGlass(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Glass over mesh'),
                ),
              )
            : const SizedBox.shrink(),
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Color tokens', type: LLCColors)
Widget llcColorTokens(BuildContext context) {
  const tokens = <(String, Color)>[
    ('voidBlack', LLCColors.voidBlack),
    ('panelElevated', LLCColors.panelElevated),
    ('mist', LLCColors.mist),
    ('mistElevated', LLCColors.mistElevated),
    ('chromeWhite', LLCColors.chromeWhite),
    ('steelGray', LLCColors.steelGray),
    ('graphite', LLCColors.graphite),
    ('graphiteSoft', LLCColors.graphiteSoft),
    ('glassFillDark', LLCColors.glassFillDark),
    ('glassBorderDark', LLCColors.glassBorderDark),
    ('glassFillLight', LLCColors.glassFillLight),
    ('glassBorderLight', LLCColors.glassBorderLight),
    ('thermalCore', LLCColors.thermalCore),
    ('thermalCorona', LLCColors.thermalCorona),
    ('instrumentCyan', LLCColors.instrumentCyan),
    ('instrumentCyanDeep', LLCColors.instrumentCyanDeep),
    ('affirmMint', LLCColors.affirmMint),
    ('affirmMintDeep', LLCColors.affirmMintDeep),
  ];
  final textTheme = Theme.of(context).textTheme;
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final (name, color) in tokens)
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LLCColors.steelGray),
                  ),
                ),
                const SizedBox(height: 6),
                Text(name, style: textTheme.labelLarge),
                Text(
                  '#${color.toARGB32().toRadixString(16).toUpperCase()}',
                  style: textTheme.labelSmall,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

@widgetbook.UseCase(name: 'Typography & color scheme', type: LLCTheme)
Widget llcThemeSpecimen(BuildContext context) {
  final theme = Theme.of(context);
  final t = theme.textTheme;
  final styles = <(String, TextStyle?)>[
    ('displayMedium', t.displayMedium),
    ('headlineMedium', t.headlineMedium),
    ('headlineSmall', t.headlineSmall),
    ('titleLarge', t.titleLarge),
    ('titleMedium', t.titleMedium),
    ('bodyLarge', t.bodyLarge),
    ('bodyMedium', t.bodyMedium),
    ('labelLarge', t.labelLarge),
    ('labelSmall', t.labelSmall),
  ];
  final scheme = theme.colorScheme;
  final roles = <(String, Color, Color)>[
    ('primary', scheme.primary, scheme.onPrimary),
    ('secondary', scheme.secondary, scheme.onSecondary),
    ('tertiary', scheme.tertiary, scheme.onTertiary),
    ('error', scheme.error, scheme.onError),
    ('surface', scheme.surface, scheme.onSurface),
    (
      'surfaceContainerHighest',
      scheme.surfaceContainerHighest,
      scheme.onSurfaceVariant,
    ),
  ];
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, style) in styles)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('$name · \$12,480.00', style: style),
          ),
        const Divider(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (name, bg, fg) in roles)
              Container(
                width: 200,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(name, style: TextStyle(color: fg)),
              ),
          ],
        ),
        const Divider(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(onPressed: () {}, child: const Text('Filled')),
            ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
            OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
            TextButton(onPressed: () {}, child: const Text('Text')),
            const SizedBox(
              width: 240,
              child: TextField(
                decoration: InputDecoration(labelText: 'Text field'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
