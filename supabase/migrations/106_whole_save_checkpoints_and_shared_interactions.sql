-- Additive local-save/checkpoint rollout. Old clients retain their existing RPCs
-- until the minimum-client cutover; only these functions may write revisions.
create table if not exists public.v3_player_save_heads (
  player_id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null default 0 check (revision >= 0),
  checkpoint_id uuid,
  reconciliation_cursor bigint not null default 0 check (reconciliation_cursor >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.v3_player_save_revisions (
  player_id uuid not null references auth.users(id) on delete cascade,
  revision bigint not null check (revision > 0),
  checkpoint_id uuid not null,
  ancestor_revision bigint,
  environment text not null check (environment in ('local', 'prod')),
  schema_version integer not null,
  rules_version text not null,
  content_version text not null,
  reconciliation_cursor bigint not null,
  save jsonb not null,
  accepted_at timestamptz not null default now(),
  retain_until timestamptz not null default (now() + interval '90 days'),
  primary key (player_id, revision),
  unique (player_id, checkpoint_id)
);
create index if not exists v3_save_revisions_retention_idx
  on public.v3_player_save_revisions(retain_until);

create table if not exists public.v3_shared_interactions (
  id uuid primary key,
  kind text not null,
  rules_version text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'completed', 'expired', 'failed')),
  idempotency_key uuid not null unique,
  causal_interaction_id uuid references public.v3_shared_interactions(id),
  input jsonb not null default '{}'::jsonb,
  outcome jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  completed_at timestamptz
);

create table if not exists public.v3_shared_interaction_participants (
  interaction_id uuid not null references public.v3_shared_interactions(id) on delete cascade,
  player_id uuid not null references auth.users(id) on delete cascade,
  player_revision bigint not null,
  primary key (interaction_id, player_id),
  foreign key (player_id, player_revision)
    references public.v3_player_save_revisions(player_id, revision)
);

create table if not exists public.v3_shared_interaction_deliveries (
  sequence bigint generated always as identity primary key,
  interaction_id uuid not null references public.v3_shared_interactions(id) on delete cascade,
  player_id uuid not null references auth.users(id) on delete cascade,
  rules_version text not null,
  effect jsonb not null,
  created_at timestamptz not null default now(),
  applied_revision bigint,
  unique (interaction_id, player_id)
);

alter table public.v3_player_save_heads enable row level security;
alter table public.v3_player_save_revisions enable row level security;
alter table public.v3_shared_interactions enable row level security;
alter table public.v3_shared_interaction_participants enable row level security;
alter table public.v3_shared_interaction_deliveries enable row level security;

revoke all on public.v3_player_save_heads, public.v3_player_save_revisions,
  public.v3_shared_interactions, public.v3_shared_interaction_participants,
  public.v3_shared_interaction_deliveries from anon, authenticated;

create or replace function public.validate_player_save_shape(p_save jsonb)
returns text language plpgsql immutable set search_path = '' as $$
declare
  required_sections constant text[] := array[
    'profile', 'pack', 'itemKnowledge', 'disciplineProgress', 'map',
    'encounters', 'home', 'town'
  ];
  section text;
begin
  if jsonb_typeof(p_save) <> 'object' then return 'save_not_object'; end if;
  if (p_save->>'schemaVersion')::integer <> 1 then return 'unsupported_schema'; end if;
  if jsonb_typeof(p_save->'payload') <> 'object' then return 'payload_not_object'; end if;
  foreach section in array required_sections loop
    if not (p_save->'payload' ? section) then return 'incomplete_save_' || section; end if;
  end loop;
  if p_save->'payload' ?| array['credentials','undiscoveredItems','futureOutcomes','secrets'] then
    return 'hidden_information_forbidden';
  end if;
  if jsonb_typeof(p_save->'evidence') <> 'array'
     or jsonb_typeof(p_save->'appliedInteractionIds') <> 'array' then
    return 'invalid_provenance';
  end if;
  return null;
exception when others then
  return 'malformed_save';
end;
$$;

