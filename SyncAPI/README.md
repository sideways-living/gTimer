# gTimer Sync API

Small cross-platform sync API for gTimer dose history, settings, profile data, saved locations, account login, and device tokens.

This is a first backend slice for local development and protocol testing. It uses only built-in Node modules and stores data as JSON files under `SyncAPI/data`. For production, keep the HTTP contract and replace the file store with Postgres or another audited database.

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

## Sync Model

Clients are local-first:

- Every object has a stable `id`.
- Every object has `createdAt`, `updatedAt`, and optional `deletedAt`.
- Deleted objects are sent as tombstones with `deletedAt`, not removed immediately.
- Clients push local changes, then pull remote changes newer than their last cursor.
- The server returns a monotonically increasing `cursor`.
- The first production implementation should encrypt transport with HTTPS and use a proper account identity provider.

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
```

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
