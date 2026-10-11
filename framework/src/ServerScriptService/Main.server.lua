--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Config = require(RS.Config)
local Wheel = require(script.Parent.Wheel)
local Inventory = require(script.Parent.Inventory)
local Bases = require(script.Parent.Bases)
local Brainrots = require(script.Parent.Brainrots)
local Profile = require(script.Parent.Profile).new(Config, require(RS.WheelLogic).new(Config))
local Logic = require(RS.ProfileLogic).new(Config, require(RS.BrainrotData), function() return HttpService:GenerateGUID(false) end)
-- Start remote handlers/geometry first, with Saving owning departure cleanup.
-- On successful load: Profile -> Wheel -> Inventory -> Bases. On departure:
-- snapshot + save/release -> Bases -> Inventory -> Wheel -> Profile cleanup.
Wheel.Start(true); Inventory.Start(true); Bases.Start(Inventory)
Bases.SetCashHandler(Profile.addCash)
local Saving = require(script.Parent.Saving).new(Config, Logic, {
	store = DataStoreService:GetDataStore(Config.Saving.StoreName),
	legacyStore = DataStoreService:GetDataStore(Config.Saving.LegacyStoreName),
	Profile = Profile, Wheel = Wheel, Inventory = Inventory, Bases = Bases,
	jobId = game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false), isStudio = RunService:IsStudio(),
	now = os.time, clock = os.clock, wait = task.wait, spawn = task.spawn, warn = warn,
	isActive = function(player) return player.Parent == Players end,
})
Players.PlayerAdded:Connect(function(player) Saving.load(player) end)
Players.PlayerRemoving:Connect(function(player) Saving.remove(player) end)
game:BindToClose(function() Saving.close() end)
RunService.Heartbeat:Connect(function() Saving.tick() end)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(function() Saving.load(player) end) end
-- Geometry adapter: call Brainrots.SetPitRects(worldSpaceRects) before Start.
Brainrots.Start(Inventory)
