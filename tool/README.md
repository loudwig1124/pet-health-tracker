# tool/ — sandbox-runnable Flutter toolchain

`Pet Health Tracker/` is the Flutter app root. The machine's system Flutter at
`/opt/homebrew/share/flutter` **cannot be used from this sandbox**: the tool must
write `bin/cache/lockfile`, artifacts and pub state, which the sandbox blocks
outside the workspace, and the repo path contains parentheses (`School Project
(AppDev)`) which trips a Flutter 3.47.5 `otool` parser bug on `flutter test`.

This directory holds a thin wrapper. The heavy SDK copy is **not duplicated**:
`.flutter-sdk` is a relative symlink to the sibling
`Final Project/.flutter-sdk` (a workspace-local copy of the Homebrew SDK carrying
the one-line patch documented below).

## Files

| Path | Purpose |
| --- | --- |
| `tool/fv` | Wrapper: runs `.flutter-sdk/bin/flutter` (through the symlink) with sandbox-contained caches. Falls back to `flutter` on `PATH` when the local SDK is absent (e.g. a normal developer machine). |
| `tool/format` | `dart format` wrapper with the same sandbox HOME/PUB_CACHE redirection (`./tool/format lib test`). |
| `.flutter-sdk` → `../Final Project/.flutter-sdk` | Symlink to the verbatim SDK copy with the local patch. Gitignored. **Never copy the 4 GB SDK into this project.** |
| `.pub-cache` → `../Final Project/.pub-cache` | Symlink to the workspace pub cache (pub's global cache by design). Gitignored. |
| `.tool-home/` | `HOME` for the tool so analytics/analyzer state stays inside the workspace; holds `enable-native-assets: true` for `sqlite3`'s build hook. Gitignored. Never delete it. |

`tool/fv` sets `FLUTTER_SUPPRESS_ANALYTICS=true`, `PUB_CACHE=<repo>/.pub-cache`
and `HOME=<repo>/.tool-home` only when `.pub-cache/` exists, so on a normal
developer machine it is a plain passthrough to the local SDK (or system
`flutter`).

## Recorded versions (2026-11-21)

- Flutter **3.47.5** stable, revision `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`
- Dart **3.13.4**, DevTools 2.60.0, engine `af7e796e16`
- Packages resolved from `.pub-cache`: `go_router 18.1.4`, `sqflite 2.4.6`,
  `sqflite_common_ffi 2.4.7`, `sqlite3 3.5.2`, `intl 0.20.3`, `path 1.9.1`.
  `pub get` runs the `sqlite3` build hook, which downloads a prebuilt
  `libsqlite3.dylib` into `.dart_tool/hooks_runner/` (workspace-local).

## Commands

```bash
cd "Pet Health Tracker"
./tool/fv --version
./tool/fv pub get
./tool/fv analyze
./tool/fv test
./tool/format --set-exit-if-changed lib test
sqlite3 :memory: ".read db/schema.sql"
```

## Local patch in the SDK copy (required for `flutter test` here)

The repo path contains parentheses: `.../School Project (AppDev)/Pet Health
Tracker`. Flutter 3.47.5's `parseOtoolArchitectureSections`
(`packages/flutter_tools/lib/src/isolated/native_assets/macos/native_assets_host.dart`)
parses `otool` output with `^[^(]+( \(architecture (.+)\))?:$`; the `[^(]+` path
part cannot match a path containing `(`, so the `.dylib` header line falls into
the content branch and `flutter test` dies with
`Oops; flutter has exited unexpectedly: "Null check operator used on a null value"`
(the native-assets copy step for `flutter_tester`). Route:
`copyNativeCodeAssetsMacOSFlutterTester` → `getInstallNamesDylib` →
`parseOtoolArchitectureSections`.

The one-line patch applied to the sibling SDK copy:

```dart
// before
final architectureHeaderPattern = RegExp(r'^[^(]+( \(architecture (.+)\))?:$');
// after (same capture groups: 1 = " (architecture x)", 2 = "x")
final architectureHeaderPattern = RegExp(r'^.+?( \(architecture (.+)\))?:$');
```

`bin/cache/flutter_tools.snapshot` was rebuilt from the patched source, and the
unpatched snapshot is kept as `bin/cache/flutter_tools.snapshot.orig`. The full
recipe (and the rebuild command) lives in
`Final Project/tool/README.md`. This patch is sandbox plumbing, not app code: the
app itself does not depend on it.

## Hand-off to another machine

1. Run a normal `flutter pub get` / `flutter test` there (the patch is only needed
   on a parenthesised checkout).
2. If the checkout path contains `(`, apply the same one-line patch to that
   machine's SDK and rebuild the snapshot (recipe above), or move/rename the
   checkout **before** opening a session.
3. Keep `.flutter-sdk` (or its symlink), `.pub-cache` and `.tool-home` out of
   version control; they exist only because this sandbox blocks writes outside
   the workspace.
