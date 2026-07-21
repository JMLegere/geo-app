import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '097_home_item_category_foundation.sql',
  );
  final versionedContentFoundation = File(
    '${Directory.current.path}/supabase/migrations/'
    '076_versioned_content_foundation.sql',
  );

  String sql() => migration.readAsStringSync().toLowerCase();
  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test('creates exactly one immutable Home identity per public Player profile',
      () {
    expect(migration.existsSync(), isTrue);
    final normalized = compact(sql());

    expect(
      normalized,
      contains(
        'create table if not exists public.v3_player_homes ( id uuid primary key default gen_random_uuid(), user_id uuid not null unique references public.v3_profiles(id)',
      ),
    );
    expect(
        normalized, contains('created_at timestamptz not null default now()'));
    expect(normalized, contains('home state is immutable'));
    expect(
      normalized,
      contains(
        'create trigger v3_player_homes_prevent_mutation before update or delete on public.v3_player_homes',
      ),
    );
    expect(normalized, isNot(contains('home_modules')));
    expect(normalized, isNot(contains('home_module')));
    expect(normalized, isNot(contains('module_kind')));
    expect(normalized, isNot(contains('placement')));
  });

  test(
      'automatically creates Homes for new profiles and backfills existing profiles',
      () {
    final normalized = compact(sql());

    expect(
      normalized,
      contains(
        'create or replace function public.create_v3_home_for_profile() returns trigger language plpgsql security definer set search_path = public',
      ),
    );
    expect(
      normalized,
      contains(
        'insert into public.v3_player_homes (user_id) values (new.id) on conflict (user_id) do nothing',
      ),
    );
    expect(
      normalized,
      contains(
        'create trigger v3_profiles_create_home after insert on public.v3_profiles for each row execute function public.create_v3_home_for_profile()',
      ),
    );
    expect(
      normalized,
      contains(
        'insert into public.v3_player_homes (user_id) select profile.id from public.v3_profiles as profile on conflict (user_id) do nothing',
      ),
    );
  });

  test('keeps Homes owner-readable while mutations remain server-owned', () {
    final normalized = compact(sql());

    expect(
      normalized,
      contains('alter table public.v3_player_homes enable row level security'),
    );
    expect(
      normalized,
      contains(
        'create policy "v3_player_homes_authenticated_read_own" on public.v3_player_homes for select to authenticated using (auth.uid() = user_id)',
      ),
    );
    expect(
      normalized,
      contains(
        'revoke insert, update, delete on table public.v3_player_homes from anon, authenticated',
      ),
    );
    expect(normalized, isNot(contains('on public.v3_player_homes for insert')));
    expect(normalized, isNot(contains('on public.v3_player_homes for update')));
    expect(normalized, isNot(contains('on public.v3_player_homes for delete')));
  });

  test('exposes only the strict authenticated Home projection', () {
    final normalized = compact(sql());
    final start = normalized.indexOf(
      'create or replace function public.get_v3_home()',
    );
    final end = normalized.indexOf(
      'alter table public.v3_player_homes enable row level security',
    );
    final function = normalized.substring(start, end);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    expect(function, contains('v_user_id uuid := auth.uid()'));
    expect(
      function,
      contains(
          "raise exception 'home requires an authenticated user' using errcode = '28000'"),
    );
    expect(function, contains('where user_id = v_user_id'));
    expect(
      function,
      contains(
        "return jsonb_build_object( 'id', v_home.id, 'user_id', v_home.user_id, 'created_at', v_home.created_at )",
      ),
    );
    expect(function, isNot(contains("'home'")));
    expect(function, isNot(contains("'module'")));
    expect(
      normalized,
      contains('revoke all on function public.get_v3_home() from public, anon'),
    );
    expect(
      normalized,
      contains(
          'grant execute on function public.get_v3_home() to authenticated'),
    );
  });

  test(
      'preserves the seven canonical categories and fails closed for a seventh Food Base Item',
      () {
    expect(versionedContentFoundation.existsSync(), isTrue);
    final categories =
        compact(versionedContentFoundation.readAsStringSync().toLowerCase());
    final normalized = compact(sql());

    expect(
      categories,
      contains(
        "category text not null check ( category in ( 'fauna', 'flora', 'mineral', 'fossil', 'artifact', 'food', 'orb' ) )",
      ),
    );
    expect(
      normalized,
      contains(
        "add constraint v3_base_items_food_identity_whitelist check ( category <> 'food' or id in ( 'food:veg', 'food:fruit', 'food:critter', 'food:fish', 'food:grub', 'food:nectar' ) ) not valid",
      ),
    );
    expect(
      normalized,
      contains(
        'alter table public.v3_base_items validate constraint v3_base_items_food_identity_whitelist',
      ),
    );
  });

  test(
      'seeds and publishes exactly the canonical Food Types and explicit Orb Base Item',
      () {
    final value = sql();
    final normalized = compact(value);

    for (final food in <({String id, String name})>[
      (id: 'food:veg', name: 'veg'),
      (id: 'food:fruit', name: 'fruit'),
      (id: 'food:critter', name: 'critter'),
      (id: 'food:fish', name: 'fish'),
      (id: 'food:grub', name: 'grub'),
      (id: 'food:nectar', name: 'nectar'),
    ]) {
      expect(normalized, contains("'${food.id}'"));
      expect(normalized, contains("'${food.name}'"));
      expect(
        normalized,
        contains("public.publish_v3_base_item_version('${food.id}'"),
      );
    }
    expect(normalized, contains("'orb:orb_type'"));
    expect(normalized, contains("'orb type'"));
    expect(
      normalized,
      contains("public.publish_v3_base_item_version('orb:orb_type'"),
    );
    expect(normalized, contains("'food'"));
    expect(normalized, contains("'orb'"));
    expect(normalized, contains('revision, publication_status, display_name'));
    expect(normalized, contains(', 1, \'draft\','));
    expect(normalized, contains('on conflict (id) do nothing'));
    expect(
      normalized,
      contains(
        "array[ 'food:critter', 'food:fish', 'food:fruit', 'food:grub', 'food:nectar', 'food:veg' ]",
      ),
    );
    expect(normalized, contains('base_item.current_published_version_id'));
    expect(normalized, contains('version.revision is distinct from 1'));
    expect(normalized,
        contains("version.publication_status is distinct from 'published'"));
    expect(normalized,
        contains('food base item seed is incomplete or not current'));
    expect(normalized,
        contains('orb base item seed is not current and published'));
    expect(value, isNot(contains('v3_orb_')));
    expect(value, isNot(contains('currency')));
    expect(value, isNot(contains('craft')));
    expect(value, isNot(contains('stack')));
    expect(value, isNot(contains('consum')));
  });

  test(
      'completes schema, RLS, and whitelist validation before writes, then asserts seeded state',
      () {
    final value = sql();
    final firstWrite = <int>[
      value.indexOf('insert into public.v3_player_homes (user_id)\nselect'),
      value.indexOf('insert into public.v3_base_items'),
    ].reduce((left, right) => left < right ? left : right);

    expect(firstWrite, greaterThanOrEqualTo(0));
    for (final setup in <String>[
      'alter table public.v3_base_items\n      add constraint',
      'alter table public.v3_player_homes enable row level security',
      'create policy "v3_player_homes_authenticated_read_own"',
      'revoke insert, update, delete on table public.v3_player_homes',
    ]) {
      final position = value.indexOf(setup);
      expect(position, greaterThanOrEqualTo(0), reason: setup);
      expect(position, lessThan(firstWrite), reason: setup);
    }
    final validation = value.indexOf(
      'alter table public.v3_base_items\n  validate constraint v3_base_items_food_identity_whitelist',
    );
    expect(validation, greaterThanOrEqualTo(0));
    expect(validation, lessThan(firstWrite));
    expect(value, isNot(contains('set constraints')));
    final finalAssertion = value.indexOf(
      r'do $assert_canonical_home_item_category_seed$',
    );
    expect(finalAssertion, greaterThan(firstWrite));
  });
}
