-- TestEZ-style sample; adapt require paths for your test runner.
-- Covers the EquipPrimary ticket acceptance criteria using ProfileStore.Mock
-- (no real DataStore calls, no Player instance required):
--   - no equip of an unowned Primary
--   - equip persists across reconnect (ProfileStore save + reopen)
--   - no Primary change once a Run has started
--   - RunLoadoutSnapshot freezes the owned, validated Primary
return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ProfileStore = require(ReplicatedStorage.Shared.Vendor.ProfileStore)

    -- LobbyService lives under ServerScriptService/GameServer/Lobby per the
    -- Rojo mapping in default.project.json, not under ReplicatedStorage.
    local LobbyService = require(game:GetService("ServerScriptService").GameServer.Lobby.LobbyService)

    local TEMPLATE = {
        profileSchemaVersion = 1,
        coin = 0,
        diamond = 0,
        permanentUpgrades = { primary = {}, secondary = {}, armor = {}, pet = {} },
        unlockedTomes = {},
        tomeSlotsUnlocked = 2,
        selectedPrimary = nil,
        equippedItems = {},
        purchaseReceipts = {},
        questHistory = {},
    }

    local nextStoreId = 0

    local function newProfileData(ownedPrimaries: { [string]: number }?)
        nextStoreId += 1
        local store = ProfileStore.New("LobbyServiceSpec_" .. tostring(nextStoreId), TEMPLATE)
        local profile = store.Mock:StartSessionAsync("Player_1")
        profile:Reconcile()
        if ownedPrimaries then
            profile.Data.permanentUpgrades.primary = ownedPrimaries
        end
        return profile
    end

    describe("EquipPrimary (LOB-01) — ownership and Run-lock rules", function()
        it("refuses to equip a Primary the player does not own", function()
            local profile = newProfileData({})
            local ok, reason = LobbyService.evaluateEquipPrimary(profile.Data, "Sword", false)

            expect(ok).to.equal(false)
            expect(reason).to.equal("PRIMARY_NOT_OWNED")
            expect(profile.Data.selectedPrimary).to.equal(nil)

            profile:EndSession()
        end)

        it("refuses an unknown Primary id even if present in permanentUpgrades", function()
            local profile = newProfileData({ NotARealWeapon = 1 })
            local ok, reason = LobbyService.evaluateEquipPrimary(profile.Data, "NotARealWeapon", false)

            expect(ok).to.equal(false)
            expect(reason).to.equal("UNKNOWN_PRIMARY")

            profile:EndSession()
        end)

        it("equips an owned, known Primary while not in a Run", function()
            local profile = newProfileData({ Bow = 1 })
            local ok, reason = LobbyService.evaluateEquipPrimary(profile.Data, "Bow", false)

            expect(ok).to.equal(true)
            expect(reason).to.equal(nil)
            expect(profile.Data.selectedPrimary).to.equal("Bow")

            profile:EndSession()
        end)

        it("refuses to change Primary while a Run is active (no mid-Run swap)", function()
            local profile = newProfileData({ Sword = 1, Bow = 1 })
            profile.Data.selectedPrimary = "Sword"

            local ok, reason = LobbyService.evaluateEquipPrimary(profile.Data, "Bow", true)

            expect(ok).to.equal(false)
            expect(reason).to.equal("RUN_IN_PROGRESS")
            expect(profile.Data.selectedPrimary).to.equal("Sword")

            profile:EndSession()
        end)

        it("blocks equip when the profile failed to load (nil profileData)", function()
            local ok, reason = LobbyService.evaluateEquipPrimary(nil, "Sword", false)

            expect(ok).to.equal(false)
            expect(reason).to.equal("PROFILE_NOT_LOADED")
        end)

        it("persists the equipped Primary across a session end + reconnect", function()
            local store = ProfileStore.New("LobbyServiceSpec_Reconnect", TEMPLATE)

            local first = store.Mock:StartSessionAsync("Player_2")
            first:Reconcile()
            first.Data.permanentUpgrades.primary = { Staff = 1 }
            local ok = LobbyService.evaluateEquipPrimary(first.Data, "Staff", false)
            expect(ok).to.equal(true)
            first:Save()
            first:EndSession()

            local second = store.Mock:StartSessionAsync("Player_2")
            second:Reconcile()
            expect(second.Data.selectedPrimary).to.equal("Staff")

            second:EndSession()
        end)
    end)

    describe("RunLoadoutSnapshot — immutable freeze at Lobby->RunInit", function()
        it("returns nil when no Primary has been selected", function()
            local profile = newProfileData({ Sword = 1 })
            local snapshot = LobbyService.evaluateRunLoadoutSnapshot(profile.Data)

            expect(snapshot).to.equal(nil)

            profile:EndSession()
        end)

        it("returns nil when the selected Primary is no longer owned", function()
            local profile = newProfileData({})
            profile.Data.selectedPrimary = "Sword"

            local snapshot = LobbyService.evaluateRunLoadoutSnapshot(profile.Data)

            expect(snapshot).to.equal(nil)

            profile:EndSession()
        end)

        it("freezes the owned, selected Primary into a snapshot", function()
            local profile = newProfileData({ Sword = 1 })
            profile.Data.selectedPrimary = "Sword"

            local snapshot = LobbyService.evaluateRunLoadoutSnapshot(profile.Data)

            expect(snapshot).to.be.ok()
            expect(snapshot.primaryId).to.equal("Sword")

            local mutateOk = pcall(function()
                (snapshot :: any).primaryId = "Bow"
            end)
            expect(mutateOk).to.equal(false)

            profile:EndSession()
        end)

        it("is not affected by a later selectedPrimary change on the profile", function()
            local profile = newProfileData({ Sword = 1, Bow = 1 })
            profile.Data.selectedPrimary = "Sword"
            local snapshot = LobbyService.evaluateRunLoadoutSnapshot(profile.Data)

            profile.Data.selectedPrimary = "Bow"

            expect(snapshot.primaryId).to.equal("Sword")

            profile:EndSession()
        end)
    end)
end
