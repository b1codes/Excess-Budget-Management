# Widgetbook catalog

Interactive catalog of every UI component and screen in `frontend/`, built
with [Widgetbook](https://docs.widgetbook.io). Use it to browse components
in isolation, try them out with knobs, review adaptive layouts at each
breakpoint, and as the base for visual regression testing.

It is a separate Flutter package with a path dependency on `frontend`, so
Widgetbook, its generator and the fake data never ship in the app.

## Running

```bash
cd frontend/widgetbook
flutter pub get
dart run build_runner build      # regenerate lib/main.directories.g.dart
flutter run -d chrome            # or -d macos
```

Release web build (e.g. for hosting or Widgetbook Cloud):

```bash
flutter build web --release --no-tree-shake-icons
```

`--no-tree-shake-icons` is required because budget categories build
`IconData` from stored code points at runtime, so icon tree shaking can't
see which glyphs are used. The main app's release builds have the same
constraint.

## Layout

```
lib/
├── main.dart                  # @App entry point
├── main.directories.g.dart    # generated navigation tree — do not edit
├── catalog/
│   ├── catalog_addons.dart    # addon stack, viewports, ComponentFrame, OnMount
│   └── catalog_environment.dart  # providers + sandbox router per use case
├── fakes/
│   ├── fake_backend.dart      # Dio interceptor serving the REST API in memory
│   └── fixtures.dart          # deterministic sample data (JSON + models)
└── use_cases/
    ├── core/                  # theme tokens, glass, glow, layout widgets
    └── features/              # one file per feature: accounts, auth, …
test/
└── use_cases_smoke_test.dart  # renders every use case in every scenario
```

The navigation tree mirrors `frontend/lib` (it is derived from each
component's source location), not the layout of `use_cases/`.

## How it works

**Real code, fake transport.** `createFakeApiClient` builds a real
`ApiClient` whose Dio has a `FakeBackend` interceptor in front of the
network. All repositories, blocs and screens run unmodified, including
screens that construct their own repositories from
`context.read<ApiClient>()`. Writes (add/edit/delete, allocations,
subgoal updates) persist in memory for the life of the use case.

**Per-use-case environment.** `CatalogEnvironmentAddon` wraps every use
case in the same provider tree as `main.dart` (repositories, `AuthBloc`,
`AccountBloc`, `BudgetBloc`, `DashboardBloc`), a `MaterialApp.router`
inheriting the selected theme, and `MeshBackdrop`. Navigation calls land on
a stub page that shows the destination. Each use case and scenario gets a
fresh environment, so state never leaks between catalog entries.

**Addons** (settings panel → *Addons*):

| Addon      | Purpose                                                    |
| ---------- | ---------------------------------------------------------- |
| Viewport   | iPhone 13 / iPad / MacBook Pro — compact, medium, expanded |
| Theme      | `LLCTheme.dark()` / `LLCTheme.light()`                     |
| Text scale | 1.0×–2.0× accessibility scaling                            |
| Inspector  | Tap to inspect widgets                                     |
| Backend    | Populated · Empty · Loading · Error                        |
| Alignment  | Position component use cases                               |

## Adding a use case

1. Add a top-level function to the matching file in `lib/use_cases/`:

   ```dart
   @widgetbook.UseCase(name: 'Default', type: MyWidget)
   Widget myWidgetDefault(BuildContext context) {
     return ComponentFrame(
       child: MyWidget(label: context.knobs.string(label: 'Label')),
     );
   }
   ```

2. Run `dart run build_runner build`.
3. Run `flutter test`. The smoke test picks the new use case up
   automatically.

Conventions:

- Wrap standalone components in `ComponentFrame` (padding, max width,
  list-like unbounded height). Screens render bare.
- Use `Fixtures` for sample data rather than inline literals, so data stays
  consistent across use cases and stable for screenshots.
- If a widget needs a bloc its parent screen or route normally provides,
  create it in the use case (see `bulkExpenseTab`, `overtimeScreen`).
- If it relies on account/budget lists that another tab would have loaded,
  wrap it in `PreloadAppData`. Only preload what the widget doesn't load
  itself: overlapping loads race inside `AccountBloc`/`BudgetBloc`.
- To render a state that a bloc event produces, dispatch the event with
  `OnMount`, keyed on the knob values (see `overviewTab`).

## Testing & visual regression

`flutter test` pumps every use case inside the real Widgetbook shell for
Populated (compact and expanded), Empty, Error and Loading, and fails on any
exception. `RenderFlex` overflows are logged rather than failed:
`flutter_test` draws each glyph as a 1em square and can't load the app's
Google Fonts, so text-width overflows there don't reflect the real app.

For pixel-level visual regression, connect the repo to
[Widgetbook Cloud](https://docs.widgetbook.io/cloud). It snapshots each use
case from the web build (`--no-tree-shake-icons`) on every PR. All fixture
dates are pinned to `Fixtures.fixtureNow`, so snapshots are deterministic.
The exception is bulk-entry rows, which default to `DateTime.now()` in the
app's blocs.

## Telemetry

`build.yaml` disables `widgetbook_generator`'s telemetry. It would
otherwise report a hash of your git email, the repo's root commit SHA and
its remote URL to Widgetbook.
