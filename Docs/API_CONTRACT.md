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

