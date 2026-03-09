-- Add has_completed_onboarding to profiles table
-- Tracks whether user has completed the onboarding flow
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS has_completed_onboarding BOOLEAN DEFAULT false;
