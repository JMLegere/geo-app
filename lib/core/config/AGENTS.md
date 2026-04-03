# core/config

Environment configuration and Supabase bootstrap.

**Files:** `supabase_config.dart` (`SupabaseConfig` — url, anonKey, validate()), `supabase_bootstrap.dart` (pre-initializes Supabase client, overridden in ProviderScope).

**Key rule:** `validate()` throws if `SUPABASE_URL` or `SUPABASE_ANON_KEY` are empty — fail fast at startup. No fallback values.

See /lib/core/AGENTS.md for full core subsystem rules.
