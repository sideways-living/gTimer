# gTimer Sync API

Small cross-platform sync API for gTimer dose history, settings, profile data, saved locations, account login, and device tokens.

This is a first backend slice for local development and protocol testing. It stores data as JSON files under `SyncAPI/data`. For production, keep the HTTP contract and replace the file store with Postgres or another audited database.

## Run Locally

```sh
cd SyncAPI
GTIMER_SYNC_TOKENS='{"dev-token":"local-user"}' npm start
```

Then call the API with:

```text
Authorization: Bearer dev-token
```

Or create a beta account and use the returned device token:

```sh
curl -X POST http://127.0.0.1:8787/v1/auth/register \
  -H 'content-type: application/json' \
  -d '{"email":"person@example.com","password":"change-this-password","deviceName":"Dan Mac"}'
```

## Test

```sh
cd SyncAPI
npm test
```

## CloudPanel / PM2 Deployment

The production CloudPanel site is expected to run the API from:

```sh
/home/gtimer-sync/htdocs/sync.gtimer.app/app/SyncAPI
```

Start or reload the process with the checked-in PM2 ecosystem file:

```sh
cd /home/gtimer-sync/htdocs/sync.gtimer.app/app/SyncAPI
npm test
pm2 startOrReload ecosystem.config.cjs --env production
pm2 save
curl http://127.0.0.1:8787/health
curl https://sync.gtimer.app/health
```

### Reboot Persistence

Preferred setup is PM2's systemd integration. It must be installed by a user with root privileges:

```sh
sudo env PATH=$PATH:$(dirname "$(command -v node)") "$(command -v pm2)" startup systemd -u gtimer-sync --hp /home/gtimer-sync
```

Then, as `gtimer-sync`, save the current process list:

```sh
cd /home/gtimer-sync/htdocs/sync.gtimer.app/app/SyncAPI
pm2 startOrReload ecosystem.config.cjs --env production
pm2 save
```

If root access is not available, install the no-root crontab fallback as `gtimer-sync`:

```sh
cd /home/gtimer-sync/htdocs/sync.gtimer.app/app/SyncAPI
chmod +x scripts/install-reboot-cron.sh
scripts/install-reboot-cron.sh
crontab -l | grep gtimer-sync-api
```

After a VPS reboot, verify:

```sh
pm2 status
ss -ltnp | grep ':8787'
curl http://127.0.0.1:8787/health
curl https://sync.gtimer.app/health
```

## Sync Model

Clients are local-first:

- Every object has a stable `id`.
- Every object has `createdAt`, `updatedAt`, and optional `deletedAt`.
- Deleted objects are sent as tombstones with `deletedAt`, not removed immediately.
- Clients push local changes, then pull remote changes newer than their last cursor.
- The server returns a monotonically increasing `cursor`.
- The first production implementation should encrypt transport with HTTPS and use a proper account identity provider.

Assistant, Siri, Shortcuts, and bot logging must create the same canonical dose object as in-app logging. The preferred pattern is to parse the spoken/typed command on the trusted client, write the local record, and let normal sync push it. On Apple platforms, trusted automations can use the App Intent or the local deep link `gtimer://log?details=2.8ml%20at%20Adina%20with%20Jake%20hashtag%20working%20away`. Supported deep-link query fields are `amount`, `unit`, `details`, `time` as ISO-8601, `location`, `people`, `tags`, `notes`, and `missed=true`. A future server-side bot endpoint must be authenticated to the user/device and must still emit a normal `doses` change through `POST /v1/sync/push`; it should not create a parallel dose format.

## Auth

The normal beta flow is email/password login. Registering or logging in returns a device token. The app stores that token locally and uses it as the bearer token for sync.

Device sync is a Pro entitlement with a 14-day free trial for new sync accounts. Static development tokens bypass entitlement checks and should not be used for public users.

The development server still supports static bearer tokens mapped to user ids through `GTIMER_SYNC_TOKENS`, a JSON object:

```json
{
  "token-value": "user-id"
}
```

If the environment variable is omitted, `dev-token` maps to `dev-user` for local development only.

The server also reads `SyncAPI/.env` before startup. This is useful on hosts where the Node.js site panel does not expose an environment-variable editor:

```sh
PORT=8787
GTIMER_SYNC_TOKENS={"replace-with-a-long-random-token":"dan"}
GTIMER_AUTH_ENCRYPTION_KEY=replace-with-at-least-32-random-bytes
GTIMER_WEBAUTHN_RP_ID=sync.gtimer.app
GTIMER_WEBAUTHN_ORIGINS=https://sync.gtimer.app
```

`GTIMER_AUTH_ENCRYPTION_KEY` encrypts authenticator-app secrets with AES-256-GCM before they are written to disk. Generate it once, back it up securely, and do not rotate or lose it until a supported re-encryption procedure exists. Passkeys are scoped to the configured relying-party ID and exact allowed HTTPS origins.

Do not commit `.env`. It is ignored by Git.

## Endpoints

### `GET /health`

Returns service status.

### `POST /v1/auth/register`

Creates a beta account and registers the current device.

```json
{
  "email": "person@example.com",
  "password": "change-this-password",
  "deviceName": "Dan Mac"
}
```

Response:

