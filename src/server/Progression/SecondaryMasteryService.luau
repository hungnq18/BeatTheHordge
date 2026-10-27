--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Formula = require(ReplicatedStorage.Shared.Math.MasteryFormula)
local defaults = require(ReplicatedStorage.Shared.Config.BalanceDefaults)
local Service = {}
function Service.newState(equippedAt: number)
    return { equippedAt = equippedAt, masteryXP = 0, level = 1, evolved = false }
end
function Service.grantPickup(state: any, value: number, pickupTime: number)
    if pickupTime < state.equippedAt then return false end
    state.masteryXP += value
    state.level = Formula.levelFromXP(state.masteryXP, defaults.secondary.masteryXpPerLevel, defaults.secondary.maxLevel)
    if state.level == defaults.secondary.maxLevel and not state.evolved then
        state.evolved = true
        return true
    end
    return false
end
function Service.grantUpgradeCard(state: any)
    return Service.grantPickup(state, defaults.secondary.upgradeCardXp, state.equippedAt)
end
return Service
