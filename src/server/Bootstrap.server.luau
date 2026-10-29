--!strict
-- Server composition root. Do not process rewards, damage or purchases on client.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local names = require(ReplicatedStorage.Shared.Contracts.RemoteNames)
local ProfileService = require(script.Parent.Economy.ProfileService)
local LobbyService = require(script.Parent.Lobby.LobbyService)
local TomeSlotUnlockService = require(script.Parent.Lobby.TomeSlotUnlockService)
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
ProfileService.init()
LobbyService.init()
TomeSlotUnlockService.init()
MarketplaceService.ProcessReceipt = TomeSlotUnlockService.processReceipt

print("[BeatTheHorde] Server scaffold loaded; gameplay services are NOT wired yet (ProfileService, LobbyService, TomeSlotUnlockService active)")
