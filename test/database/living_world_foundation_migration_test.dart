import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '092_living_world_foundation.sql',
  );

  String sql() => migration.readAsStringSync().toLowerCase();
  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test(
      'creates additive stable authored Venue, Villager, and Service lifecycles',
      () {
    expect(migration.existsSync(), isTrue);
    final value = sql();
    final normalized = compact(value);

    for (final table in <String>[
      'v3_venues',
      'v3_venue_versions',
      'v3_villagers',
      'v3_villager_versions',
      'v3_services',
      'v3_service_versions',
    ]) {
      expect(value, contains('create table if not exists public.$table'));
    }
    expect(normalized, contains('unique (venue_id, revision)'));
    expect(normalized, contains('unique (villager_id, revision)'));
    expect(normalized, contains('unique (service_id, revision)'));
    expect(
        normalized,
        contains(
            'foreign key (id, current_published_version_id) references public.v3_venue_versions(venue_id, id)'));
    expect(
        normalized,
        contains(
            'foreign key (id, current_published_version_id) references public.v3_villager_versions(villager_id, id)'));
    expect(
        normalized,
        contains(
            'foreign key (id, current_published_version_id) references public.v3_service_versions(service_id, id)'));
    expect(value, contains('published living world versions are immutable'));
    expect(
        value,
        contains(
            'living world version associations can only change while draft'));
    expect(
        normalized, contains("kind text not null check (btrim(kind) <> '')"));
    expect(normalized,
        contains("description text not null check (btrim(description) <> '')"));
    final immutabilityGuard = normalized.substring(
      normalized.indexOf(
          'create or replace function public.v3_prevent_published_living_world_version_mutation()'),
      normalized.indexOf(
          'create or replace function public.v3_require_draft_living_world_association()'),
    );
    final venueBranch = immutabilityGuard.substring(
      immutabilityGuard.indexOf("if tg_table_name = 'v3_venue_versions' then"),
      immutabilityGuard
          .indexOf("elsif tg_table_name = 'v3_villager_versions' then"),
    );
    final villagerBranch = immutabilityGuard.substring(
      immutabilityGuard
          .indexOf("elsif tg_table_name = 'v3_villager_versions' then"),
      immutabilityGuard
          .indexOf("elsif tg_table_name = 'v3_service_versions' then"),
    );
    final serviceBranch = immutabilityGuard.substring(
      immutabilityGuard
          .indexOf("elsif tg_table_name = 'v3_service_versions' then"),
    );
    expect(venueBranch, isNot(contains('new.villager_id')));
    expect(venueBranch, isNot(contains('new.service_id')));
    expect(villagerBranch, isNot(contains('new.venue_id')));
    expect(villagerBranch, isNot(contains('new.service_id')));
    expect(serviceBranch, isNot(contains('new.venue_id')));
    expect(serviceBranch, isNot(contains('new.villager_id')));
    expect(value, isNot(contains('drop table')));
    expect(value, isNot(contains('truncate')));
  });

  test('models normalized ordered roster and service associations', () {
    final normalized = compact(sql());

    expect(
        normalized,
        contains(
            'create table if not exists public.v3_venue_version_villagers'));
    expect(normalized, contains('primary key (venue_version_id, villager_id)'));
    expect(normalized, contains('unique (venue_version_id, ordinal)'));
    expect(
        normalized,
        contains(
            'create table if not exists public.v3_villager_version_services'));
    expect(
        normalized, contains('primary key (villager_version_id, service_id)'));
    expect(normalized, contains('unique (villager_version_id, ordinal)'));
    expect(
        normalized,
        contains(
            "raise exception 'published venue versions require at least one villager'"));
    expect(
        normalized,
        contains(
            "raise exception 'published villager versions require at least one service'"));
    expect(
        normalized,
        contains(
            'published venue versions require every roster villager to have an exact current published villager version'));
    expect(
        normalized,
        contains(
            'published villager versions require every associated service to have an exact current published service version'));
    expect(normalized,
        contains("villager_version.publication_status = 'published'"));
    expect(normalized,
        contains("service_version.publication_status = 'published'"));
  });

  test('seeds only the stable Rowan authored graph and explicit legacy alias',
      () {
    final value = sql();
    final seed = value.substring(
      value.indexOf('-- rowan compatibility content is stable'),
    );

    expect(value, contains("'venue:rowans_rehab_center'"));
    expect(value, contains("'villager:rowan'"));
    expect(value, contains("'service:release_to_wild'"));
    expect(
        value, contains("'wildlife-rehabilitation-center:city_fredericton'"));
    expect(value, contains("'city_fredericton'"));
    expect(value, contains("'v_22982_-33322'"));
    expect(value, contains("'rowan'"));
    expect(value, contains("'wildlife rehabilitator'"));
    expect(value, contains("'rowan''s rehab center'"));
    expect(value, contains("'release to wild'"));
    expect(value, contains('insert into public.v3_venue_legacy_aliases'));
    expect(value, contains('on conflict do nothing'));
    expect(seed, isNot(contains('insert into public.v3_player_known_venues')));
    expect(
        seed, isNot(contains('insert into public.v3_player_known_villagers')));
    expect(seed, isNot(contains('insert into public.v3_venue_visits')));
    final seedOffset =
        value.indexOf('-- rowan compatibility content is stable');
    expect(
        value.indexOf(
                'alter table public.v3_venues enable row level security') <
            seedOffset,
        isTrue);
    expect(
        value.indexOf(
                'create policy "v3_player_known_venues_authenticated_read_own"') <
            seedOffset,
        isTrue);
    expect(
        value.indexOf(
                'revoke insert, update, delete on table public.v3_venues') <
            seedOffset,
        isTrue);
  });

  test(
      'preserves exact Player knowledge and visit provenance with one-state uniqueness',
      () {
    final normalized = compact(sql());

    expect(normalized, contains('primary key (user_id, venue_id)'));
    expect(normalized, contains('first_venue_version_id uuid not null'));
    expect(
        normalized,
        contains(
            'reveal_outcome_result_id uuid not null references public.v3_encounter_outcome_results(id)'));
    expect(
        normalized,
        contains(
            'foreign key (venue_id, first_venue_version_id) references public.v3_venue_versions(venue_id, id)'));
    expect(normalized, contains('unique (id, user_id, cell_id)'));
    expect(normalized, contains('unique (user_id, venue_id, cell_visit_id)'));
    expect(
        normalized,
        contains(
            'foreign key (cell_visit_id, user_id, cell_id) references public.v3_cell_visits(id, user_id, cell_id)'));
    expect(
        normalized,
        contains(
            'foreign key (venue_id, venue_version_id) references public.v3_venue_versions(venue_id, id)'));
    expect(
        normalized,
        contains(
            'foreign key (user_id, venue_id) references public.v3_player_known_venues(user_id, venue_id)'));
    expect(normalized, contains('primary key (user_id, villager_id)'));
    expect(
        normalized,
        contains(
            'foreign key (first_venue_visit_id, user_id, first_venue_id, first_venue_version_id) references public.v3_venue_visits(id, user_id, venue_id, venue_version_id)'));
    expect(
        normalized,
        contains(
            'foreign key (first_venue_version_id, villager_id) references public.v3_venue_version_villagers(venue_version_id, villager_id)'));
    expect(
        normalized,
        contains(
            'known venue must preserve its player reveal venue outcome provenance'));
    expect(normalized, contains("result.outcome_kind"));
    expect(normalized, contains("outcome.payload ->> 'venue_id'"));
  });

  test(
      'Venue Visit is an auth-bound exact command with current roster semantics and idempotency',
      () {
    final normalized = compact(sql());

    expect(
        normalized,
        contains(
            'create or replace function public.record_v3_venue_visit( p_cell_visit_id uuid, p_venue_id text, p_expected_venue_version_id uuid )'));
    expect(normalized, contains('v_user_id uuid := auth.uid()'));
    expect(
        normalized,
        contains(
            'where id = p_cell_visit_id and user_id = v_user_id for update'));
    expect(
        normalized,
        contains(
            'where user_id = v_user_id and venue_id = p_venue_id for update'));
    expect(normalized, contains('version.id = p_expected_venue_version_id'));
    expect(normalized, contains("version.publication_status = 'published'"));
    expect(
        normalized,
        contains(
            'v_cell_visit.cell_id is distinct from v_venue_version.anchor_cell_id'));
    expect(normalized,
        contains('on conflict (user_id, venue_id, cell_visit_id) do nothing'));
    expect(
        normalized, contains('insert into public.v3_player_known_villagers'));
    expect(
        normalized, contains('on conflict (user_id, villager_id) do nothing'));
    expect(normalized,
        contains('where association.venue_version_id = v_venue_version.id'));
    expect(normalized, contains('venue_version_revision'));
    expect(normalized, contains('villager_version_revision'));
    expect(normalized, contains('service_version_revision'));
    expect(normalized, contains('is_idempotent_retry'));
    expect(normalized, contains('venue_association_ordinal'));
    expect(normalized, contains('service_association_ordinal'));
    expect(
        normalized,
        contains(
            'where service_association.villager_version_id = introduced.first_villager_version_id'));
    expect(normalized, contains("'known_at', introduced.known_at"));
    expect(
        normalized,
        contains(
            'venue visit expected venue version does not match the persisted visit version'));
    expect(normalized, contains("'introduced_villagers', '[]'::jsonb"));
    expect(normalized, contains("v_is_idempotent_retry := not found"));
    expect(
      sql().indexOf('from public.v3_player_known_venues') <
          sql().indexOf('select * into v_visit'),
      isTrue,
    );
  });

  test(
      'Town is a current-content projection and command response has only strict aggregates',
      () {
    final value = sql();
    final normalized = compact(value);

    expect(value, contains('create or replace function public.get_v3_town()'));
    expect(value, isNot(contains('create table if not exists public.v3_town')));
    expect(
        normalized, contains("return jsonb_build_object('venues', v_venues)"));
    expect(normalized, contains("'visit', jsonb_build_object("));
    expect(normalized, contains("'introduced_villagers', v_introduced"));
    expect(normalized, contains("'town', v_town"));
    expect(normalized, contains('v_town := public.get_v3_town()'));
    expect(normalized, contains("'kind', version.kind"));
    expect(normalized, contains("'description', service_version.description"));
    expect(normalized,
        contains("'first_venue_version_revision', first_version.revision"));
    expect(normalized, contains("'encounter_id', reveal_result.encounter_id"));
    expect(normalized,
        contains('venue_association.venue_version_id = version.id'));
    expect(normalized, contains('from public.v3_venue_visits as venue_visit'));
    expect(normalized, contains('venue_visit.user_id = v_user_id'));
    expect(normalized, contains('venue_visit.venue_id = known.venue_id'));
    expect(value, isNot(contains("'item'")));
    expect(value, isNot(contains('v3_items')));
    expect(value, isNot(contains('rarity')));
    expect(value, isNot(contains('delete from')));
    expect(value, isNot(contains('drop table')));
    expect(value, isNot(contains('gps')));
    expect(value, isNot(contains('range')));
  });

  test('RLS is read-only and mutation is command-only for Players', () {
    final normalized = compact(sql());

    for (final table in <String>[
      'v3_player_known_venues',
      'v3_player_known_villagers',
      'v3_venue_visits',
    ]) {
      expect(normalized,
          contains('alter table public.$table enable row level security'));
      expect(
          normalized,
          contains(
              'on public.$table for select to authenticated using (auth.uid() = user_id)'));
    }
    expect(normalized, isNot(contains('for insert to authenticated')));
    expect(normalized, isNot(contains('for update to authenticated')));
    expect(normalized, isNot(contains('for delete to authenticated')));
    expect(normalized,
        contains('revoke insert, update, delete on table public.v3_venues'));
    for (final table in <String>[
      'v3_venues',
      'v3_venue_versions',
      'v3_villagers',
      'v3_villager_versions',
      'v3_services',
      'v3_service_versions',
      'v3_venue_version_villagers',
      'v3_villager_version_services',
      'v3_venue_legacy_aliases',
    ]) {
      expect(normalized,
          contains('alter table public.$table enable row level security'));
      expect(normalized,
          isNot(contains('create policy "${table}_authenticated_read"')));
    }
    expect(
        normalized,
        contains(
            'grant execute on function public.publish_v3_venue_version(text, uuid) to service_role'));
    expect(
        normalized,
        contains(
            'grant execute on function public.publish_v3_villager_version(text, uuid) to service_role'));
    expect(
        normalized,
        contains(
            'grant execute on function public.publish_v3_service_version(text, uuid) to service_role'));
    expect(
        normalized,
        contains(
            'revoke all on function public.record_v3_venue_visit(uuid, text, uuid) from public, anon'));
    expect(
        normalized,
        contains(
            'grant execute on function public.record_v3_venue_visit(uuid, text, uuid) to authenticated'));
    expect(
        normalized,
        contains(
            'grant execute on function public.get_v3_town() to authenticated'));
  });
}
