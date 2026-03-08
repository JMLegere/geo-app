# Supabase Setup Guide

This document provides step-by-step instructions for setting up the Supabase backend for the EarthNova game.

## Prerequisites

- Supabase account (free tier at https://supabase.com)
- Supabase CLI (optional, for local development)

## Step 1: Create a Supabase Project

1. Go to https://supabase.com/dashboard
2. Click "New Project"
3. Fill in:
   - **Name**: `fog-of-world` (or your preferred name)
   - **Database Password**: Generate a strong password
   - **Region**: Choose closest to your location
4. Click "Create new project"
5. Wait for the project to initialize (2-3 minutes)

## Step 2: Run Database Migrations

Once your project is created:

1. Go to the SQL Editor in your Supabase dashboard
2. Click "New Query"
3. Copy the entire contents of `supabase/migrations/001_initial_schema.sql`
4. Paste into the SQL editor
5. Click "Run"
6. Verify all tables are created (check the "Tables" section in the left sidebar)

## Step 3: Seed Species Data

1. In the SQL Editor, click "New Query"
2. Copy the entire contents of `supabase/migrations/002_seed_species.sql`
3. Paste into the SQL editor
4. Click "Run"
5. Verify 30 species are inserted:
   - Go to the "species" table in the left sidebar
   - You should see 30 rows

## Step 4: Deploy Edge Function

1. In your Supabase dashboard, go to "Edge Functions"
2. Click "Create a new function"
3. Name it: `generate-species-for-cell`
4. Copy the entire contents of `supabase/functions/generate-species-for-cell/index.ts`
5. Paste into the function editor
6. Click "Deploy"

## Step 5: Get Your Credentials

1. Go to Project Settings → API
2. Copy the following values:
   - **Project URL**: `https://[project-id].supabase.co`
   - **Anon Key**: The public anonymous key
3. Create a `.env` file in the project root (copy from `.env.example`):
   ```
   SUPABASE_URL=https://[your-project-id].supabase.co
   SUPABASE_ANON_KEY=[your-anon-key]
   ```

## Step 6: Verify Setup

### Test Species Table (Public Read)

```bash
curl -X GET \
  'https://[your-project-id].supabase.co/rest/v1/species?select=*' \
  -H 'apikey: [your-anon-key]'
```

Expected: 200 OK with 30 species records

### Test RLS (Cell Progress - Should Fail Without Auth)

```bash
curl -X GET \
  'https://[your-project-id].supabase.co/rest/v1/cell_progress?select=*' \
  -H 'apikey: [your-anon-key]'
```

Expected: 401 Unauthorized (RLS blocks unauthenticated access)

### Test Edge Function

```bash
curl -X POST \
  'https://[your-project-id].supabase.co/functions/v1/generate-species-for-cell' \
  -H 'Authorization: Bearer [your-anon-key]' \
  -H 'Content-Type: application/json' \
  -d '{"cell_id": "test_cell_001", "biome": "forest"}'
```

Expected: 200 OK with species array for forest biome

## Database Schema

### Tables

- **profiles**: User profiles with streak counters and stats
- **cell_progress**: Per-user cell fog state and restoration level
- **species**: Global species catalog (30 species, 5 biomes)
- **collected_species**: User's collected species journal

### Row Level Security (RLS)

- **profiles**: Users can only read/update their own profile
- **cell_progress**: Users can only read/write their own cell progress
- **species**: Public read (no authentication required)
- **collected_species**: Users can only read/write their own collections

## Flutter Integration

The Flutter app uses `supabase_flutter` package configured via:

- `lib/core/config/supabase_config.dart`: Loads credentials from `.env`
- `.env`: Contains `SUPABASE_URL` and `SUPABASE_ANON_KEY`

Make sure to:
1. Add `flutter_dotenv` to `pubspec.yaml`
2. Load `.env` in `main.dart` before initializing Supabase
3. Call `SupabaseConfig.initialize()` during app startup

## Troubleshooting

### "Missing Supabase configuration"

- Ensure `.env` file exists in project root
- Verify `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set
- Check that values don't have extra whitespace

### RLS Errors

- Verify RLS policies are enabled on all tables
- Check that policies use `auth.uid()` correctly
- Test with authenticated user (sign up first)

### Edge Function Errors

- Check function logs in Supabase dashboard
- Verify function has access to `species` table
- Ensure `SUPABASE_SERVICE_ROLE_KEY` is set in function environment

## Next Steps

- Task 5: Riverpod state management scaffolding
- Task 16: Supabase auth + user profile integration
- Task 23: Backend sync implementation
