--!strict
local Scaling = {}
function Scaling.forSpawn(baseHP: number, baseDamage: number, survivalSeconds: number, cfg: any)
    assert(baseHP > 0 and baseDamage >= 0 and survivalSeconds >= 0)
    local minutes = survivalSeconds / 60
    return {
        maxHP = baseHP * (1 + cfg.hpGrowth * minutes) ^ cfg.hpExponent,
        damage = baseDamage * (1 + cfg.damageGrowth * minutes),
    }
end
return table.freeze(Scaling)
