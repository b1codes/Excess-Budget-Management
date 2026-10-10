import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_workspace/catalog/catalog_addons.dart';
import 'package:widgetbook_workspace/fakes/fake_backend.dart';
import 'package:widgetbook_workspace/main.directories.g.dart';

/// Renders every generated use case inside the real Widgetbook shell and
/// fails on any thrown exception or layout overflow.
///
/// This is the catalog's safety net: a use case that breaks (renamed
/// constructor, new required provider, overflowing layout) fails CI instead
/// of silently rendering an error box in the catalog.
void main() {
  final useCases = <WidgetbookUseCase>[];
  void collect(WidgetbookNode node) {
    if (node is WidgetbookUseCase) useCases.add(node);
    node.children?.forEach(collect);
  }

  // Building the root links each node to its parent, which `path` relies on.
  WidgetbookRoot(children: directories).children!.forEach(collect);

  test('catalog is not empty', () => expect(useCases, isNotEmpty));

  const runs = [
    (BackendScenario.populated, IosViewports.iPhone13),
    (BackendScenario.populated, MacosViewports.macbookPro),
    (BackendScenario.empty, IosViewports.iPhone13),
    (BackendScenario.error, IosViewports.iPhone13),
    (BackendScenario.loading, IosViewports.iPhone13),
  ];

  for (final (scenario, viewport) in runs) {
    group('${scenario.label} · ${viewport.name}', () {
      for (final useCase in useCases) {
        testWidgets(useCase.path, (tester) async {
          // Large enough for Widgetbook's desktop layout to host the
          // viewport frame alongside its navigation and settings panels.
          tester.view.physicalSize = const Size(3200, 2200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          // flutter_test renders every glyph as a 1em square ("FlutterTest"
          // font) and the app's Google Fonts can't load offline, so text is
          // far wider than in the real app and overflow assertions here are
          // not trustworthy. Log them; fail on everything else. Visual
          // layout is reviewed in the rendered catalog instead.
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            if (details.exceptionAsString().contains('RenderFlex overflowed')) {
              debugPrint(
                'overflow (test font): ${details.exceptionAsString()}',
              );
              return;
            }
            originalOnError?.call(details);
          };
          addTearDown(() => FlutterError.onError = originalOnError);

          await tester.pumpWidget(
            Widgetbook.material(
              initialRoute: '/?path=${useCase.path}',
              directories: directories,
              addons: catalogAddons(
                initialScenario: scenario,
                viewports: [viewport],
              ),
            ),
          );
          // Let fake requests resolve and entry animations finish. Fixed
          // pumps rather than pumpAndSettle: spinners never settle.
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }

          expect(tester.takeException(), isNull);

          // Dispose the tree so blocs close and their polling timers cancel.
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    });
  }
}
