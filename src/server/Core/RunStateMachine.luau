--!strict
local FSM = {}
FSM.__index = FSM
local transitions = {
    Lobby = { RunInit = true }, RunInit = { Phase1Survival = true, Failed = true },
    Phase1Survival = { Phase1Boss = true, Failed = true },
    Phase1Boss = { Phase1Reward = true, Failed = true },
    Phase1Reward = { Phase2Survival = true, Results = true },
    Phase2Survival = { Phase2Boss = true, Failed = true },
    Phase2Boss = { Phase2Reward = true, Failed = true },
    Phase2Reward = { MapBoss = true, Results = true },
    MapBoss = { Victory = true, Failed = true },
    Victory = { Results = true }, Failed = { Results = true },
    Results = { Lobby = true },
}
function FSM.new()
    return setmetatable({ state = "Lobby" }, FSM)
end
function FSM:transition(nextState: string)
    if not (transitions[self.state] and transitions[self.state][nextState]) then
        error(`Invalid Run transition {self.state} -> {nextState}`)
    end
    self.state = nextState
end
return FSM
