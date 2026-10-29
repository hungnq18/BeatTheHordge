--!strict
-- Read owned loadout; equip Primary; set Secondary targeting preference.
--
-- Scope: DOC-02 GSD SYS-17 (Lobby Equipment & Permanent Upgrades), the Lobby
-- Loadout sub-section (DOC-04 TDD "Lobby system scope"). Server authoritative:
-- client only sends a RequestLobbyEquip intent, this module validates and is
-- the sole writer of ProfileData.selectedPrimary.
--
-- Acceptance (ticket LOB EquipPrimary):
--   - No equip of an unowned Primary (DOC-01 GDD §7.2.1 ownership rule).
--   - Equip persists across reconnect (writes through ProfileService).
--   - No Primary change once a Run has started (DOC-02 LOB-01 "no mid-Run
--     Primary swap"; DOC-04 TDD §7.1 "khóa đổi sau Start Run" [APPROVED]).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteNames = require(ReplicatedStorage.Shared.Contracts.RemoteNames)
local BalanceDefaults = require(ReplicatedStorage.Shared.Config.BalanceDefaults)
local ProfileService = require(script.Parent.Parent.Economy.ProfileService)

local Service = {}

export type RunLoadoutSnapshot = {
    primaryId: string,
}

-- userId -> true while that player's Run is active (RunInit..Results). Owned
-- by this module; Run-lifecycle code (RunStateMachine wiring, out of this
-- ticket's scope) must call Service.setRunActive at Lobby<->Run transitions.
local playerRunActive: { [number]: boolean } = {}

local function primaryCatalog(): { [string]: any }
    return BalanceDefaults.primary.catalog
end

local function isOwnedPrimary(profileData, primaryId: string): boolean
    local owned = profileData.permanentUpgrades and profileData.permanentUpgrades.primary
    return owned ~= nil and owned[primaryId] ~= nil
end

-- True while the player is mid-Run; equip must be refused during this window.
function Service.isRunActiveForUserId(userId: number): boolean
    return playerRunActive[userId] == true
end

function Service.isRunActive(player: Player): boolean
    return Service.isRunActiveForUserId(player.UserId)
end

-- Called by Run-lifecycle code on Lobby->RunInit and Run->Results transitions.
function Service.setRunActive(player: Player, active: boolean)
    if active then
        playerRunActive[player.UserId] = true
    else
        playerRunActive[player.UserId] = nil
    end
end

-- Pure decision core: no Player/ProfileService dependency, so unit tests can
-- exercise every branch directly against a plain ProfileData table. Returns
-- false plus a reason code on any rejection; mutates profileData.selectedPrimary
-- in place on success (the caller is responsible for persisting it).
function Service.evaluateEquipPrimary(profileData, primaryId: string, runActive: boolean): (boolean, string?)
    if type(primaryId) ~= "string" then
        return false, "INVALID_PRIMARY_ID"
    end

    if profileData == nil then
        -- Profile not loaded/failed per LOB-01 acceptance criteria: block.
        return false, "PROFILE_NOT_LOADED"
    end

    if runActive then
        return false, "RUN_IN_PROGRESS"
    end

    if primaryCatalog()[primaryId] == nil then
        return false, "UNKNOWN_PRIMARY"
    end

    if not isOwnedPrimary(profileData, primaryId) then
        return false, "PRIMARY_NOT_OWNED"
    end

    profileData.selectedPrimary = primaryId
    return true, nil
end

-- Thin Player-facing adapter over evaluateEquipPrimary: reads live state from
-- ProfileService/playerRunActive and persists on success.
function Service.equipPrimary(player: Player, primaryId: string): (boolean, string?)
    local profileData = ProfileService.getProfile(player)
    local ok, reason = Service.evaluateEquipPrimary(profileData, primaryId, Service.isRunActive(player))
    if ok then
        ProfileService.saveProfile(player)
    end
    return ok, reason
end

-- Pure decision core for the RunLoadoutSnapshot freeze, usable without a
-- Player instance. Re-validates ownership/catalog at snapshot time: both may
-- have changed since selection (e.g. config republish), and the Run must
-- never start with a now-invalid Primary.
function Service.evaluateRunLoadoutSnapshot(profileData): RunLoadoutSnapshot?
    if profileData == nil then
        return nil
    end

    local primaryId = profileData.selectedPrimary
    if primaryId == nil then
        return nil
    end

    if primaryCatalog()[primaryId] == nil or not isOwnedPrimary(profileData, primaryId) then
        return nil
    end

    return table.freeze({ primaryId = primaryId })
end

-- Freezes the current, already-validated selectedPrimary into an immutable
-- snapshot at Lobby->RunInit per DOC-02 "Dungeon / Run Entry: ... freeze an
-- immutable RunConfig and RunLoadoutSnapshot ... Only approved and unlocked
-- items are copied to the snapshot." Returns nil if the player has no owned,
-- valid Primary selected; callers must block Run start on nil.
function Service.buildRunLoadoutSnapshot(player: Player): RunLoadoutSnapshot?
    return Service.evaluateRunLoadoutSnapshot(ProfileService.getProfile(player))
end

local function onRequestLobbyEquip(player: Player, primaryId: string)
    local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
    if remotes == nil then
        return
    end

    local ok, reason = Service.equipPrimary(player, primaryId)
    if not ok then
        local errorFeedback = remotes:FindFirstChild(remoteNames.ErrorFeedback)
        if errorFeedback then
            errorFeedback:FireClient(player, "RequestLobbyEquip", reason)
        end
    end
end

local function onPlayerRemoving(player: Player)
    playerRunActive[player.UserId] = nil
end

function Service.init()
    local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
    local requestLobbyEquip = remotes:WaitForChild(remoteNames.RequestLobbyEquip)
    requestLobbyEquip.OnServerEvent:Connect(onRequestLobbyEquip)

    Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return Service
