# Supabase Phone + OTP Authentication Setup

This document provides step-by-step instructions for configuring phone-based authentication with one-time passwords (OTP) in Supabase. This is the sole authentication method for EarthNova.

## Prerequisites

Before configuring phone auth in Supabase, you need one of the following:

### Option A: Twilio (Production)
- **Twilio Account**: Create at https://www.twilio.com
- **Account SID**: Found in Twilio Console → Account Info
- **Auth Token**: Found in Twilio Console → Account Info (keep secret)
- **Messaging Service SID** or **Sender Phone Number**: 
  - Messaging Service SID: Recommended for production (found in Twilio Console → Messaging → Services)
  - Sender Phone Number: A Twilio phone number in E.164 format (e.g., `+1234567890`)

### Option B: Supabase Built-in SMS (Testing Only)
- No external account required
- Limited to 10 test phone numbers
- OTP is always `000000` for test numbers
- **Not suitable for production**

## Enable Phone Provider in Supabase Dashboard

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Navigate to **Authentication** → **Providers**
4. Find **Phone** in the provider list
5. Click **Enable**
6. A configuration panel will appear

## Configure SMS Provider

### If Using Twilio (Recommended for Production)

In the Phone provider configuration panel:

1. **SMS Provider**: Select **Twilio**
2. **Twilio Account SID**: Paste your Account SID from Twilio Console
3. **Twilio Auth Token**: Paste your Auth Token from Twilio Console (keep this secret)
4. **Twilio Messaging Service SID** (recommended):
   - Paste your Messaging Service SID from Twilio Console → Messaging → Services
   - This allows you to manage sender numbers and failover at the Twilio level
5. **OR Twilio Phone Number** (alternative):
   - If not using Messaging Service SID, provide a single Twilio phone number in E.164 format
   - Example: `+14155552671`
6. Click **Save**

### If Using Supabase Built-in SMS (Testing Only)

1. **SMS Provider**: Select **Supabase** (built-in)
2. No additional configuration needed
3. Click **Save**
4. Proceed to "Add Test Phone Numbers" section below

## Add Test Phone Numbers (Testing Only)

If using Supabase built-in SMS, you can add up to 10 test phone numbers. For these numbers, the OTP is always `000000`.

1. In the Phone provider configuration panel, scroll to **Test Phone Numbers**
2. Click **Add Phone Number**
3. Enter a phone number in E.164 format (see E.164 Format section below)
4. Click **Add**
5. Repeat for up to 10 test numbers

### Example Test Phone Numbers

```
+15555550100  → OTP: 000000
+15555550101  → OTP: 000000
+15555550102  → OTP: 000000
+15555550103  → OTP: 000000
+15555550104  → OTP: 000000
```

**Note**: These are example numbers. Use any valid E.164 format numbers for testing.

## E.164 Format

Phone numbers must be in **E.164 format**:
- Starts with `+` (plus sign)
- Followed by country code (1–3 digits)
- Followed by national number (no spaces, dashes, or parentheses)

### Examples

| Country | Format | Example |
|---------|--------|---------|
| United States | +1 + area code + number | `+14155552671` |
| United Kingdom | +44 + number (drop leading 0) | `+442071838750` |
| Germany | +49 + number (drop leading 0) | `+493012345678` |
| Japan | +81 + number (drop leading 0) | `+81312345678` |
| Australia | +61 + number (drop leading 0) | `+61212345678` |

**Invalid formats** (will be rejected):
- `1-415-555-2671` (dashes)
- `(415) 555-2671` (parentheses and spaces)
- `415 555 2671` (spaces)
- `+1 415 555 2671` (spaces after country code)

## Rate Limits

Supabase enforces the following rate limits for phone authentication:

| Limit | Value |
|-------|-------|
| **Cooldown per user** | 60 seconds between OTP requests |
| **Global OTP requests** | 30 requests per project per 5 minutes |
| **Max OTP attempts** | 10 attempts per OTP before expiration |
| **OTP expiration** | 10 minutes (default) |

If a user exceeds the 60-second cooldown, they will receive an error. If the project exceeds 30 requests in 5 minutes, all OTP requests will be temporarily blocked.

## Environment Variables

The EarthNova app requires Supabase credentials to be passed at build time via `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
```

**Where to find these values:**
1. Go to Supabase Dashboard → Your Project → Settings → API
2. Copy **Project URL** (for `SUPABASE_URL`)
3. Copy **anon public** key (for `SUPABASE_ANON_KEY`)

**Important**: 
- Never commit these values to version control
- Use environment files or CI/CD secrets for production builds
- The app will fall back to `MockAuthService` if these are not provided

## Verification Checklist

After completing the setup, verify the configuration:

- [ ] Phone provider is **Enabled** in Supabase Dashboard
- [ ] SMS provider is configured (Twilio or Supabase built-in)
- [ ] If using Twilio: Account SID and Auth Token are correct
- [ ] If using Twilio: Messaging Service SID or Sender Phone Number is set
- [ ] Test phone numbers are added (if using Supabase built-in SMS)
- [ ] All test phone numbers are in E.164 format
- [ ] `SUPABASE_URL` and `SUPABASE_ANON_KEY` are available for `--dart-define`
- [ ] Rate limits are understood (60s cooldown, 30 requests per 5 min)

## Testing Phone Auth Locally

1. Build and run the app with credentials:
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://your-project.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
   ```

2. On the auth screen, enter a test phone number (e.g., `+15555550100`)

3. If using Supabase built-in SMS, the OTP will always be `000000`

4. If using Twilio, check your Twilio logs for the actual OTP sent

5. Enter the OTP and verify sign-in succeeds

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Invalid phone number" error | Ensure phone is in E.164 format: `+` + country code + number, no spaces |
| "Rate limit exceeded" | Wait 60 seconds before requesting another OTP |
| "SMS not received" (Twilio) | Check Twilio logs in Console → Monitor → Logs |
| "SMS not received" (Supabase) | Verify phone number is in test list; OTP should be `000000` |
| App shows "Supabase not configured" | Ensure `--dart-define` flags are passed at build time |

## References

- [Supabase Phone Auth Docs](https://supabase.com/docs/guides/auth/phone-login)
- [Twilio Account Setup](https://www.twilio.com/console)
- [E.164 Phone Number Format](https://en.wikipedia.org/wiki/E.164)
- [EarthNova Supabase Config](../lib/core/config/supabase_config.dart)
