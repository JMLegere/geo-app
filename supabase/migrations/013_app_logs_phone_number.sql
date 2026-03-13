-- Add phone_number to app_logs for user identification.
-- Populated from Supabase auth user_metadata.phone_number at flush time.

ALTER TABLE app_logs ADD COLUMN IF NOT EXISTS phone_number text;
