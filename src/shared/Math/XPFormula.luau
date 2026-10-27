--!strict
local XPFormula = {}
function XPFormula.nextLevelXP(level: number): number
    assert(level >= 1 and level % 1 == 0)
    if level <= 10 then return 60 * level end
    if level <= 25 then return 600 + 150 * (level - 10) end
    return 3200 * 1.12 ^ (level - 25)
end
function XPFormula.levelFromTotalXP(totalXP: number): number
    assert(totalXP >= 0)
    local level = 1
    while totalXP >= XPFormula.nextLevelXP(level) do
        totalXP -= XPFormula.nextLevelXP(level)
        level += 1
    end
    return level
end
return table.freeze(XPFormula)
