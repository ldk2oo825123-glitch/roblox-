-- Plain Lua server-contract mock, NOT an engine replication/playtest.
-- Remove only Luau type syntax; execute the actual Wheel module's behavior.
Color3 = { fromRGB = function(...) return {...} end }
local Config = dofile("src/ReplicatedStorage/Config.lua")
local Logic = dofile("src/ReplicatedStorage/WheelLogic.lua")
local checks = 0
local function equal(a, b) assert(a == b, tostring(a).." ~= "..tostring(b)); checks = checks + 1 end
local function signal()
	local event = { listeners = {} }
	function event:Connect(fn)
		local item = { fn = fn, connected = true }
		table.insert(self.listeners, item)
		return { Disconnect = function() item.connected = false end }
	end
	function event:Fire(...)
		for _, item in ipairs(self.listeners) do if item.connected then item.fn(...) end end
	end
	return event
end
local clock, nextRoll = 100000, 1
local originalTime, originalRequire = os.time, require
os.time = function() return clock end
math.clamp = function(n, lo, hi) return math.max(lo, math.min(n, hi)) end
typeof = function(value) return type(value) == "table" and value.kind or type(value) end
Random = { new = function() return { NextInteger = function(_, lo, hi)
	equal(lo, 1); equal(hi, nextRoll == 9467 and 9467 or (clock >= 272800 and 9400 or 9467)); assert(nextRoll <= hi); return nextRoll
end } end }
local remotes = {}
local updates = {}
local Remotes = { Setup = function() end, Get = function(name)
	if not remotes[name] then remotes[name] = {FireClient = function(_, player, state, now)
		table.insert(updates, {player = player, state = state, now = now})
	end} end
	return remotes[name]
end }
local Players = { PlayerRemoving = signal() }
local RunService = { Heartbeat = signal() }
local storage = { Config = Config, WheelLogic = Logic, Remotes = Remotes }
game = { GetService = function(_, name)
	return ({Players = Players, ReplicatedStorage = storage, RunService = RunService})[name]
end }
require = function(value) return value end
local sourceFile = assert(io.open("src/ServerScriptService/Wheel.lua"))
local source = sourceFile:read("*a"); sourceFile:close()
source = source:gsub("export type State = [^\n]*\n", ""):gsub("type Entry = [^\n]*\n", "")
source = source:gsub("local entries: { %[Player%]: Entry }", "local entries")
source = source:gsub("pedestalValues: { number }", "pedestalValues")
source = source:gsub(" :: RemoteEvent", ""):gsub(" :: RemoteFunction", "")
for _, annotation in ipairs({"RBXScriptConnection", "RemoteEvent", "Player", "State", "Entry", "boolean", "number", "any"}) do
	source = source:gsub(": " .. annotation .. "%?", ""):gsub(": " .. annotation .. "%f[^%w_]", "")
end
local Wheel = assert(load(source, "Wheel mock"))()
require = originalRequire
local player = {kind = "Instance", Parent = Players, CharacterAdded = signal(), attributes = {}}
function player:IsA(class) return class == "Player" end
function player:SetAttribute(name, value) self.attributes[name] = value end
Wheel.Start(); Wheel.Start()
equal(#RunService.Heartbeat.listeners, 1)
equal(remotes.SpinWheel.OnServerInvoke(player).reason, "not ready")
local profile = {upgrades = {Jump = 10, ["Ragdoll Resist"] = 10, ["Knockback Resist"] = 10}}
Wheel.Init(player, nil, profile)
equal(Wheel.getProfile(player), profile)
equal(profile.wheel.lastSpinAt, 0)
equal(remotes.SpinWheel.OnServerInvoke(player, "Brainrot67").reason, "unexpected arguments")
local response = remotes.SpinWheel.OnServerInvoke(player)
equal(response.ok, true); equal(response.rewardName, "SpeedBoost")
equal(profile.wheel.lastSpinAt, 100000); equal(profile.wheel.potions.SpeedBoost, 100900)
equal(player.attributes.WalkSpeed, 24)
response.state.potions.SpeedBoost = 0
equal(profile.wheel.potions.SpeedBoost, 100900)
response = remotes.SpinWheel.OnServerInvoke(player)
equal(response.ok, false); equal(response.remainingSeconds, 86400)
clock = 100899; RunService.Heartbeat:Fire(); equal(player.attributes.WalkSpeed, 24)
clock = 100900; RunService.Heartbeat:Fire(); equal(player.attributes.WalkSpeed, 16)
equal(profile.wheel.potions.SpeedBoost, nil)
clock = 186399; equal(remotes.SpinWheel.OnServerInvoke(player).remainingSeconds, 1)
clock = 186400; nextRoll = 9467
response = remotes.SpinWheel.OnServerInvoke(player)
equal(response.ok, true); equal(response.rewardName, "Brainrot67"); equal(profile.wheel.owns67, true)
equal(Wheel.getIncome(player, {1, 84}, 85), 169)
equal(Wheel.getIncome(player, {1}, 1), 2)
equal(Wheel.getIncome(player, {}, 0), 1)
clock = 272800; nextRoll = 9400
response = remotes.SpinWheel.OnServerInvoke(player)
equal(response.outcome, "granted"); equal(profile.wheel.lastSpinAt, 272800)
equal(remotes.SpinWheel.OnServerInvoke(player).remainingSeconds, 86400)
local state = Wheel.getState(player)
state.potions.JumpBoost = clock + 900
state.potions.RagdollResist = clock + 900
state.potions.KnockbackResist = clock + 900
state.potions.DoubleMoney = clock + 900
Wheel.setState(player, state)
equal(player.attributes.JumpPower, 125); equal(player.attributes.RagdollReduction, 0.9)
equal(player.attributes.KnockbackReduction, 0.9)
equal(Wheel.getIncome(player, {84}, 84), 336)
state.potions.DoubleMoney = 0
equal(profile.wheel.potions.DoubleMoney, clock + 900)
local snapshot = remotes.GetWheelState.OnServerInvoke(player)
equal(snapshot.ok, true); equal(snapshot.serverNow, clock)
equal(remotes.GetWheelState.OnServerInvoke(player, true).ok, false)
clock = clock + 900
equal(Wheel.getIncome(player, {84}, 84), 168) -- correct even before scheduler fires
RunService.Heartbeat:Fire()
equal(player.attributes.JumpPower, 100); equal(player.attributes.RagdollReduction, 0.8)
equal(player.attributes.KnockbackReduction, 0.8)
local saved = Wheel.getState(player)
Wheel.Init(player, saved, profile)
equal(#RunService.Heartbeat.listeners, 1)
equal(player.CharacterAdded.listeners[1].connected, false)
equal(profile.wheel.owns67, true)
equal(profile.wheel.value, nil)
Players.PlayerRemoving:Fire(player)
equal(Wheel.getState(player), nil)
equal(player.CharacterAdded.listeners[2].connected, false)
equal(remotes.SpinWheel.OnServerInvoke(player).ok, false)
os.time = originalTime
print("PASS: " .. checks .. " wheel server mock checks (not Roblox replication)")
