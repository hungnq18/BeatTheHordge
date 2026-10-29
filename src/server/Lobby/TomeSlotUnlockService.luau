--!strict
-- Unlock 3/4 with Coin or Robux; server receipt validation.
--
-- Scope: DOC-02 GSD SYS-10 (Tome System) slot sub-rules + DOC-01 GDD part A
-- §47 (BL-V2): "Ô thứ 3 và Ô thứ 4 được mở khóa vĩnh viễn bằng Coin hoặc mở
-- sớm bằng Robux; chính sách Robux-only cũ đã SUPERSEDED." GDD BL-06 requires
-- Coin/Robux price parity and says prices are [CẦN CHỐT] — this module must
-- not invent a number; see BalanceDefaults.tome.coinCostBySlot.
--
-- Acceptance (ticket Tome Slot Unlock):
--   - 2 slots default (already the ProfileService template default).
--   - Unlock is permanent (writes ProfileData.tomeSlotsUnlocked, persisted).
--   - Coin and Robux grant the exact same entitlement (DOC-04 TDD LOB-04:
--     "Same functional entitlement; no double purchase or advantage from
--     payment channel") via one shared applySlotUnlock path.
--   - Never grants a slot the client merely claims to have purchased
--     (LOB-06: "Server rejects forged price, ownership, insufficient
--     currency or replayed receipt").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteNames = require(ReplicatedStorage.Shared.Contracts.RemoteNames)
local BalanceDefaults = require(ReplicatedStorage.Shared.Config.BalanceDefaults)
local ProfileService = require(script.Parent.Parent.Economy.ProfileService)

local Service = {}

local UNLOCKABLE_SLOTS = { [3] = true, [4] = true }

local function coinCostForSlot(slotNumber: number): number?
    return BalanceDefaults.tome.coinCostBySlot[slotNumber]
end

-- Shared entitlement grant used by BOTH the Coin and the Robux path, so the
-- two payment channels can never diverge in what they grant (LOB-04 parity).
-- Mutates profileData.tomeSlotsUnlocked in place; caller persists.
local function applySlotUnlock(profileData, slotNumber: number)
    if profileData.tomeSlotsUnlocked < slotNumber then
        profileData.tomeSlotsUnlocked = slotNumber
    end
end

-- Pure decision core for the Coin path: no Player/ProfileService dependency.
-- Mutates profileData (coin spend + slot grant) only on success.
function Service.evaluateCoinUnlock(profileData, slotNumber: number): (boolean, string?)
    if profileData == nil then
        return false, "PROFILE_NOT_LOADED"
    end

    if not UNLOCKABLE_SLOTS[slotNumber] then
        return false, "INVALID_SLOT"
    end

    if profileData.tomeSlotsUnlocked >= slotNumber then
        return false, "ALREADY_UNLOCKED"
    end

    -- DOC-02 "Full Tome Slot Handling" / LOB-04/LOB-05 require sequential
    -- unlock: slot 4 is only meaningful once slot 3 is owned, and granting it
    -- out of order would desync with GDD's 2/3/4 slot progression.
    if slotNumber == 4 and profileData.tomeSlotsUnlocked < 3 then
        return false, "SLOT_3_REQUIRED_FIRST"
    end

    local cost = coinCostForSlot(slotNumber)
    if cost == nil then
        -- GDD BL-06: price not yet confirmed by Balance. Refuse rather than
        -- invent a number per the ticket's "không tự thay đổi gameplay" rule.
        return false, "PRICE_NOT_CONFIGURED"
    end

    if profileData.coin < cost then
        return false, "INSUFFICIENT_COIN"
    end

    profileData.coin -= cost
    applySlotUnlock(profileData, slotNumber)
    return true, nil
end

-- Pure decision core for the Robux (MarketplaceService ProcessReceipt) path.
-- `purchaseId` is the receipt's unique PurchaseId; idempotency depends on it
-- being stored before this function is called a second time for the same
-- purchase (replayed receipts must short-circuit to "already granted").
function Service.evaluateReceiptUnlock(profileData, developerProductId: number, purchaseId: string): (boolean, string?)
    if profileData == nil then
        return false, "PROFILE_NOT_LOADED"
    end

    if profileData.purchaseReceipts[purchaseId] then
        -- Already granted in a prior call (e.g. Roblox retrying the same
        -- receipt). Idempotent: report success without granting again.
        return true, nil
    end

    local slotNumber = BalanceDefaults.tome.developerProductIdToSlot[developerProductId]
    if slotNumber == nil then
        return false, "UNKNOWN_PRODUCT"
    end

    -- Robux unlock is intentionally NOT gated by ALREADY_UNLOCKED/sequential
    -- order the way Coin is: a replayed or repeat-purchased receipt for an
    -- already-owned slot must still be marked granted (player keeps the
    -- Robux spend's entitlement) without raising a currency error.
    applySlotUnlock(profileData, slotNumber)
    profileData.purchaseReceipts[purchaseId] = true
    return true, nil
end

-- Thin Player-facing adapter over evaluateCoinUnlock: reads live profile
-- state and persists on success.
function Service.unlockSlotWithCoin(player: Player, slotNumber: number): (boolean, string?)
    local profileData = ProfileService.getProfile(player)
    local ok, reason = Service.evaluateCoinUnlock(profileData, slotNumber)
    if ok then
        ProfileService.saveProfile(player)
    end
    return ok, reason
end

-- MarketplaceService.ProcessReceipt callback body. Returns the Enum the
-- caller should hand back to Roblox: NotProcessedYet if the profile is not
-- loaded (per DOC-02 "thất bại không mất tiền" — Roblox will retry later
-- without charging again), otherwise PurchaseGranted once the receipt is
-- idempotently recorded.
function Service.processReceipt(receiptInfo: { PlayerId: number, ProductId: number, PurchaseId: string }): Enum.ProductPurchaseDecision
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if player == nil then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local profileData = ProfileService.getProfile(player)
    if profileData == nil then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local ok = Service.evaluateReceiptUnlock(profileData, receiptInfo.ProductId, receiptInfo.PurchaseId)
    if not ok then
        -- Unknown product: never silently swallow a real purchase. Treat as
        -- not-yet-processed so Roblox retries while this gets investigated;
        -- never return PurchaseGranted for a product this module can't map.
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    ProfileService.saveProfile(player)
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onRequestTomeSlotUnlock(player: Player, slotNumber: number)
    local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
    if remotes == nil then
        return
    end

    local ok, reason = Service.unlockSlotWithCoin(player, slotNumber)
    if not ok then
        local errorFeedback = remotes:FindFirstChild(remoteNames.ErrorFeedback)
        if errorFeedback then
            errorFeedback:FireClient(player, "RequestTomeSlotUnlock", reason)
        end
    end
end

function Service.init()
    local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
    local requestTomeSlotUnlock = remotes:WaitForChild(remoteNames.RequestTomeSlotUnlock)
    requestTomeSlotUnlock.OnServerEvent:Connect(onRequestTomeSlotUnlock)

    -- NOTE: MarketplaceService.ProcessReceipt is a single, server-wide
    -- callback slot, so it is NOT set here. The composition root (Bootstrap)
    -- wires `MarketplaceService.ProcessReceipt = Service.processReceipt`
    -- after Service.init(), since no other module currently claims it.
end

return Service
