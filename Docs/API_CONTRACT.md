# Draft API contract

This is the extraction seam for a future standalone backend. It is not enabled by the current app.

## Base and versioning

- Base path: `/v1`
- Content type: `application/json`
- Authentication: `Authorization: Bearer <token>`
- Dates: ISO 8601 UTC
- Currency: integer coins only

## State endpoints

### `GET /v1/game-state`

Returns the authenticated player's complete game state.

### `PUT /v1/game-state`

Prototype sync endpoint accepting a complete state document. Production should replace client-authoritative economy updates with validated action endpoints and require an idempotency key.

```json
{
  "schemaVersion": 1,
  "coins": 50,
  "inventory": { "grain": 0, "rice": 0, "tomato": 0 },
  "plots": [
    { "id": "UUID", "crop": null }
  ],
  "updatedAt": "2026-09-04T12:00:00Z"
}
```

## Expected errors

Errors use `{ "code": "stable_machine_code", "message": "safe player message" }` with appropriate HTTP status codes. The client must not derive economy outcomes from an error message.

## Planned action endpoints

- `POST /v1/actions/plant`
- `POST /v1/actions/harvest`
- `POST /v1/actions/sell`
- `POST /v1/actions/purchase-upgrade`

Each mutation should accept an idempotency key, validate against authoritative server time, and return the new state version.

## Local save compatibility

The on-device JSON uses the state shape above with `schemaVersion: 1`. The wire format remains v1 and remote sync remains disabled. V1 is the first released format; unversioned saves are not a supported historical format.

- `schemaVersion` must be an integer. Missing, null, malformed, nonpositive, or newer-than-supported versions fail loading without modifying the file. No downgrade or silent reset occurs.
- Unknown object fields at the state, plot, and crop levels are ignored. Unknown inventory keys are ignored without decoding their values. Missing known inventory keys default to zero; known values must remain integers. Unknown fields are not retained when a later action re-encodes state, so incompatible additions must increment the schema version.
- An absent or null plot crop means an empty plot. Unknown planted seed values, invalid known field types, invalid dates/UUIDs, and missing required fields fail decoding; they are not silently discarded.
- Coins, inventory, plot identities/order, and stored crop timestamps survive loading. Dates retain the existing ISO 8601 UTC encoding at whole-second precision; readiness is not recalculated from current balancing data.
- The local codec applies registered migrations consecutively, vN→vN+1, in memory before decoding the current model. Missing steps, thrown errors, malformed output, or a step that skips/repeats a version stop loading. The original file remains intact and the existing retry screen blocks game actions.
- Successful migration alone does not rewrite storage. Only the next successfully saved player action atomically replaces the file with current-version JSON. Wrong-version states are rejected before writing.

`FazendinhaTests/Fixtures/save-v1.json` freezes the released shape with mixed crops, inventory, stable plot UUIDs, and both omitted and null empty crops. `save-v1-unknown-fields.json` exercises additive fields and a missing inventory key. Synthetic v2/v3 transformations exist only in tests to verify ordering and failure behavior. Keep these historical fixtures when adding a real schema version; add its migration and fixtures before changing inventory or progression data.
