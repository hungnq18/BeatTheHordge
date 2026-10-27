--!strict
-- Playtest baseline from DOC-03; this is not production balancing approval.
return table.freeze({
    run = { survivalPhaseSeconds = 360, survivalPhases = 2 },
    enemy = { hpGrowth = 0.15, hpExponent = 1.3, damageGrowth = 0.08 },
    secondary = { maxLevel = 99, masteryXpPerLevel = 100, upgradeCardXp = 500, damagePerLevel = 0.005, evolutionBonus = 0.25 },
    tome = { maxLevel = 30, defaultSlots = 2, maxSlots = 4 },
    xp = { green = 5, purple = 20, red = 100 },
})
