# beat-the-horde-roblox

Standalone **Roblox Luau + Rojo repository** for Beat the Horde (Solo MVP). Not a monorepo: it contains no Next.js, NestJS, Prisma or PostgreSQL source.

## Layout

```text
beat-the-horde-roblox/
├── default.project.json          # Rojo mapping, independent repository root
├── aftman.toml                    # Tool pinning
├── src/
│   ├── client/                   # LocalScripts / client controllers
│   ├── server/                   # ServerScriptService/GameServer
│   │   ├── Core/                 # Config, clock, run state
│   │   ├── Lobby/                # Equipment, Tome slots, quests, gacha
│   │   ├── Combat/               # Weapons, damage, enemy, boss
│   │   ├── Progression/          # XP, cards, mastery, Tome
│   │   ├── Economy/              # Profile, rewards, merchant
│   │   └── Telemetry/
│   └── shared/                   # Public math, types, remote contracts
├── tests/                        # Unit and integration scaffolding
├── studio/                       # Optional local .rbxl snapshots, not committed
└── docs/                         # Roblox-specific architecture and API integration
```

## Tools and local setup

Install [Rojo](https://rojo.space/) and the Roblox Studio Rojo plugin, then:

```bash
rojo serve default.project.json
```

Connect to a **development** Roblox Studio place. Only scripts in the Rojo mappings are synchronized. Do not overwrite the designer's shared Team Create map. The repo does not include an actual place file.

## Related repositories

- **beat-the-horde-docs** — gameplay rules and full design documentation.
- **beat-the-horde-admin** — Next.js frontend, NestJS backend, PostgreSQL config and deployment.

This repository reads published balance settings from the Admin API using server-side `HttpService`; see [`docs/API_INTEGRATION.md`](docs/API_INTEGRATION.md). Permanent player data lives in **Roblox DataStore**, not Admin PostgreSQL.

## Status and cautions

This is a starter scaffold, **not a complete playable game**. Most gameplay modules are stubs. Admin URL is a placeholder, ConfigService validation is partial, remote handlers are not wired, and full production-grade persistence/auth and E2E tests remain to be implemented.

# BeatTheHordge