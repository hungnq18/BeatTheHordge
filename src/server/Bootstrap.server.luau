--!strict
-- Server composition root. Do not process rewards, damage or purchases on client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local names = require(ReplicatedStorage.Shared.Contracts.RemoteNames)
local folder = ReplicatedStorage:FindFirstChild("GameRemotes")
if not folder then
    folder = Instance.new("Folder")
    folder.Name = "GameRemotes"
    folder.Parent = ReplicatedStorage
end
for _, name in pairs(names) do
    if not folder:FindFirstChild(name) then
        local remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = folder
    end
end
print("[BeatTheHorde] Server scaffold loaded; gameplay services are NOT wired yet")
