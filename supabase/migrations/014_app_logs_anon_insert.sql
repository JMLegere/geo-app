CREATE POLICY "anon_insert_logs" ON app_logs
  FOR INSERT TO anon
  WITH CHECK (true);
