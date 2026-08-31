import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only local and prod are active execution environments', () {
    expect(File('.github/workflows/deploy-beta.yml').existsSync(), isFalse);
    expect(
        File('.github/workflows/deploy-production.yml').existsSync(), isFalse);
    expect(File('scripts/clone_prod_to_beta.py').existsSync(), isFalse);
    expect(File('scripts/seed_beta_remaining.py').existsSync(), isFalse);
    expect(
      File('scripts/import_cell_geometry_artifact.py').readAsStringSync(),
      isNot(contains('BETA_DB_URL')),
    );

    final workflow =
        File('.github/workflows/deploy-prod.yml').readAsStringSync();
    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, isNot(contains('workflow_run:')));
    expect(workflow, contains('environment_name: prod'));
    expect(workflow, contains('needs: deploy-supabase'));
    expect(workflow, contains('DEPLOYMENT_ENVIRONMENT=prod'));
    expect(workflow, contains('--environment production'));
    final dockerfile = File('Dockerfile').readAsStringSync();
    expect(
      dockerfile,
      contains('"--dart-define=DEPLOYMENT_ENVIRONMENT=prod"'),
    );
    expect(
      dockerfile,
      contains('"--dart-define=DESKTOP_CONTROLS_AVAILABLE=true"'),
    );
    expect(
      dockerfile,
      contains('"--dart-define=DESKTOP_CONTROLS_DEFAULT=true"'),
    );
    final supabaseWorkflow =
        File('.github/workflows/deploy-supabase.yml').readAsStringSync();
    expect(
      supabaseWorkflow,
      contains('SUPABASE_DB_PASSWORD:\n        required: true'),
    );
    expect(supabaseWorkflow, isNot(contains('Skip migrations')));

    final launcher = File('mise.toml').readAsStringSync();
    expect(launcher, contains('[tasks."desktop:local"]'));
    expect(launcher, contains('--dart-define-from-file=.env.local'));
    expect(launcher, isNot(contains('desktop:prod')));

    final localExample = File('.env.local.example').readAsStringSync();
    expect(localExample, contains('DEPLOYMENT_ENVIRONMENT=local'));
    expect(localExample, contains('gameplay changes production data'));
  });
}
