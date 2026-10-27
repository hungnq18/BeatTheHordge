--!strict
-- Server-only ConfigService for published balance. NOT a complete production validator.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local defaults = require(ReplicatedStorage.Shared.Config.BalanceDefaults)
local ConfigService = {}
local latest = nil
local endpoint = "https://YOUR-STAGING-API.example.com/api/v1/game-config/solo?channel=development"
local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k,v in pairs(value) do out[k] = deepCopy(v) end
    return out
end
function ConfigService.fetchPublished()
    local ok, response = pcall(function()
        return HttpService:RequestAsync({Url=endpoint,Method="GET",Headers={Accept="application/json"}})
    end)
    if not ok or not response.Success then return false, "NETWORK_OR_HTTP_ERROR" end
    local decoded, body = pcall(function() return HttpService:JSONDecode(response.Body) end)
    if not decoded or type(body) ~= "table" or body.schemaVersion ~= 1 or type(body.payload) ~= "table" then
        return false, "INVALID_CONFIG"
    end
    if type(body.payload.secondary) ~= "table" or body.payload.secondary.maxLevel ~= 99 then
        return false, "RULE_MISMATCH"
    end
    -- TODO: Full schema validation of all game config branches, channel, version and integrity.
    latest = body
    return true, body.configVersion
end
function ConfigService.getRunConfig()
    -- Deep copy freezes the run's inputs against later config refreshes.
    return deepCopy(latest and latest.payload or defaults)
end
return ConfigService