```json
{
  "token": "gtimer_...",
  "user": {
    "id": "user-uuid",
    "email": "person@example.com",
    "entitlement": {
      "plan": "free",
      "syncTrialStartedAt": "2026-09-13T08:30:00.000Z",
      "syncTrialEndsAt": "2026-09-27T08:30:00.000Z",
      "proUntil": null,
      "hasSyncAccess": true
    }
  },
  "device": {
    "id": "device-uuid",
    "name": "Dan Mac",
    "createdAt": "2026-09-13T08:30:00.000Z",
    "lastSeenAt": "2026-09-13T08:30:00.000Z",
    "revokedAt": null
  }
}
```

### `POST /v1/auth/login`

Logs in and registers this device as a separate synced device.

```json
{
  "email": "person@example.com",
  "password": "change-this-password",
  "deviceName": "Dan iPhone"
}
```

If authenticator-app protection is enabled, registering a new synced device through `POST /v1/auth/device` also requires either `totpCode` or a one-time `recoveryCode`.

### Account security endpoints

All setup, listing, and revocation endpoints require `Authorization: Bearer <device-token>` unless marked as a sign-in endpoint.

- `GET /v1/auth/security` returns whether TOTP is enabled, remaining recovery-code count, active passkey count, and active device count.
- `POST /v1/auth/totp/enrollment` requires `currentPassword` and returns a five-minute enrollment id, Base32 secret, and `otpauth://` URI.
- `POST /v1/auth/totp/confirmation` accepts the enrollment id and current six-digit code. It returns recovery codes exactly once.
- `DELETE /v1/auth/totp` requires the current password plus a valid authenticator or recovery code.
- `POST /v1/auth/passkeys/registration/options` requires `currentPassword` and returns WebAuthn creation options.
- `POST /v1/auth/passkeys/registration/verification` verifies the signed registration response and stores only the public credential.
- `POST /v1/auth/passkeys/authentication/options` is the email-first passkey sign-in start endpoint.
- `POST /v1/auth/passkeys/authentication/verification` verifies the assertion and issues the normal per-device sync token.
- `GET /v1/auth/passkeys` lists passkeys without exposing credential material.
- `DELETE /v1/auth/passkeys/:passkeyId` revokes a passkey.

WebAuthn challenges are random, expire after five minutes, and are consumed after one verification attempt. Registration and authentication require user verification. Native Apple clients additionally need `webcredentials:sync.gtimer.app` in Associated Domains and a matching `apple-app-site-association` response. Android needs matching Digital Asset Links before passkeys can be enabled in the UI.

### `GET /v1/auth/devices`

Requires `Authorization: Bearer <device-token>`. Returns all devices registered to the account, including revoked devices.

### `DELETE /v1/auth/devices/:deviceId`

Requires `Authorization: Bearer <device-token>`. Revokes a device and invalidates its token for future sync requests.

### `POST /v1/sync/push`

Push local changes for the signed-in user.

```json
{
  "clientId": "iphone-15-pro",
  "changes": {
    "doses": [
      {
        "id": "4E4DD28A-421F-41D6-9D82-5B0DA5E43A3A",
        "amount": 2.8,
        "unit": "ml",
        "time": "2026-09-13T08:30:00.000Z",
        "deviceName": "iPhone",
        "notes": "",
        "tags": ["#hookup"],
        "people": ["Alex"],
        "missed": false,
        "edited": false,
        "earlyBySeconds": 600,
        "latitude": -37.8136,
        "longitude": 144.9631,
        "locationName": "Melbourne",
        "locationAccuracyMeters": 20,
        "locationCapturedAt": "2026-09-13T08:30:00.000Z",
        "locationSource": "automatic",
        "createdAt": "2026-09-13T08:30:00.000Z",
        "updatedAt": "2026-09-13T08:30:00.000Z"
      }
    ],
    "settings": [],
    "savedLocations": [],
    "profiles": []
  }
}
```

Response:

```json
{
  "cursor": 12,
  "accepted": {
    "doses": 1,
    "settings": 0,
    "savedLocations": 0,
    "profiles": 0
  }
}
```

### `GET /v1/sync/pull?since=0&limit=100`

Pull remote changes for the signed-in user.

Response:

```json
{
  "cursor": 12,
  "hasMore": false,
  "changes": {
    "doses": [],
    "settings": [],
    "savedLocations": [],
    "profiles": []
  }
}
```

## Object Types

### Dose

Matches the Swift `DoseRecord` fields and adds sync metadata:

- `id`
- `amount`
- `unit`
- `time`
- `deviceName`
- `notes`
- `tags`
- `people`
- `missed`
- `edited`
- `earlyBySeconds`
- `latitude`
- `longitude`
- `locationName`
- `locationAccuracyMeters`
- `locationCapturedAt`
- `locationSource`
- `createdAt`
- `updatedAt`
- `deletedAt`

### Setting

Use one row per setting key so cross-device changes are small and conflict handling is simple.

- `id`
- `key`
- `value`
- `createdAt`
- `updatedAt`
- `deletedAt`

### Saved Location

Used for autocomplete and home/manual location reuse.

- `id`
- `name`
- `address`
- `latitude`
- `longitude`
- `source`
- `createdAt`
- `updatedAt`
- `deletedAt`

### Profile

Use for display name, email, photo reference, and future Pro entitlement mirror.

- `id`
- `displayName`
- `email`
- `photoURL`
- `createdAt`
- `updatedAt`
- `deletedAt`
