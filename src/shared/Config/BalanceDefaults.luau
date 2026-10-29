--!strict
-- Playtest baseline from DOC-03; this is not production balancing approval.
-- primary catalog per DOC-01 GDD §7.2 / §24.2 and DOC-04 TDD §7.1: five Primary
-- Weapons chosen at Lobby, permanent per-Lobby upgrade, no mid-Run swap. Only
-- Sword/Bow/Staff have confirmed baseStats in DOC-04 TDD ("Bảng gốc"); Gun and
-- Scythe baseStats are [CẦN CHỐT] in source and must stay nil, not invented,
-- until Weapon Design publishes them.
return table.freeze({
    run = { survivalPhaseSeconds = 360, survivalPhases = 2 },
    enemy = { hpGrowth = 0.15, hpExponent = 1.3, damageGrowth = 0.08 },
    secondary = { maxLevel = 99, masteryXpPerLevel = 100, upgradeCardXp = 500, damagePerLevel = 0.005, evolutionBonus = 0.25 },
    tome = {
        maxLevel = 30,
        defaultSlots = 2,
        maxSlots = 4,
        -- Slot 3/4 unlock parity per GDD part A §47 (BL-V2): permanent unlock by
        -- Coin OR early unlock by Robux; the old Robux-only policy is
        -- SUPERSEDED. GDD BL-06 / DOC-04 TDD line 7877: "Cần định giá
        -- Coin/Robux chính thức" — prices are [CẦN CHỐT], not invented here.
        -- coinCostBySlot[n] is absent (reads as nil) until Balance publishes a
        -- number; the Coin unlock path must refuse with PRICE_NOT_CONFIGURED
        -- while absent. Left empty rather than {[3]=nil,...}: a nil value
        -- cannot be stored in a Luau table literal, it would just vanish.
        coinCostBySlot = {} :: { [number]: number },
        -- Maps a Roblox Developer Product id (created in Creator Dashboard,
        -- not by this codebase) to the slot it unlocks. Empty until Robux
        -- products exist; ProcessReceipt must reject any unmapped product id.
        developerProductIdToSlot = {} :: { [number]: number },
    },
    xp = { green = 5, purple = 20, red = 100 },
    primary = {
        -- Five Primary IDs are confirmed by DOC-01 GDD §24.2; baseStats are only
        -- confirmed for Sword/Bow/Staff (DOC-04 TDD §7.1 "Bảng gốc"). Gun and
        -- Scythe exist as valid, ownable IDs but carry no baseStats = {} is NOT
        -- used to fake a value: `statsConfirmed = false` marks them [CẦN CHỐT].
        catalog = {
            Sword = { statsConfirmed = true, baseDamage = 20, attackCooldownSeconds = 0.8, critChance = 0.05 },
            Bow = { statsConfirmed = true, baseDamage = 14, attackCooldownSeconds = 0.5, critChance = 0.10 },
            Staff = { statsConfirmed = true, baseDamage = 26, attackCooldownSeconds = 1.3, critChance = 0.03 },
            Gun = { statsConfirmed = false },
            Scythe = { statsConfirmed = false },
        },
        -- Default ownership on a brand new profile. Not stated in DOC-01/02; kept
        -- empty so no Primary is granted until an explicit unlock rule is approved.
        defaultOwned = {},
    },
})