create or replace function public.validate_player_save_progression(
  p_previous jsonb, p_proposed jsonb
) returns text language plpgsql immutable set search_path = '' as $$
declare old_item jsonb; proposed_item jsonb; receipt text;
begin
  -- Ownership cannot disappear or be rebound by restoring/editing a save.
  for old_item in select value from jsonb_array_elements(p_previous->'payload'->'pack') loop
    select value into proposed_item
      from jsonb_array_elements(p_proposed->'payload'->'pack')
      where value->>'id' = old_item->>'id' limit 1;
    if proposed_item is null then return 'owned_item_removed'; end if;
    if coalesce(proposed_item->>'base_item_id', proposed_item->>'baseItemId', '')
         <> coalesce(old_item->>'base_item_id', old_item->>'baseItemId', '')
       or coalesce(proposed_item->>'base_item_version_id', proposed_item->>'baseItemVersionId', '')
         <> coalesce(old_item->>'base_item_version_id', old_item->>'baseItemVersionId', '')
       or coalesce(proposed_item->'property_values', proposed_item->'propertyValues', '[]'::jsonb)
         <> coalesce(old_item->'property_values', old_item->'propertyValues', '[]'::jsonb) then
      return 'permanent_item_binding_changed';
    end if;
    proposed_item := null;
  end loop;

  -- A restored branch may contain fewer local observations, but it may never
  -- erase a server-delivered shared interaction receipt.
  for receipt in select jsonb_array_elements_text(p_previous->'appliedInteractionIds') loop
    if not (p_proposed->'appliedInteractionIds' ? receipt) then
      return 'shared_receipt_removed';
    end if;
  end loop;

  -- Every newly claimed Item must name durable provenance. The referenced
  -- command/outcome/interaction is verified by its mechanic-specific RPC or
  -- shared record before this generic checkpoint gate is enabled for cutover.
  if exists (
    select 1 from jsonb_array_elements(p_proposed->'payload'->'pack') proposed
    where not exists (
      select 1 from jsonb_array_elements(p_previous->'payload'->'pack') old
      where old->>'id' = proposed->>'id'
    ) and not exists (
      select 1 from jsonb_array_elements(p_proposed->'evidence') evidence
      where coalesce(evidence->>'resultItemId', evidence->>'result_item_id') = proposed->>'id'
        and evidence->>'receiptId' is not null
    )
  ) then return 'new_item_without_receipt'; end if;
  return null;
exception when others then return 'malformed_progression';
end;
$$;

create or replace function public.accept_player_checkpoint(p_save jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  head public.v3_player_save_heads%rowtype;
  prior public.v3_player_save_revisions%rowtype;
  checkpoint uuid;
  ancestor bigint;
  failure text;
  next_revision bigint;
  cursor bigint;
begin
  if actor is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if p_save->>'playerId' <> actor::text then
    return jsonb_build_object('status','rejected','code','owner_mismatch','message','Save owner does not match authentication.');
  end if;
  failure := public.validate_player_save_shape(p_save);
  if failure is not null then
    return jsonb_build_object('status','rejected','code',failure,'message','Save validation failed.');
  end if;
  checkpoint := (p_save->>'checkpointId')::uuid;
  ancestor := (p_save->>'ancestorRevision')::bigint;

  select * into prior from public.v3_player_save_revisions
    where player_id = actor and checkpoint_id = checkpoint;
  if found then
    return jsonb_build_object('status','accepted','checkpoint_id',checkpoint,
      'revision',prior.revision,'reconciliation_cursor',prior.reconciliation_cursor);
  end if;

  insert into public.v3_player_save_heads(player_id) values(actor)
    on conflict (player_id) do nothing;
  select * into head from public.v3_player_save_heads
    where player_id = actor for update;
  if ancestor is distinct from nullif(head.revision, 0) then
    select * into prior from public.v3_player_save_revisions
      where player_id = actor and revision = head.revision;
    return jsonb_build_object('status','conflict','reason','stale_ancestor',
      'cloud_revision',head.revision,'cloud_save',prior.save);
  end if;

  if head.revision > 0 then
    select * into prior from public.v3_player_save_revisions
      where player_id = actor and revision = head.revision;
    failure := public.validate_player_save_progression(prior.save, p_save);
    if failure is not null then
      return jsonb_build_object('status','rejected','code',failure,
        'message','Progression is not supported by accepted ancestry and evidence.');
    end if;
  end if;

  -- Completed shared records are monotonic and cannot be erased by restoration.
  select coalesce(max(sequence), head.reconciliation_cursor) into cursor
    from public.v3_shared_interaction_deliveries where player_id = actor;
  if (p_save->>'reconciliationCursor')::bigint < head.reconciliation_cursor then
    return jsonb_build_object('status','rejected','code','reconciliation_regression',
      'message','Completed shared interactions must be reconciled first.');
  end if;

  next_revision := head.revision + 1;
  insert into public.v3_player_save_revisions(
    player_id, revision, checkpoint_id, ancestor_revision, environment,
    schema_version, rules_version, content_version, reconciliation_cursor, save
  ) values (
    actor, next_revision, checkpoint, ancestor, p_save->>'environment',
    (p_save->>'schemaVersion')::integer, p_save->>'rulesVersion',
    p_save->>'contentVersion', cursor, p_save
  );
  update public.v3_player_save_heads set revision = next_revision,
    checkpoint_id = checkpoint, reconciliation_cursor = cursor, updated_at = now()
    where player_id = actor;
  return jsonb_build_object('status','accepted','checkpoint_id',checkpoint,
    'revision',next_revision,'reconciliation_cursor',cursor);
exception when invalid_text_representation then
  return jsonb_build_object('status','rejected','code','invalid_identity','message','Checkpoint identity is invalid.');
end;
$$;

create or replace function public.fetch_latest_player_checkpoint()
returns jsonb language sql security definer set search_path = '' stable as $$
  select case when auth.uid() is null then null else (
    select jsonb_build_object('revision', revision, 'save', save)
    from public.v3_player_save_revisions
    where player_id = auth.uid() order by revision desc limit 1
  ) end;
$$;

create or replace function public.fetch_player_interaction_deliveries(p_after_sequence bigint)
returns jsonb language sql security definer set search_path = '' stable as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'interaction_id', interaction_id, 'sequence', sequence,
    'rules_version', rules_version, 'effect', effect
  ) order by sequence), '[]'::jsonb)
  from public.v3_shared_interaction_deliveries
  where player_id = auth.uid() and sequence > greatest(p_after_sequence, 0);
