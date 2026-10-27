--!strict
local Clock = {}
Clock.__index = Clock
function Clock.new(secondsPerPhase: number, phases: number)
    return setmetatable({ elapsed = 0, active = false, maxSeconds = secondsPerPhase * phases }, Clock)
end
function Clock:setActive(value: boolean)
    self.active = value
end
function Clock:advance(delta: number): number
    assert(delta >= 0)
    if self.active then self.elapsed = math.min(self.maxSeconds, self.elapsed + delta) end
    return self.elapsed
end
return Clock
