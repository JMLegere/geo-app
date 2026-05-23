import 'dart:io';

import 'package:earth_nova/shared/design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('design component registry', () {
    test('matches the public design widget taxonomy', () {
      final exportedNames = _exportedTaxonomyWidgetNames();
      final registeredNames =
          designComponentRegistry.map((component) => component.name).toSet();

      expect(registeredNames, exportedNames);
      expect(publicDesignComponentNames.toSet(), exportedNames);
    });

    test('keeps every component in a formal taxonomy category', () {
      expect(designTaxonomy[DesignComponentCategory.primitive], isNotEmpty);
      expect(designTaxonomy[DesignComponentCategory.composite], isNotEmpty);
      expect(designTaxonomy[DesignComponentCategory.pattern], isNotEmpty);

      for (final component in designComponentRegistry) {
        expect(
          designTaxonomy[component.category],
          contains(component),
          reason: '${component.name} must appear under its taxonomy bucket.',
        );
      }
    });

    test('documents route/screen usage policy for every component', () {
      final names = <String>{};

      for (final component in designComponentRegistry) {
        expect(component.name, isNotEmpty);
        expect(component.purpose, isNotEmpty);
        expect(names.add(component.name), isTrue,
            reason: '${component.name} is duplicated.');

        if (component.category == DesignComponentCategory.pattern) {
          expect(
            component.allowedInScreens,
            isFalse,
            reason:
                '${component.name} is a catalog/pattern artifact and should not be used directly in app screens.',
          );
        }
      }
    });
  });
}

Set<String> _exportedTaxonomyWidgetNames() {
  const taxonomyDirs = ['primitives', 'composites', 'patterns'];
  final names = <String>{};

  for (final dir in taxonomyDirs) {
    final directory = Directory('lib/shared/design/$dir');
    expect(directory.existsSync(), isTrue,
        reason: '${directory.path} must exist.');

    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.uri.pathSegments.last == 'index.dart') continue;

      final source = entity.readAsStringSync();
      final matches = RegExp(
        r'class\s+([A-Z][A-Za-z0-9]*)\s+extends\s+(?:StatelessWidget|StatefulWidget)',
      ).allMatches(source);
      names.addAll(matches.map((match) => match.group(1)!));
    }
  }

  return names;
}