$$;

create or replace function public.claim_next_shared_interaction()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare claimed public.v3_shared_interactions%rowtype;
begin
  select * into claimed from public.v3_shared_interactions
    where status = 'pending' and (expires_at is null or expires_at > now())
    order by created_at, id for update skip locked limit 1;
  if not found then return null; end if;
  update public.v3_shared_interactions set status = 'processing'
    where id = claimed.id;
  return jsonb_build_object('interaction_id', claimed.id, 'kind', claimed.kind,
    'rules_version', claimed.rules_version, 'input', claimed.input,
    'participants', (select jsonb_agg(jsonb_build_object(
      'player_id', player_id, 'revision', player_revision
    )) from public.v3_shared_interaction_participants where interaction_id=claimed.id));
end;
$$;

create or replace function public.complete_shared_interaction(
  p_interaction_id uuid, p_outcome jsonb, p_deliveries jsonb
) returns void language plpgsql security definer set search_path = '' as $$
declare interaction public.v3_shared_interactions%rowtype; delivery jsonb;
begin
  select * into interaction from public.v3_shared_interactions
    where id=p_interaction_id for update;
  if not found then raise exception 'unknown interaction'; end if;
  if interaction.status = 'completed' then return; end if;
  if interaction.status <> 'processing' then raise exception 'interaction not claimed'; end if;
  for delivery in select value from jsonb_array_elements(p_deliveries) loop
    if not exists(select 1 from public.v3_shared_interaction_participants
      where interaction_id=p_interaction_id
        and player_id=(delivery->>'player_id')::uuid) then
      raise exception 'delivery participant mismatch';
    end if;
    insert into public.v3_shared_interaction_deliveries(
      interaction_id, player_id, rules_version, effect
    ) values(p_interaction_id, (delivery->>'player_id')::uuid,
      interaction.rules_version, delivery->'effect')
    on conflict (interaction_id, player_id) do nothing;
  end loop;
  update public.v3_shared_interactions set status='completed', outcome=p_outcome,
    completed_at=now() where id=p_interaction_id;
end;
$$;

-- Repeatable bootstrap: the first complete save is assembled by the trusted API
-- from existing authoritative projections, never supplied as accepted history by
-- an unauthenticated client. Feature arrays preserve exact IDs/version bindings.
create or replace function public.bootstrap_player_save(p_environment text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result jsonb;
begin
  if actor is null then raise exception 'authentication required' using errcode='42501'; end if;
  if p_environment not in ('local','prod') then raise exception 'invalid environment'; end if;
  if exists(select 1 from public.v3_player_save_heads where player_id=actor and revision>0) then
    return public.fetch_latest_player_checkpoint();
  end if;
  result := jsonb_build_object(
    'profile', coalesce((select jsonb_build_object('id',p.id,'display_name',p.display_name,'created_at',p.created_at,'updated_at',p.updated_at) from public.v3_profiles p where p.id=actor), '{}'::jsonb),
    -- Existing projections already redact undiscovered identity and properties.
    'pack', public.fetch_v3_pack_items(),
    'itemKnowledge', public.fetch_v3_item_index(),
    'disciplineProgress', coalesce((select jsonb_agg(to_jsonb(d)) from public.v3_discipline_progress d where d.user_id=actor), '[]'::jsonb),
    'map', jsonb_build_object('visits', coalesce((select jsonb_agg(to_jsonb(v)) from public.v3_cell_visits v where v.user_id=actor), '[]'::jsonb)),
    'encounters', '[]'::jsonb,
    'home', public.get_v3_home(),
    'town', public.get_v3_town()
  );
  return jsonb_build_object('status','bootstrap_required','payload',result);
end;
$$;

grant execute on function public.validate_player_save_shape(jsonb) to authenticated;
grant execute on function public.validate_player_save_progression(jsonb,jsonb) to authenticated;
grant execute on function public.accept_player_checkpoint(jsonb) to authenticated;
grant execute on function public.fetch_latest_player_checkpoint() to authenticated;
grant execute on function public.fetch_player_interaction_deliveries(bigint) to authenticated;
grant execute on function public.bootstrap_player_save(text) to authenticated;
revoke all on function public.claim_next_shared_interaction() from public, anon, authenticated;
revoke all on function public.complete_shared_interaction(uuid,jsonb,jsonb) from public, anon, authenticated;
grant execute on function public.claim_next_shared_interaction() to service_role;
grant execute on function public.complete_shared_interaction(uuid,jsonb,jsonb) to service_role;

comment on table public.v3_player_save_revisions is
  'Immutable accepted whole-save checkpoints. Retention jobs must preserve heads, interaction references, unresolved branches and receipts.';
