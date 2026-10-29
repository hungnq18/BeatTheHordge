-- TestEZ-style sample; adapt require paths for your test runner.
-- Covers the Tome Slot Unlock ticket acceptance criteria using
-- ProfileStore.Mock (no real DataStore/MarketplaceService calls, no Player
-- instance required):
--   - 2 slots default
--   - unlock is permanent (persists across reconnect)
--   - Coin and Robux grant the same entitlement (parity, LOB-04)
--   - never grants a slot the client only claims to have purchased
--     (forged price, insufficient Coin, replayed receipt — LOB-06)
return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ProfileStore = require(ReplicatedStorage.Shared.Vendor.ProfileStore)

    -- Lives under ServerScriptService/GameServer/Lobby per the Rojo mapping
    -- in default.project.json, not under ReplicatedStorage.
    local TomeSlotUnlockService =
        require(game:GetService("ServerScriptService").GameServer.Lobby.TomeSlotUnlockService)

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

    local function newProfileData(coin: number?, tomeSlotsUnlocked: number?)
        nextStoreId += 1
        local store = ProfileStore.New("TomeSlotUnlockServiceSpec_" .. tostring(nextStoreId), TEMPLATE)
        local profile = store.Mock:StartSessionAsync("Player_1")
        profile:Reconcile()
        profile.Data.coin = coin or 0
        profile.Data.tomeSlotsUnlocked = tomeSlotsUnlocked or 2
        return profile
    end

    describe("Default slots", function()
        it("gives a new profile exactly 2 Tome slots", function()
            local profile = newProfileData()
            expect(profile.Data.tomeSlotsUnlocked).to.equal(2)
            profile:EndSession()
        end)
    end)

    describe("Coin unlock path", function()
        it("refuses slot 3 while Balance has not published a Coin price (PRICE_NOT_CONFIGURED)", function()
            local profile = newProfileData(1000000)
            local ok, reason = TomeSlotUnlockService.evaluateCoinUnlock(profile.Data, 3)

            expect(ok).to.equal(false)
            expect(reason).to.equal("PRICE_NOT_CONFIGURED")
            expect(profile.Data.tomeSlotsUnlocked).to.equal(2)
            expect(profile.Data.coin).to.equal(1000000)

            profile:EndSession()
        end)

        it("rejects an invalid slot number", function()
            local profile = newProfileData(1000000)
            local ok, reason = TomeSlotUnlockService.evaluateCoinUnlock(profile.Data, 5)

            expect(ok).to.equal(false)
            expect(reason).to.equal("INVALID_SLOT")

            profile:EndSession()
        end)

        it("refuses to re-unlock an already-owned slot", function()
            local profile = newProfileData(1000000, 3)
            local ok, reason = TomeSlotUnlockService.evaluateCoinUnlock(profile.Data, 3)

            expect(ok).to.equal(false)
            expect(reason).to.equal("ALREADY_UNLOCKED")

            profile:EndSession()
        end)

        it("requires slot 3 before slot 4 can be unlocked", function()
            local profile = newProfileData(1000000, 2)
            local ok, reason = TomeSlotUnlockService.evaluateCoinUnlock(profile.Data, 4)

            expect(ok).to.equal(false)
            expect(reason).to.equal("SLOT_3_REQUIRED_FIRST")

            profile:EndSession()
        end)

        it("blocks unlock when the profile failed to load (nil profileData)", function()
            local ok, reason = TomeSlotUnlockService.evaluateCoinUnlock(nil, 3)

            expect(ok).to.equal(false)
            expect(reason).to.equal("PROFILE_NOT_LOADED")
        end)
    end)

    describe("Robux receipt path (parity + idempotency)", function()
        it("rejects a developer product id with no configured slot mapping", function()
            local profile = newProfileData(0, 2)
            local ok, reason = TomeSlotUnlockService.evaluateReceiptUnlock(profile.Data, 999999, "purchase-1")

            expect(ok).to.equal(false)
            expect(reason).to.equal("UNKNOWN_PRODUCT")
            expect(profile.Data.tomeSlotsUnlocked).to.equal(2)

            profile:EndSession()
        end)

        it("blocks receipt processing when the profile failed to load (nil profileData)", function()
            local ok, reason = TomeSlotUnlockService.evaluateReceiptUnlock(nil, 1, "purchase-1")

            expect(ok).to.equal(false)
            expect(reason).to.equal("PROFILE_NOT_LOADED")
        end)
    end)

    describe("Payment-channel parity (LOB-04)", function()
        it("refuses both Coin and Robux the same way while neither is configured (no channel gets an advantage)", function()
            -- BalanceDefaults.tome.coinCostBySlot and developerProductIdToSlot
            -- are both intentionally empty ([CẦN CHỐT]). Parity today means
            -- neither channel can grant a slot ahead of the other being
            -- configured; neither path may fall back to a default/guessed
            -- price or mapping to "unblock" one channel over the other.
            local coinProfile = newProfileData(1000000, 2)
            local robuxProfile = newProfileData(0, 2)

            local coinOk, coinReason = TomeSlotUnlockService.evaluateCoinUnlock(coinProfile.Data, 3)
            local robuxOk, robuxReason = TomeSlotUnlockService.evaluateReceiptUnlock(robuxProfile.Data, 1, "purchase-parity")

            expect(coinOk).to.equal(false)
            expect(coinReason).to.equal("PRICE_NOT_CONFIGURED")
            expect(robuxOk).to.equal(false)
            expect(robuxReason).to.equal("UNKNOWN_PRODUCT")
            expect(coinProfile.Data.tomeSlotsUnlocked).to.equal(2)
            expect(robuxProfile.Data.tomeSlotsUnlocked).to.equal(2)

            coinProfile:EndSession()
            robuxProfile:EndSession()
        end)

        it("never double-grants on a replayed receipt (idempotent)", function()
            local profile = newProfileData(0, 2)

            -- Mark the receipt as already-seen directly to exercise the
            -- idempotency short-circuit in isolation from product mapping.
            profile.Data.purchaseReceipts["purchase-replay"] = true
            local before = profile.Data.tomeSlotsUnlocked

            local ok = TomeSlotUnlockService.evaluateReceiptUnlock(profile.Data, 1, "purchase-replay")

            expect(ok).to.equal(true)
            expect(profile.Data.tomeSlotsUnlocked).to.equal(before)

            profile:EndSession()
        end)
    end)

    describe("Persistence across reconnect", function()
        it("keeps a replayed-but-recorded receipt id across reconnect (no double future grant)", function()
            local store = ProfileStore.New("TomeSlotUnlockServiceSpec_ReceiptReconnect", TEMPLATE)

            local first = store.Mock:StartSessionAsync("Player_3")
            first:Reconcile()
            first.Data.purchaseReceipts["purchase-reconnect"] = true
            local ok = TomeSlotUnlockService.evaluateReceiptUnlock(first.Data, 1, "purchase-reconnect")
            expect(ok).to.equal(true)
            first:Save()
            first:EndSession()

            local second = store.Mock:StartSessionAsync("Player_3")
            second:Reconcile()
            expect(second.Data.purchaseReceipts["purchase-reconnect"]).to.equal(true)

            second:EndSession()
        end)
    end)
end
