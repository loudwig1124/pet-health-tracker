/// Structural guard: SQL stays in the data layer, and only `lib/data/**` (the
/// SQLite repositories/seed) plus the composition root may import the sqflite
/// plugin.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no SQL text exists outside lib/data', () {
    const List<String> markers = <String>[
      'SELECT ',
      'INSERT INTO',
      'DELETE FROM',
      'CREATE TABLE',
      'PRAGMA ',
    ];
    final List<String> offenders = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (entity.path.startsWith('lib/data/')) {
        continue;
      }
      final String source = entity.readAsStringSync();
      for (final String marker in markers) {
        if (source.contains(marker)) {
          offenders.add('${entity.path} contains "$marker"');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('only lib/data and lib/app/di.dart import sqflite', () {
    final List<String> offenders = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String source = entity.readAsStringSync();
      if (!source.contains('package:sqflite/')) {
        continue;
      }
      final bool allowed =
          entity.path.startsWith('lib/data/') ||
          entity.path == 'lib/app/di.dart';
      if (!allowed) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('lib/domain stays pure Dart', () {
    final List<String> banned = <String>[
      'package:flutter/',
      'package:sqflite',
      'dart:io',
      'dart:ui',
      'rootBundle',
    ];
    final List<String> offenders = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib/domain',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String source = entity.readAsStringSync();
      for (final String marker in banned) {
        if (source.contains(marker)) {
          offenders.add('${entity.path} imports/uses $marker');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
