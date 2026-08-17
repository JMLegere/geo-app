import 'dart:convert';
import 'dart:io';

import 'package:earth_nova/shared/design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('native EAC design contracts', () {
    test('match the shared design registry for public design components', () {
      final sharedDesignContracts = _nativeContracts()
          .where((contract) => contract.publicApi == 'lib/shared/design.dart')
          .where((contract) =>
              const {'Atom', 'Molecule', 'Organism'}.contains(contract.kind))
          .toList();

      final contractNames =
          sharedDesignContracts.map((contract) => contract.name).toSet();
      final registryNames =
          designComponentRegistry.map((component) => component.name).toSet();

      expect(
        contractNames,
        registryNames,
        reason:
            'Every public shared design registry component must have exactly one native EAC atom/molecule/organism contract.',
      );

      for (final component in designComponentRegistry) {
        final contract = sharedDesignContracts.singleWhere(
          (candidate) => candidate.name == component.name,
        );

        expect(
          _categoryFor(contract.kind),
          component.category,
          reason:
              '${component.name} native contract kind must match the Dart design registry category.',
        );
        expect(
          _statusFor(contract.status),
          component.status,
          reason:
              '${component.name} native contract status must match the Dart design registry status.',
        );
        expect(File(contract.exports).existsSync(), isTrue,
            reason:
                '${contract.name} exports ${contract.exports}, but it does not exist.');
      }
    });

    test('covers the app-level migrated product surfaces', () {
      const requiredSurfaceContracts = <String, ({String path, String kind})>{
        'PrimaryNavigationShell': (
          path: 'lib/shared/widgets/tab_shell.dart',
          kind: 'Template'
        ),
        'ExplorationMapRoot': (
          path: 'lib/features/map/presentation/screens/map_root_screen.dart',
          kind: 'Template',
        ),
        'ExplorationMap': (
          path: 'lib/features/map/presentation/screens/map_screen.dart',
          kind: 'Page',
        ),
        'PlayerPack': (
          path: 'lib/features/pack/presentation/screens/pack_screen.dart',
          kind: 'Page',
        ),
        'TownDirectory': (
          path:
              'lib/features/living_world/presentation/screens/town_screen.dart',
          kind: 'Page',
        ),
        'VenueDetail': (
          path:
              'lib/features/living_world/presentation/screens/venue_detail_screen.dart',
          kind: 'Page',
        ),
        'PlayerSettings': (
          path:
              'lib/features/profile/presentation/screens/settings_screen.dart',
          kind: 'Page',
        ),
        'HomeIdentity': (
          path: 'lib/features/home/presentation/screens/home_screen.dart',
          kind: 'Page',
        ),
        'TerritoryHierarchyHeader': (
          path: 'lib/features/map/presentation/widgets/hierarchy_header.dart',
          kind: 'Molecule',
        ),
        'MapCellDetailSheet': (
          path: 'lib/features/map/presentation/widgets/cell_detail_sheet.dart',
          kind: 'Molecule',
        ),
      };

      final contractsByName = {
        for (final contract in _nativeContracts()) contract.name: contract,
      };

      for (final entry in requiredSurfaceContracts.entries) {
        final expected = entry.value;
        final contract = contractsByName[entry.key];
        expect(contract, isNotNull,
            reason:
                '${entry.key} needs a native EAC product-surface contract.');
        expect(contract!.exports, expected.path);
        expect(File(contract.exports).existsSync(), isTrue);
        expect(contract.kind, expected.kind,
            reason:
                '${entry.key} should be modeled with product-facing Atomic Design language.');
        expect(contract.interactionPolicy, isNotEmpty,
            reason: '${entry.key} must declare an interaction policy.');
      }
    });
    test('ui-action evidence is anchored to native design exports', () {
      final controls = _collectUiActionEvidence();
      final contractsByExport = {
        for (final contract in _nativeContracts()) contract.exports: contract,
      };

      final offenders = <String>[];

      for (final control in controls) {
        final source = control['source'] as String;
        final component = control['component'] as String;
        final controlComponent = control['controlComponent'] as String;
        final line = control['line'] as int;
        final contract = contractsByExport[source];

        if (contract == null) {
          offenders.add(
            '$source:$line has UI-action evidence but no native design contract exports that source file.',
          );
          continue;
        }

        if (controlComponent == 'EarthActionButton') {
          expect(
            component,
            'EarthActionButton',
            reason:
                '$source:$line EarthActionButton evidence should remain anchored to the shared atom.',
          );
          continue;
        }

        if (component != contract.name) {
          offenders.add(
            '$source:$line $controlComponent evidence reports component "$component", but native contract export maps that file to "${contract.name}".',
          );
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'The collector should derive feature/page/template/molecule evidence components from native contract Exports, not a separate Dart surface-name map.',
      );
    });
    test('action-required product surfaces emit native UI-action evidence', () {
      final evidencedComponents = _collectUiActionEvidence()
          .map((control) => control['component'] as String)
          .toSet();
      final missing = <String>[];

      for (final contract in _nativeContracts()) {
        if (contract.exports.startsWith('lib/shared/design/') ||
            contract.exports.startsWith('lib/shared/product/')) {
          continue;
        }
        if (contract.interactionPolicy != 'action-required') continue;
        if (!evidencedComponents.contains(contract.name)) {
          missing.add(
            '${contract.name} (${contract.path}) declares action-required but has no collected UI-action evidence.',
          );
        }
      }

      expect(
        missing,
        isEmpty,
        reason:
            'App-level action-required native design contracts must be visible in the generated EAC UI-action evidence.',
      );
    });

    test('defines canonical Map Cell knowledge disclosure', () {
      final contracts = {
        for (final contract in _nativeContracts()) contract.name: contract,
      };
      final map = contracts['ExplorationMap']!;
      final sheet = contracts['MapCellDetailSheet']!;

      expect(map.interactionPolicy, 'action-required');
      expect(
        map.purpose,
        contains('exactly Shrouded, Informed, Explored, and Present'),
      );
      expect(map.purpose, contains('static native fog legend'));
      expect(
          map.purpose, contains('Present requires trusted physical occupancy'));
      expect(map.purpose, contains('paused banner is a semantic status'));
      expect(map.purpose, contains('legacy hasLoot never adds a star'));

      expect(sheet.interactionPolicy, 'action-required');
      expect(sheet.purpose, contains('inspect-map-cell'));
      expect(sheet.purpose, contains('Informed discloses only one category'));
      expect(
        sheet.purpose,
        contains(
            'never an exact Encounter, fauna identity, Outcome, or reward'),
      );
    });

    test('requires explicit interaction policy on every native contract', () {
      for (final contract in _nativeContracts()) {
        expect(contract.status, isNotEmpty,
            reason: '${contract.path} must declare Status.');
        expect(contract.role, isNotEmpty,
            reason: '${contract.path} must declare Role.');
        expect(contract.interactionPolicy, isNotEmpty,
            reason: '${contract.path} must declare Interaction policy.');
        expect(contract.purpose, isNotEmpty,
            reason: '${contract.path} must include a Purpose block.');
      }
    });
  });
}

