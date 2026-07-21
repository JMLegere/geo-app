import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '087_authored_variable_property_integrity.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  String functionBody(String sql, String functionName) => RegExp(
        'CREATE OR REPLACE FUNCTION public\\.$functionName'
        r'[\s\S]*?\$\$;',
        caseSensitive: false,
      ).firstMatch(sql)!.group(0)!;

  test('closes normalized Variable Property definition gaps without a rewrite',
      () {
    final sql = readMigration();
    final normalized = compact(sql).toLowerCase();

    expect(
      normalized,
      contains(
        'add constraint v3_item_property_values_exact_definition_assignment_fk '
        'foreign key (base_item_version_id, variable_property_key) '
        'references public.v3_base_item_version_variable_properties( '
        'base_item_version_id, variable_property_id )',
      ),
    );
    expect(
      normalized,
      contains('on update restrict on delete restrict'),
      reason:
          'Committed values must not survive a changed normalized assignment.',
    );

    for (final table in <String>[
      'public.v3_variable_properties',
      'public.v3_property_values',
      'public.v3_base_item_version_variable_properties',
    ]) {
      expect(
        RegExp('create table(?: if not exists)? ${RegExp.escape(table)}',
                caseSensitive: false)
            .hasMatch(sql),
        isFalse,
        reason:
            '087 must constrain the existing normalized $table model, not duplicate it.',
      );
    }
    expect(sql.toLowerCase(), isNot(contains('authored_content')));
    expect(RegExp(r'\bdrop\s+table\b', caseSensitive: false).hasMatch(sql),
        isFalse);
    expect(
        RegExp(r'\btruncate\b', caseSensitive: false).hasMatch(sql), isFalse);
    expect(RegExp(r'\bdelete\s+from\b', caseSensitive: false).hasMatch(sql),
        isFalse);
    expect(
      RegExp(r'\bupdate\s+public\.v3_(?:items|base_item_versions)\b',
              caseSensitive: false)
          .hasMatch(sql),
      isFalse,
    );
  });

  test('requires dense assignments and unconditional owned active selectors',
      () {
    final sql = readMigration();
    final selectorIntegrity = functionBody(
      sql,
      'v3_assert_variable_property_selector_integrity\\(',
    ).toLowerCase();
    final candidateOrdinals = functionBody(
      sql,
      'v3_assert_dense_selector_candidate_ordinals\\(',
    ).toLowerCase();
    final versionIntegrity = functionBody(
      sql,
      'v3_assert_base_item_version_variable_property_integrity\\(',
    ).toLowerCase();

    expect(candidateOrdinals, contains('count(*)'));
    expect(candidateOrdinals, contains('max(candidate.ordinal)'));
    expect(candidateOrdinals, contains('v_candidate_count = 0'));
    expect(
        candidateOrdinals, contains('v_max_ordinal <> v_candidate_count - 1'));

    expect(versionIntegrity, contains('max(assignment.ordinal)'));
    expect(versionIntegrity, contains('v_assignment_count <> 0'));
    expect(
      versionIntegrity,
      contains('v_assignment_max_ordinal <> v_assignment_count - 1'),
    );
    expect(versionIntegrity, contains('base_item.category'));
    expect(
      versionIntegrity,
      contains(
          'v_variable_property_category is distinct from v_base_item_category'),
    );

    expect(selectorIntegrity,
        contains("v_selector_result_type is distinct from 'property_value'"));
    expect(selectorIntegrity,
        contains("v_selector_status is distinct from 'active'"));
    expect(selectorIntegrity,
        contains('perform public.v3_assert_dense_selector_candidate_ordinals'));
    expect(selectorIntegrity, contains('candidate.condition_id is not null'));
    expect(
        selectorIntegrity,
        contains(
            'property_value.variable_property_id is distinct from p_variable_property_id'));
    expect(
      selectorIntegrity,
      contains("candidate.result_kind <> 'none'"),
      reason:
          'Explicit None is a valid candidate while every value must be owned.',
    );
  });

  test(
      'guards publication through a table trigger rather than trusting a caller',
      () {
    final sql = readMigration();
    final publicationGate = functionBody(
      sql,
      'v3_validate_base_item_version_variable_property_integrity\\(',
    ).toLowerCase();
    final normalized = compact(sql).toLowerCase();

    expect(publicationGate, contains("new.publication_status = 'published'"));
    expect(
        publicationGate,
        contains(
            'perform public.v3_assert_base_item_version_variable_property_integrity(new.id)'));
    expect(
      normalized,
      contains(
        'create trigger v3_base_item_versions_validate_variable_property_integrity '
        'before insert or update of publication_status on public.v3_base_item_versions '
        'for each row execute function public.v3_validate_base_item_version_variable_property_integrity()',
      ),
    );
    expect(publicationGate, isNot(contains('auth.uid()')));
    expect(
      normalized,
      contains('where publication_status in (\'published\', \'retired\')'),
      reason:
          'Existing immutable definitions are checked instead of bypassing the new gate.',
    );
  });

  test(
      'committed Property Values preserve exact assignment, selector, candidate, and explicit None',
      () {
    final sql = readMigration();
    final resolutionGate = functionBody(
      sql,
      'v3_validate_item_property_value_resolution\\(',
    ).toLowerCase();

    expect(
      RegExp(
        r'perform public\.v3_assert_base_item_version_variable_property_integrity\(\s*new\.base_item_version_id\s*\)',
      ).hasMatch(resolutionGate),
      isTrue,
    );
    expect(
      resolutionGate,
      contains('assignment.base_item_version_id = new.base_item_version_id'),
    );
    expect(
      resolutionGate,
      contains('assignment.variable_property_id = new.variable_property_key'),
    );
    expect(resolutionGate,
        contains('v_expected_selector_id is distinct from new.selector_id'));
    expect(resolutionGate,
        contains('candidate.selector_id = v_expected_selector_id'));
    expect(
        resolutionGate, contains('candidate.id = new.selector_candidate_id'));
    expect(resolutionGate, contains('v_candidate_condition_id is not null'));
    expect(resolutionGate, contains("if v_candidate_kind = 'none' then"));
    expect(resolutionGate,
        contains("new.resolution_kind is distinct from 'none'"));
    expect(resolutionGate, contains('new.resolved_value_id is not null'));
    expect(resolutionGate, contains("elsif v_candidate_kind = 'value' then"));
    expect(
      resolutionGate,
      contains(
          'v_candidate_value_property_id is distinct from v_variable_property_id'),
    );
  });

  test('keeps every 087 helper private from client roles', () {
    final normalized = compact(readMigration()).toLowerCase();

    for (final signature in <String>[
      'v3_assert_dense_selector_candidate_ordinals(text)',
      'v3_assert_variable_property_selector_integrity(text)',
      'v3_assert_base_item_version_variable_property_integrity(uuid)',
      'v3_validate_base_item_version_variable_property_integrity()',
      'v3_validate_item_property_value_resolution()',
    ]) {
      expect(
        normalized,
        contains(
            'revoke all on function public.$signature from public, anon, authenticated'),
      );
    }
  });
}
