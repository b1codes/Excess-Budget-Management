import 'package:flutter/material.dart';
import 'package:frontend/core/theme/llc_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import '../fakes/fake_backend.dart';
import 'catalog_environment.dart';

/// One viewport per app breakpoint (see `core/breakpoints.dart`), so
/// adaptive layouts can be reviewed compact → medium → expanded.
const catalogViewports = [
  Viewports.none,
  IosViewports.iPhone13, // compact  (< 600)
  IosViewports.iPad, // medium   (600–1199)
  MacosViewports.macbookPro, // expanded (≥ 1200)
];

final _darkTheme = WidgetbookTheme(name: 'LLC Dark', data: LLCTheme.dark());
final _lightTheme = WidgetbookTheme(name: 'LLC Light', data: LLCTheme.light());

/// The addon stack shared by the app and the smoke tests.
///
/// Order matters: addons wrap outer → inner, so the viewport and theme sit
/// outside [CatalogEnvironmentAddon] (whose `MaterialApp.router` inherits
/// both), while alignment applies inside the routed page.
List<WidgetbookAddon> catalogAddons({
  BackendScenario initialScenario = BackendScenario.populated,
  List<ViewportData> viewports = catalogViewports,
}) => [
  ViewportAddon(viewports),
  MaterialThemeAddon(themes: [_darkTheme, _lightTheme]),
  TextScaleAddon(min: 1.0, max: 2.0, divisions: 4),
  InspectorAddon(),
  CatalogEnvironmentAddon(initialScenario: initialScenario),
  AlignmentAddon(),
];

/// Pads a component use case so it isn't glued to the viewport edge.
///
/// Height is left unbounded, matching the `ListView` / scroll view most of
/// these components live in; with a bounded height, cards whose `Column`
/// uses `MainAxisSize.max` would stretch to fill the whole viewport.
class ComponentFrame extends StatelessWidget {
  const ComponentFrame({super.key, this.maxWidth = 480, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return UnconstrainedBox(
      constrainedAxis: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Runs [onMount] once when inserted — used to dispatch the bloc event a
/// parent screen or route would normally fire before showing a widget.
/// Give it a key derived from knob values to re-run when they change.
class OnMount extends StatefulWidget {
  const OnMount({super.key, required this.onMount, required this.child});

  final void Function(BuildContext context) onMount;
  final Widget child;

  @override
  State<OnMount> createState() => _OnMountState();
}

class _OnMountState extends State<OnMount> {
  @override
  void initState() {
    super.initState();
    widget.onMount(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
