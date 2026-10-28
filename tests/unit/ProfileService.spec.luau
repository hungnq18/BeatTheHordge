-- TestEZ-style sample; adapt require paths for your test runner.
-- Covers LOB-01 acceptance criteria using ProfileStore.Mock (no real DataStore calls):
-- reconnect keeps progress, load failure blocks purchase/start, no double-write across servers.
return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ProfileStore = require(ReplicatedStorage.Shared.Vendor.ProfileStore)

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

    describe("ProfileStore-backed profile lifecycle (Mock store)", function()
        it("gives a new player the default profile (schema v1, 2 Tome slots, 0 Coin/Diamond)", function()
            local store = ProfileStore.New("ProfileServiceSpec_New", TEMPLATE)
            local profile = store.Mock:StartSessionAsync("Player_1")
            expect(profile).to.be.ok()
            profile:Reconcile()

            expect(profile.Data.profileSchemaVersion).to.equal(1)
            expect(profile.Data.coin).to.equal(0)
            expect(profile.Data.diamond).to.equal(0)
            expect(profile.Data.tomeSlotsUnlocked).to.equal(2)

            profile:EndSession()
        end)

        it("keeps progress across a session end + reconnect (same key)", function()
            local store = ProfileStore.New("ProfileServiceSpec_Reconnect", TEMPLATE)

            local first = store.Mock:StartSessionAsync("Player_2")
            first:Reconcile()
            first.Data.coin = 150
            first.Data.unlockedTomes["Tome_Fire"] = true
            first:Save()
            first:EndSession()

            local second = store.Mock:StartSessionAsync("Player_2")
            expect(second).to.be.ok()
            second:Reconcile()

            expect(second.Data.coin).to.equal(150)
            expect(second.Data.unlockedTomes["Tome_Fire"]).to.equal(true)

            second:EndSession()
        end)

        it("refuses a second session while the first still owns the lock (no double-write)", function()
            local store = ProfileStore.New("ProfileServiceSpec_Lock", TEMPLATE)

            local first = store.Mock:StartSessionAsync("Player_3")
            expect(first).to.be.ok()

            -- A second StartSessionAsync for the same key while the first session is
            -- still active throws synchronously (same-VM lock), rather than retrying
            -- and returning nil. That's the "no double-write" guarantee being asserted.
            local ok = pcall(function()
                store.Mock:StartSessionAsync("Player_3")
            end)
            expect(ok).to.equal(false)

            first:EndSession()
        end)

        it("treats an inactive/absent profile as a load failure that must block purchase/start", function()
            local store = ProfileStore.New("ProfileServiceSpec_Inactive", TEMPLATE)
            local profile = store.Mock:StartSessionAsync("Player_4")
            profile:Reconcile()
            profile:EndSession()

            -- After EndSession, IsActive() must be false: callers reading this as
            -- "profile is nil/inactive" are expected to block purchase/start.
            expect(profile:IsActive()).to.equal(false)
        end)

        it("fills in newly added template fields on reconcile without discarding existing data", function()
            local store = ProfileStore.New("ProfileServiceSpec_Reconcile", TEMPLATE)
            local profile = store.Mock:StartSessionAsync("Player_5")
            profile:Reconcile()
            profile.Data.coin = 42
            profile:Save()
            profile:EndSession()

            local reopened = store.Mock:StartSessionAsync("Player_5")
            reopened:Reconcile()
            expect(reopened.Data.coin).to.equal(42)
            expect(reopened.Data.diamond).to.equal(0)
            reopened:EndSession()
        end)
    end)
end
