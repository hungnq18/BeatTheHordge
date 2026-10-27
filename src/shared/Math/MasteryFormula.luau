--!strict
local Mastery = {}
function Mastery.levelFromXP(xp: number, perLevel: number, maxLevel: number): number
    assert(xp >= 0 and perLevel > 0 and maxLevel >= 1)
    return math.min(maxLevel, 1 + math.floor(xp / perLevel))
end
function Mastery.evolutionThreshold(perLevel: number, maxLevel: number): number
    return (maxLevel - 1) * perLevel
end
function Mastery.damageMultiplier(level: number, damagePerLevel: number, evolved: boolean, evolutionBonus: number): number
    local scale = 1 + (level - 1) * damagePerLevel
    return if evolved then scale * (1 + evolutionBonus) else scale
end
return table.freeze(Mastery)
