--!strict
-- DataStore persistence, session ownership, schema migration, receipts.
-- Source of truth for Coin, Diamond, equipment, Tome ownership and permanent upgrades
-- (DOC-02 GSD / DOC-04 TDD "permanent vs per-Run" boundary). Per-run state (Gold, HP,
-- in-run XP/Mastery, current build) is NOT stored here; it stays in server RAM per DOC-04.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(ReplicatedStorage.Shared.Vendor.ProfileStore)

local Service = {}

export type PermanentUpgrades = {
    primary: { [string]: number },
    secondary: { [string]: number },
    armor: { [string]: number },
    pet: { [string]: number },
}

export type ProfileData = {
    profileSchemaVersion: number,
    coin: number,
    diamond: number,
    permanentUpgrades: PermanentUpgrades,
    unlockedTomes: { [string]: boolean },
    tomeSlotsUnlocked: number,
    selectedPrimary: string?,
    equippedItems: { [string]: string },
    purchaseReceipts: { [string]: boolean },
    questHistory: { [string]: any },
}

-- CURRENT_SCHEMA_VERSION / TEMPLATE define the "default profile" for a brand new
-- player. Values match DOC-02/DOC-04 concepts (Tome slot entitlement starts at 2 of 4,
-- per DOC-03 BalanceDefaults.tome.defaultSlots); no gameplay numbers are invented here
-- beyond what the shared config already states.
local CURRENT_SCHEMA_VERSION = 1

local TEMPLATE: ProfileData = {
    profileSchemaVersion = CURRENT_SCHEMA_VERSION,
    coin = 0,
    diamond = 0,
    permanentUpgrades = {
        primary = {},
        secondary = {},
        armor = {},
        pet = {},
    },
    unlockedTomes = {},
    tomeSlotsUnlocked = 2,
    selectedPrimary = nil,
    equippedItems = {},
    purchaseReceipts = {},
    questHistory = {},
}

-- Migration steps run in order on load, each bumping profileSchemaVersion by 1.
-- MIGRATIONS[n] upgrades data from version n to version n+1. Intentionally empty at
-- version 1; add the next step here instead of mutating data shape in place.
local MIGRATIONS: { (data: ProfileData) -> () } = {}

-- DataStore name is stable across schema versions; profileSchemaVersion (in Data)
-- is what advances, not this name. Do not rename this when bumping the schema.
local STORE_NAME = "PlayerProfile"

local profileStore = ProfileStore.New(STORE_NAME, TEMPLATE)

-- userId (number) -> Profile object from ProfileStore. nil means "not loaded" --
-- callers MUST treat nil as "load not finished or failed" and block purchase/start.
local activeProfiles: { [number]: any } = {}

local function profileKeyFor(userId: number): string
    return "Player_" .. tostring(userId)
end

local function runMigrations(data: ProfileData)
    local version = data.profileSchemaVersion or 1
    while MIGRATIONS[version] ~= nil do
        MIGRATIONS[version](data)
        version += 1
        data.profileSchemaVersion = version
    end
end

-- Starts a DataStore session for the player. Session lock, retry/backoff and
-- cross-server conflict handling are all provided by ProfileStore; this function
-- only wires migration + Reconcile on top. Returns false on any load failure so
-- callers can block purchase/start per the LOB-01 acceptance criteria.
function Service.loadProfile(player: Player): boolean
    local userId = player.UserId
    if activeProfiles[userId] ~= nil then
        return true
    end

    local profile = profileStore:StartSessionAsync(profileKeyFor(userId), {
        Cancel = function()
            return player.Parent ~= Players
        end,
    })

    if profile == nil then
        -- Session could not be started (stolen by another server, DataStore down,
        -- or the player left before the session resolved). Load error -> blocked.
        return false
    end

    profile:AddUserId(userId)
    profile:Reconcile()
    runMigrations(profile.Data)

    profile.OnSessionEnd:Connect(function()
        activeProfiles[userId] = nil
        local activePlayer = Players:GetPlayerByUserId(userId)
        if activePlayer ~= nil then
            activePlayer:Kick("Your data session ended. Please rejoin.")
        end
    end)

    if player.Parent ~= Players then
        -- Player left while the session was loading; release immediately so no
        -- other server is blocked waiting on this server's lock.
        profile:EndSession()
        return false
    end

    activeProfiles[userId] = profile
    return true
end

function Service.releaseProfile(player: Player)
    local profile = activeProfiles[player.UserId]
    if profile ~= nil then
        profile:EndSession()
    end
end

-- Returns the live, writable Data table, or nil if no session is active for this
-- player (not loaded yet, failed to load, or already released). Every caller that
-- mutates Coin/Diamond/equipment/Tome ownership must check for nil and refuse the
-- purchase/start action per the LOB-01 acceptance criteria.
function Service.getProfile(player: Player): ProfileData?
    local profile = activeProfiles[player.UserId]
    if profile == nil or not profile:IsActive() then
        return nil
    end
    return profile.Data
end

function Service.isLoaded(player: Player): boolean
    return Service.getProfile(player) ~= nil
end

-- Forces an immediate save (e.g. after a purchase) instead of waiting for the
-- library's periodic autosave. Safe to call even if the session is inactive.
function Service.saveProfile(player: Player)
    local profile = activeProfiles[player.UserId]
    if profile ~= nil then
        profile:Save()
    end
end

local function onPlayerAdded(player: Player)
    Service.loadProfile(player)
end

local function onPlayerRemoving(player: Player)
    Service.releaseProfile(player)
end

function Service.init()
    for _, player in Players:GetPlayers() do
        task.spawn(onPlayerAdded, player)
    end
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)

    game:BindToClose(function()
        if game:GetService("RunService"):IsStudio() then
            return
        end
        -- ProfileStore saves active profiles via its own BindToClose hook; wait
        -- here so this server process does not exit before those saves land.
        local pending = 0
        for _, player in Players:GetPlayers() do
            local profile = activeProfiles[player.UserId]
            if profile ~= nil then
                pending += 1
                profile.OnLastSave:Connect(function()
                    pending -= 1
                end)
            end
        end
        local deadline = os.clock() + 30
        while pending > 0 and os.clock() < deadline do
            task.wait(0.1)
        end
    end)
end

return Service
