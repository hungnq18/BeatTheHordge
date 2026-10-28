--!strict
-- Studio-only test runner. Does not run in a published/live server.
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
    return
end

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestEZ = require(ReplicatedStorage.Shared.Vendor.TestEZ)
local testRunnerRoot = ServerScriptService:WaitForChild("TestRunner")

local results = TestEZ.TestBootstrap:run({ testRunnerRoot }, TestEZ.Reporters.TextReporter)

if results.failureCount > 0 then
    warn(string.format("[TestEZ] %d test(s) failed", results.failureCount))
else
    print("[TestEZ] All tests passed")
end
