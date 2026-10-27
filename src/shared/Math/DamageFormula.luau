--!strict
local Damage = {}
function Damage.resolve(base: number, flat: number, buffPercent: number, critMultiplier: number, targetArmor: number): number
    assert(targetArmor > -100)
    return math.max(0, (base + flat) * (1 + buffPercent) * critMultiplier * (100 / (100 + targetArmor)))
end
return table.freeze(Damage)
