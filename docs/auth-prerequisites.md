# Auth Prerequisites

> Supabase dashboard setup, OAuth provider configuration, and dart-define variables for authentication.

---

## Supabase Dashboard Setup

### Anonymous Auth (Required)

Anonymous sign-in must be enabled for the app to function without OAuth providers configured.

**Steps:**
1. Open Supabase Dashboard → Authentication → Providers
2. Find "Anonymous Sign-In" in the provider list
3. Toggle to **Enable**
4. Save changes

**Verification:**
- `SupabaseAuthService` will create anonymous sessions on first launch
- Users can explore and collect species without creating an account
- Anonymous sessions persist across app restarts

### Row-Level Security (Required)

RLS policies must allow authenticated users to read/write their own data.

**Tables requiring RLS:**
- `profiles` — user profile data (display name, streaks, distance)
- `cell_progress` — per-cell fog state, visits, restoration
- `collected_species` — species collection records

**Policy pattern (all tables):**
```sql
-- Read policy
CREATE POLICY "Users can read own data"
ON <table_name>
FOR SELECT
USING (auth.uid() = user_id);

-- Write policy
CREATE POLICY "Users can write own data"
ON <table_name>
FOR INSERT, UPDATE, DELETE
USING (auth.uid() = user_id);
```

**Verification:**
- Test with anonymous user: create profile, visit cells, collect species
- Check Supabase Dashboard → Table Editor → verify rows have correct `user_id`
- Attempt to query another user's data (should return empty)

### Email Auth (Default)

Email/password authentication is enabled by default in Supabase projects. No configuration required unless explicitly disabled.

**Verification:**
- Supabase Dashboard → Authentication → Providers → Email
- Should show "Enabled" status
- Confirm email setting: optional (allows passwordless magic links)

---

## Google OAuth Setup (Future)

Google sign-in button exists in UI but is non-functional until configured.

### Google Cloud Console

1. Navigate to [Google Cloud Console](https://console.cloud.google.com/)
2. Select or create a project
3. Go to **APIs & Services → Credentials**
4. Click **Create Credentials → OAuth 2.0 Client ID**
5. Application type: **Web application**
6. Add authorized redirect URI:
   ```
   https://<project-ref>.supabase.co/auth/v1/callback
   ```
   Replace `<project-ref>` with your Supabase project reference (found in Project Settings → General → Reference ID)
7. Save and copy the **Client ID** and **Client Secret**

### Supabase Dashboard

1. Go to **Authentication → Providers → Google**
2. Toggle to **Enable**
3. Paste **Client ID** from Google Cloud Console
4. Paste **Client Secret** from Google Cloud Console
5. Save changes

**Verification:**
- Google sign-in button in app should trigger OAuth flow
- After sign-in, user profile should populate with Google account info
- Check Supabase Dashboard → Authentication → Users for new entry

**Current status:** Button renders but does nothing (no client ID configured).

---

## Apple OAuth Setup (Future)

Apple sign-in button exists in UI but is non-functional until configured.

### Apple Developer Program

**Prerequisites:**
- Active Apple Developer Program membership ($99/year)
- Access to [Apple Developer Portal](https://developer.apple.com/)

### Create App ID

1. Go to **Certificates, Identifiers & Profiles → Identifiers**
2. Click **+** to create new identifier
3. Select **App IDs** → Continue
4. Choose **App** → Continue
5. Enter description and Bundle ID (e.g., `com.yourcompany.geoapp`)
6. Enable **Sign in with Apple** capability
7. Register

### Create Services ID

1. Go to **Certificates, Identifiers & Profiles → Identifiers**
2. Click **+** → Select **Services IDs** → Continue
3. Enter description and identifier (e.g., `com.yourcompany.geoapp.web`)
4. Enable **Sign in with Apple**
5. Click **Configure** next to Sign in with Apple
6. Add web domain (e.g., `yourapp.com`)
7. Add return URL:
   ```
   https://<project-ref>.supabase.co/auth/v1/callback
   ```
8. Save and continue

### Supabase Dashboard

1. Go to **Authentication → Providers → Apple**
2. Toggle to **Enable**
3. Paste **Services ID** from Apple Developer Portal
4. Paste **Key ID** and **Team ID** (found in Apple Developer Portal)
5. Upload **Private Key** (.p8 file from Apple)
6. Save changes

**Verification:**
- Apple sign-in button in app should trigger OAuth flow
- After sign-in, user profile should populate with Apple account info
- Check Supabase Dashboard → Authentication → Users for new entry

**Current status:** Button renders but does nothing (no Services ID configured).

---

## Dart Define Variables

Supabase credentials are passed at build time via `--dart-define` flags.

### Required Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `SUPABASE_URL` | Supabase project URL | `https://abc123.supabase.co` |
| `SUPABASE_ANON_KEY` | Public anonymous key | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` |

### How Values Are Consumed

**Source:** `lib/core/config/supabase_config.dart`

```dart
class SupabaseConfig {
  static const String projectUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static void validate() {
    if (projectUrl.isEmpty || anonKey.isEmpty) {
      throw Exception(
        'Supabase configuration missing. '
        'Pass --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
  }
}
```

**Behavior:**
- If both values are empty, app uses `MockAuthService` (offline-only mode)
- If values are provided, app uses `SupabaseAuthService` with anonymous sign-in
- `validate()` is called at app startup — fails fast if credentials are malformed

### Build Commands

**Web (local):**
```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://abc123.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Docker (production):**

**Current state:** Credentials are hardcoded in `Dockerfile` (lines 7-8):
```dockerfile
RUN flutter build web \
    --dart-define=SUPABASE_URL=https://bfaczcsrpfcbijoaeckb.supabase.co \
    --dart-define=SUPABASE_ANON_KEY=sb_publishable__YSJ0cAnZ91SpxX1nlRjtQ_VaTxp2yf
```

**Recommended:** Use `--build-arg` to pass credentials at build time:
```dockerfile
ARG SUPABASE_URL
ARG SUPABASE_ANON_KEY
RUN flutter build web \
    --dart-define=SUPABASE_URL=${SUPABASE_URL} \
    --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
```

Then build with:
```bash
docker build \
  --build-arg SUPABASE_URL=https://abc123.supabase.co \
  --build-arg SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... \
  -t geo-app .
```

### Finding Your Credentials

**Supabase Dashboard:**
1. Go to **Project Settings → API**
2. Copy **Project URL** (use for `SUPABASE_URL`)
3. Copy **anon public** key (use for `SUPABASE_ANON_KEY`)

**Security note:** The anon key is safe to expose in client-side code. It's rate-limited and restricted by RLS policies.

---

## Offline-Only Mode

If `SUPABASE_URL` or `SUPABASE_ANON_KEY` are empty, the app runs in offline-only mode:

- `MockAuthService` is used (no real authentication)
- All data persists to local SQLite only (no cloud sync)
- Sync screen shows "Supabase not configured"
- OAuth buttons render but do nothing

**Use case:** Local development, testing, or fully offline deployments.
