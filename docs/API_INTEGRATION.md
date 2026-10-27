# Integration with NestJS Admin API

## Public contract

The Roblox **server**, not the Roblox client, retrieves a **published** configuration from the separate `beat-the-horde-admin` deployment. A staging example is:

`GET https://api.example.com/api/v1/game-config/solo?channel=development`

The expected payload contains `schemaVersion`, `configVersion`, `environment`, and a `payload` whose nested fields are validated against a pinned schema. Ensure the backend route is a *published read-only* endpoint; admin draft/publish endpoints require authentication and must never be accessible to the game client.

## Setup checklist

1. Publish the NestJS admin API to a reachable HTTPS staging host. `localhost` on your Ubuntu machine is not reachable from Roblox cloud servers.
2. Update the **server-only** endpoint placeholder in `src/server/Core/ConfigService.luau`, or replace it with a server-controlled environment/channel config. Do not accept host URLs from client remotes.
3. Enable HTTP Requests in Roblox Experience Settings for the test place.
4. Complete ConfigValidator and LastKnownGood fallback before production; use immutable per-Run snapshot.
5. Test `GET` response against the pinned schema; verify old runs keep their version when a new config is published.
6. Keep a server-owned configVersion/seed in telemetry. Never store backend credentials in ReplicatedStorage or LocalScripts.

## Cross-repository workflow

1. Change API spec in docs with explicit schema version.
2. Implement and validate draft/publish/read paths in Admin repository.
3. Update the Roblox consumer validator and acceptance tests, preserving backward compatibility.
4. Deploy Admin to staging, then run Roblox staging integration tests.
5. Publish compatible production versions only after passing validation.

No Git submodules or direct TypeScript imports in Luau are required.
