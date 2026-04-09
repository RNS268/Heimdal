# Settings Backend Module (Smart Helmet)

Production-ready backend module for:
- Connected Gear (Bluetooth)
- Safety & Alerts
- App Preferences

## Folder Structure

```text
backend/
  models/
  controllers/
  routes/
  services/
  middleware/
  config/
  app.js
  server.js
  package.json
```

## Run

```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

## API Contract

All routes use `/settings/*` and require user identity from:
- `Authorization: Bearer <JWT>` (`sub`/`user_id` claim), or
- `x-user-id` header (dev fallback)

### 1) Connected Gear

#### GET `/settings/devices`
Returns only supported + connected devices with non-empty capabilities.

Example response:
```json
{
  "success": true,
  "data": [
    {
      "_id": "66a1ff6a1f7391f3c7d4cc13",
      "device_id": "esp32-helmet-01",
      "user_id": "user_123",
      "name": "ESP32 Helmet",
      "type": "helmet",
      "is_connected": true,
      "last_seen": "2026-04-09T17:30:00.000Z",
      "capabilities": ["crash_detection", "telemetry"]
    }
  ]
}
```

#### POST `/settings/devices/update`
Ensures one active helmet per user and upserts device status.

Request:
```json
{
  "device_id": "esp32-helmet-01",
  "name": "ESP32 Helmet",
  "type": "helmet",
  "is_connected": true,
  "capabilities": ["crash_detection", "telemetry"]
}
```

### 2) Safety & Alerts

#### GET `/settings/safety`
```json
{
  "success": true,
  "data": {
    "user_id": "user_123",
    "crash_sensitivity": "medium",
    "auto_sos": true,
    "thresholds": {
      "g_force_threshold": 5,
      "sensitivity_factor": 0.6
    }
  }
}
```

#### POST `/settings/safety`
When sensitivity changes, backend creates a command for connected helmet and publishes a realtime event.

Request:
```json
{
  "crash_sensitivity": "high",
  "auto_sos": false
}
```

### 3) Emergency Contacts

#### GET `/settings/emergency-contacts`
```json
{
  "success": true,
  "data": {
    "user_id": "user_123",
    "contacts": [
      { "name": "Alice", "phone": "+14155551212" }
    ]
  }
}
```

#### POST `/settings/emergency-contacts`
Rules enforced:
- max 5 contacts
- phone normalization (E.164)
- duplicate detection

Request:
```json
{
  "contacts": [
    { "name": "Alice", "phone": "(415) 555-1212" },
    { "name": "Bob", "phone": "+1 415 555 3434" }
  ]
}
```

### 4) App Settings

#### GET `/settings/app`
```json
{
  "success": true,
  "data": {
    "user_id": "user_123",
    "theme": "dark",
    "units": "metric",
    "speed_unit_label": "km/h"
  }
}
```

#### POST `/settings/app`
```json
{
  "theme": "light",
  "units": "imperial"
}
```

### 5) Telemetry Unit Conversion

#### POST `/settings/telemetry/normalize`
Converts telemetry payload to the user's selected app units.

Request:
```json
{
  "payload": {
    "speed": 82.4,
    "units": "metric",
    "battery": 88
  }
}
```

## Business Logic Implemented

- Filters only connected, supported devices with valid capabilities.
- Rejects unsupported device types and invalid sensitivity values.
- Normalizes phone numbers and blocks duplicates.
- Enforces one active helmet per user.
- Propagates crash sensitivity updates to connected helmet via command outbox (`DeviceCommand`).
- Publishes realtime settings events through a dedicated service.
- Stores Auto-SOS preference and allows enforcement in crash pipeline (see `services/emergency-policy.service.js`).
- Supports telemetry unit conversion with `services/unit-conversion.service.js`.
