-- Migration 102: return the Pack-safe Item projection after examination.
--
-- Migration 100 committed durable Player/Base Item knowledge correctly, but
-- returned journal metadata instead of the Item shape consumed by Pack.

CREATE OR REPLACE FUNCTION public.examine_v3_item(p_item_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_item public.v3_items%ROWTYPE;
  v_entry public.v3_player_base_item_journal_entries%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Item examination requires an authenticated user'
      USING ERRCODE = '28000';
  END IF;

  IF p_item_id IS NULL THEN
    RAISE EXCEPTION 'Item examination requires an Item identity'
      USING ERRCODE = '22023';
  END IF;

  SELECT item.*
  INTO v_item
  FROM public.v3_items AS item
  WHERE item.id = p_item_id
    AND item.user_id = v_user_id
    AND item.status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Owned active Item % was not found', p_item_id
      USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.v3_player_base_item_journal_entries (
    user_id,
    base_item_id,
    base_item_version_id,
    examined_item_id,
    examined_at
  )
  VALUES (
    v_item.user_id,
    v_item.base_item_id,
    v_item.base_item_version_id,
    v_item.id,
    now()
  )
  ON CONFLICT (user_id, base_item_id) DO NOTHING
  RETURNING * INTO v_entry;

  IF NOT FOUND THEN
    SELECT entry.*
    INTO v_entry
    FROM public.v3_player_base_item_journal_entries AS entry
    WHERE entry.user_id = v_item.user_id
      AND entry.base_item_id = v_item.base_item_id;
  END IF;

  RETURN public.v3_safe_item_projection(v_item);
END;
$$;

REVOKE ALL ON FUNCTION public.examine_v3_item(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.examine_v3_item(UUID) TO authenticated;
