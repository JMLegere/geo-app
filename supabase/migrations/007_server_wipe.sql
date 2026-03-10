-- EarthNova — Server Wipe Function
-- Deletes ALL users and per-user game data for a clean beta reset.
-- Preserves species_enrichment (global AI data, expensive to regenerate).
--
-- Usage:
--   SELECT server_wipe();          -- from SQL Editor
--   supabase.rpc('server_wipe')    -- from Flutter client

CREATE OR REPLACE FUNCTION public.server_wipe()
RETURNS TEXT AS $$
DECLARE
  user_count INT;
  item_count INT;
  cell_count INT;
  species_count INT;
  seed_count INT;
BEGIN
  -- Count before delete for the summary
  SELECT count(*) INTO user_count FROM auth.users;

  -- 1. Delete per-user data (FK order: children before parents)
  DELETE FROM public.item_instances;
  GET DIAGNOSTICS item_count = ROW_COUNT;

  DELETE FROM public.collected_species;
  GET DIAGNOSTICS species_count = ROW_COUNT;

  DELETE FROM public.cell_progress;
  GET DIAGNOSTICS cell_count = ROW_COUNT;

  DELETE FROM public.profiles;
  -- profiles FK → auth.users, must go before auth.users

  -- 2. Delete daily seeds (global but ephemeral)
  DELETE FROM public.daily_seeds;
  GET DIAGNOSTICS seed_count = ROW_COUNT;

  -- 3. Delete all auth users
  --    The handle_new_user trigger fires on INSERT, not DELETE, so this is safe.
  DELETE FROM auth.users WHERE id IS NOT NULL;

  -- 4. species_enrichment is intentionally preserved (global AI data).

  RETURN format(
    'Wiped %s users, %s items, %s collected_species, %s cell_progress, %s daily_seeds. species_enrichment preserved.',
    user_count, item_count, species_count, cell_count, seed_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