List<Map<String, Object?>> _collectUiActionEvidence() {
  final collector = Process.runSync(
    'dart',
    ['run', 'tool/eac_collect_ui_actions.dart'],
  );

  expect(
    collector.exitCode,
    0,
    reason:
        'The UI-action collector must run before validating native evidence. stdout: ${collector.stdout} stderr: ${collector.stderr}',
  );

  final evidence = jsonDecode(
    File('artifacts/eac/ui-actions.json').readAsStringSync(),
  ) as Map<String, Object?>;

  return (evidence['controls'] as List<Object?>)
      .map((control) =>
          (control as Map<Object?, Object?>).cast<String, Object?>())
      .toList(growable: false);
}

List<_NativeDesignContract> _nativeContracts() {
  final root = Directory('product/design');
  expect(root.existsSync(), isTrue, reason: 'product/design must exist.');

  final contractFiles = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => RegExp(r'\.(atom|molecule|organism|template|page)$')
          .hasMatch(file.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  expect(contractFiles, isNotEmpty,
      reason: 'Native EAC design contracts must be checked in.');

  return contractFiles.map(_parseNativeContract).toList(growable: false);
}

_NativeDesignContract _parseNativeContract(File file) {
  final source = file.readAsStringSync();
  final header = RegExp(r'^(Atom|Molecule|Organism|Template|Page):\s*(.+)$',
          multiLine: true)
      .firstMatch(source);

  expect(header, isNotNull,
      reason:
          '${file.path} must start with Atom/Molecule/Organism/Template/Page.');

  return _NativeDesignContract(
    path: file.path.replaceAll(Platform.pathSeparator, '/'),
    kind: header!.group(1)!,
    name: header.group(2)!.trim(),
    status: _field(source, 'Status'),
    role: _field(source, 'Role'),
    interactionPolicy: _field(source, 'Interaction policy'),
    exports: _field(source, 'Exports'),
    publicApi: _field(source, 'Public API'),
    purpose: _purpose(source),
  );
}

String _field(String source, String field) {
  final match = RegExp('^${RegExp.escape(field)}:\\s*(.+)\$', multiLine: true)
      .firstMatch(source);
  return match?.group(1)?.trim() ?? '';
}

String _purpose(String source) {
  final marker = RegExp(r'^Purpose:\s*$', multiLine: true).firstMatch(source);
  if (marker == null) return '';
  return source.substring(marker.end).trim();
}

DesignComponentCategory _categoryFor(String kind) => switch (kind) {
      'Atom' => DesignComponentCategory.primitive,
      'Molecule' => DesignComponentCategory.composite,
      'Organism' => DesignComponentCategory.pattern,
      _ => throw ArgumentError.value(
          kind, 'kind', 'Not a registry component kind'),
    };

DesignComponentStatus _statusFor(String status) => switch (status) {
      'canonical' => DesignComponentStatus.canonical,
      'experimental' => DesignComponentStatus.experimental,
      'deprecated' => DesignComponentStatus.deprecated,
      _ =>
        throw ArgumentError.value(status, 'status', 'Unknown contract status'),
    };

class _NativeDesignContract {
  const _NativeDesignContract({
    required this.path,
    required this.kind,
    required this.name,
    required this.status,
    required this.role,
    required this.interactionPolicy,
    required this.exports,
    required this.publicApi,
    required this.purpose,
  });

  final String path;
  final String kind;
  final String name;
  final String status;
  final String role;
  final String interactionPolicy;
  final String exports;
  final String publicApi;
  final String purpose;
}
