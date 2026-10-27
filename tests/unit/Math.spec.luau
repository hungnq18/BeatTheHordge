-- TestEZ-style sample; adapt require paths for your test runner.
return function()
    local Shared = game:GetService("ReplicatedStorage").Shared
    local scaling = require(Shared.Math.EnemyScaling)
    local mastery = require(Shared.Math.MasteryFormula)
    describe("Balance baseline", function()
        it("uses continuous time for enemy scaling", function()
            local actual = scaling.forSpawn(20, 5, 720, { hpGrowth = 0.15, hpExponent = 1.3, damageGrowth = 0.08 })
            expect(math.abs(actual.maxHP - 76.2667845) < 0.01).to.equal(true)
        end)
        it("evolves at 9800 Mastery XP", function()
            expect(mastery.evolutionThreshold(100, 99)).to.equal(9800)
            expect(mastery.levelFromXP(9799, 100, 99)).to.equal(98)
            expect(mastery.levelFromXP(9800, 100, 99)).to.equal(99)
        end)
    end)
end
