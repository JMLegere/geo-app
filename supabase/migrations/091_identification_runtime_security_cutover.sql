-- Migration 091: close the temporary client-owned Identification projection.
--
-- The Flutter runtime now fetches Pack Items through the read-only Pack boundary
-- and identifies through prepare_v3_item_identification + identify_v3_item.
-- No Item rows or legacy Identification source fields are changed by this cutover.

DO $verify_authoritative_identification_boundary$
BEGIN
  IF NOT has_function_privilege(
    'authenticated',
    'public.prepare_v3_item_identification(uuid)',
    'EXECUTE'
  ) OR NOT has_function_privilege(
    'authenticated',
    'public.identify_v3_item(uuid,text,uuid,jsonb)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Identification runtime cutover requires authenticated prepare and commit commands';
  END IF;
END;
$verify_authoritative_identification_boundary$;

REVOKE UPDATE ON TABLE public.v3_items FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS v3_items_update_own ON public.v3_items;

-- Keep the read and command boundaries explicit after the privilege reduction.
GRANT SELECT ON TABLE public.v3_items TO authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_v3_item_identification(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.identify_v3_item(UUID, TEXT, UUID, JSONB)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.fetch_v3_item_index()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.acquire_v3_legacy_discovery_item(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, JSONB,
  TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, JSONB, JSONB, TEXT
) TO authenticated;
