import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful main push CI deploys its exact head SHA automatically', () {
    final workflow = File(
      '.github/workflows/deploy-prod.yml',
    ).readAsStringSync();

    expect(workflow, contains('workflow_run:'));
    expect(workflow, contains('workflows: [CI]'));
    expect(workflow, contains('types: [completed]'));
    expect(
      workflow,
      contains("github.event.workflow_run.conclusion == 'success'"),
    );
    expect(workflow, contains("github.event.workflow_run.event == 'push'"));
    expect(
      workflow,
      contains("github.event.workflow_run.head_branch == 'main'"),
    );
    expect(workflow, contains('github.event.workflow_run.head_sha'));
  });

  test(
    'manual exact-SHA recovery and deployment ordering remain available',
    () {
      final workflow = File(
        '.github/workflows/deploy-prod.yml',
      ).readAsStringSync();

      expect(workflow, contains('workflow_dispatch:'));
      expect(workflow, contains('commit_sha:'));
      expect(workflow, contains('needs: deploy-supabase'));
      expect(workflow, contains('cancel-in-progress: false'));
    },
  );

  test('passes the selected exact SHA into the Railway image build', () {
    final workflow = File(
      '.github/workflows/deploy-prod.yml',
    ).readAsStringSync();

    expect(
      workflow,
      contains('BUILD_COMMIT_SHA="\$DEPLOY_REF"'),
      reason: 'The deployed artifact must identify the selected CI revision.',
    );
  });
}
