import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Material primitives that must only ever be constructed inside
/// `lib/design_system`. Feature code reaches for the Memory component instead,
/// so that radius, type, colour, and touch target are decided once.
const _forbidden = <String>[
  'PopupMenuButton',
  'PopupMenuItem',
  'DropdownButton',
  'DropdownButtonFormField',
  'DropdownMenu',
  'DropdownMenuItem',
  'ListTile',
  'SwitchListTile',
  'CheckboxListTile',
  'RadioListTile',
  'Checkbox',
  'Switch',
  'Radio',
  'NavigationBar',
  'NavigationRail',
  'BottomNavigationBar',
  'TabBar',
  'TabBarView',
  'OutlinedButton',
  'FilledButton',
  'FloatingActionButton',
  'IconButton',
  'ElevatedButton',
  'TextButton',
  'CircularProgressIndicator',
  'LinearProgressIndicator',
  'SnackBar',
  'AlertDialog',
  'SimpleDialog',
  'CircleAvatar',
  'Chip',
  'ActionChip',
  'InputChip',
  'Slider',
  'Stepper',
  'ExpansionTile',
  'Drawer',
  'AppBar',
  'SliverAppBar',
  'TextField',
  'TextFormField',
  'SegmentedButton',
  'ToggleButtons',
  'DataTable',
  'CupertinoButton',
  'CupertinoAlertDialog',
  'CupertinoSwitch',
];

/// Where feature code lives. `lib/design_system` is deliberately excluded: it
/// is the one place these primitives are allowed, because wrapping them is
/// its entire job.
const _roots = ['lib/features', 'lib/media', 'lib/core', 'lib/realtime'];

/// Matches a constructor call, with or without type arguments.
///
/// `DropdownButtonFormField<CountryInfo>(` is a raw control just as much as
/// `DropdownButtonFormField(`. Two hand-written greps missed exactly that, and
/// reported zero when the answer was two.
RegExp _callTo(String name) =>
    RegExp('(?<![A-Za-z0-9_])$name(<[^<>()]*>)?\\s*\\(');

void main() {
  test('feature code constructs no raw Material control', () {
    final offenders = <String>[];

    for (final root in _roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();

        for (final name in _forbidden) {
          for (final match in _callTo(name).allMatches(source)) {
            final line =
                '\n'.allMatches(source.substring(0, match.start)).length + 1;
            final path = entity.path.replaceAll(r'\', '/');
            offenders.add('$name at $path:$line');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These belong in lib/design_system, behind a Memory component:\n'
          '  ${offenders.join('\n  ')}',
    );
  });

  test('the roots this test guards actually exist', () {
    // A typo in a path would make the test above pass by scanning nothing.
    expect(
      _roots.where((r) => Directory(r).existsSync()),
      hasLength(_roots.length),
    );
  });
}
