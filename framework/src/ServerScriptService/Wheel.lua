--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Config)
local Logic = require(ReplicatedStorage.WheelLogic).new(Config)
local Remotes = require(ReplicatedStorage.Remotes)
local Wheel = {}
local zero, one = Config.Math.Zero, Config.Math.One
local rng = Random.new()

export type State = { lastSpinAt: number, potions: { [string]: number }, owns67: boolean }
-- T3 profile contract: profile.wheel = State (absolute Unix expiries, never a
-- cached 67 value); profile.upgrades = {[Config upgrade Name]: integer level}.
-- Init can receive the actual loaded profile as its third argument. No DataStore
-- writes happen here. Saving must read this profile/getState before departure.
type Entry = { profile: any, characterConnection: RBXScriptConnection?, expiry: number? }
local entries: { [Player]: Entry } = {}
local started = false
local update: RemoteEvent

local function validPlayer(player: Player): boolean
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
end
local function copy(state: State): State
	local potions = {}
	for name, expiry in pairs(state.potions) do potions[name] = expiry end
	return { lastSpinAt = state.lastSpinAt, potions = potions, owns67 = state.owns67 }
end
local function baseStats(profile: any)
	local stats: any = { IncomeMult = one }
	for _, upgrade in ipairs(Config.Shop.Upgrades) do
		local level = (profile.upgrades or {})[upgrade.Name] or zero
		if type(level) ~= "number" or level ~= level then level = zero end
		level = math.clamp(math.floor(level), zero, Config.Shop.MaxUpgradeLevel)
		local value = upgrade.BaseValue + upgrade.Step * level
		if upgrade.MaxValue then value = math.min(value, upgrade.MaxValue) end
		if upgrade.Stat == "IncomeBonus" then stats.IncomeMult = one + value
		else stats[upgrade.Stat] = value end
	end
	return stats
end
local function schedule(entry: Entry)
	entry.expiry = nil
	for _, expiry in pairs(entry.profile.wheel.potions) do
		entry.expiry = math.min(entry.expiry or expiry, expiry)
	end
end
function Wheel.Refresh(player: Player)
	local entry = entries[player]
	if not entry then return end
	local now = os.time()
	local stats = Logic.effectiveStats(entry.profile.wheel, now, baseStats(entry.profile))
	-- Wall/Income consumers must use these refreshed attributes or getIncome,
	-- not add potions a second time. Upgrade purchases should call Refresh.
	for name, value in pairs(stats) do player:SetAttribute(name, value) end
	player:SetAttribute("OwnsBrainrot67", entry.profile.wheel.owns67)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = stats.WalkSpeed
		humanoid.UseJumpPower = true
		humanoid.JumpPower = stats.JumpPower
		humanoid.MaxHealth = stats.MaxHealth
		humanoid.Health = math.min(humanoid.Health, humanoid.MaxHealth)
	end
	schedule(entry)
end
local function publish(player: Player)
	local entry = entries[player]
	if entry and validPlayer(player) then update:FireClient(player, copy(entry.profile.wheel), os.time()) end
end
function Wheel.getState(player: Player): State?
	local entry = entries[player]
	if not entry then return nil end
	Wheel.Refresh(player)
	return copy(entry.profile.wheel)
end
function Wheel.getProfile(player: Player): any
	local entry = entries[player]
	return entry and entry.profile
end
function Wheel.setState(player: Player, state: State)
	assert(validPlayer(player) and entries[player], "Wheel player must be initialized")
	assert(Logic.validateState(state), "Invalid saved wheel state")
	entries[player].profile.wheel = copy(state)
	Wheel.Refresh(player)
	publish(player)
end
-- Called each base income tick with current ordinary pedestal values. 67 exists
-- only as owns67, never as a droppable inventory/Index/pedestal item.
function Wheel.getIncome(player: Player, pedestalValues: { number }, ordinaryIncome: number): number
	local entry = entries[player]
	assert(entry, "Wheel player must be initialized")
	local bonus = entry.profile.wheel.owns67 and Logic.brainrot67Value(pedestalValues) or zero
	local stats = Logic.effectiveStats(entry.profile.wheel, os.time(), baseStats(entry.profile))
	return (ordinaryIncome + bonus) * stats.IncomeMult
end
function Wheel.Remove(player: Player)
	local entry = entries[player]
	if entry and entry.characterConnection then entry.characterConnection:Disconnect() end
	entries[player] = nil
end
function Wheel.Start(managedLifecycle)
	if started then return end
	started = true
	Remotes.Setup()
	update = Remotes.Get("WheelUpdate") :: RemoteEvent
	local spin = Remotes.Get("SpinWheel") :: RemoteFunction
	local getState = Remotes.Get("GetWheelState") :: RemoteFunction
	getState.OnServerInvoke = function(player: Player, ...)
		if not validPlayer(player) or not entries[player] or select("#", ...) ~= zero then
			return { ok = false, reason = "not ready" }
		end
		return { ok = true, state = Wheel.getState(player), serverNow = os.time() }
	end
	spin.OnServerInvoke = function(player: Player, ...)
		if not validPlayer(player) or not entries[player] then return { ok = false, reason = "not ready" } end
		if select("#", ...) ~= zero then return { ok = false, reason = "unexpected arguments" } end
		local state = entries[player].profile.wheel
		local now = os.time()
		local allowed, remaining = Logic.canSpin(state, now)
		if not allowed then
			return { ok = false, reason = "cooldown", remainingSeconds = remaining,
				state = copy(state), serverNow = now }
		end
		-- No yields between checking and consuming cooldown; simultaneous invokes
		-- cannot spend the same spin. Duplicate 67 still consumes the daily spin.
		local reward = Logic.rollReward(rng:NextInteger(one, Config.Wheel.RewardWeightTotal))
		state.lastSpinAt = now
		local outcome = Logic.applyReward(state, reward, now)
		Wheel.Refresh(player)
		publish(player)
		return { ok = true, rewardName = reward, outcome = outcome, state = copy(state), serverNow = now }
	end
	-- One shared scheduler, independent of potion count; no per-potion threads.
	RunService.Heartbeat:Connect(function()
		local now = os.time()
		for player, entry in pairs(entries) do
			if entry.expiry and now >= entry.expiry then Wheel.Refresh(player); publish(player) end
		end
	end)
	if not managedLifecycle then Players.PlayerRemoving:Connect(Wheel.Remove) end
end
function Wheel.Init(player: Player, savedState: State?, profile: any?)
	assert(validPlayer(player), "Invalid wheel player")
	local state = savedState or (profile and profile.wheel)
		or { lastSpinAt = zero, potions = {}, owns67 = false }
	assert(Logic.validateState(state), "Invalid saved wheel state; do not replace a failed load with defaults")
	Wheel.Start()
	Wheel.Remove(player)
	local entry: Entry = { profile = profile or {}, characterConnection = nil, expiry = nil }
	entry.profile.wheel = copy(state)
	entries[player] = entry
	entry.characterConnection = player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		if entries[player] == entry and player.Character == character and humanoid:IsA("Humanoid") then
			Wheel.Refresh(player)
		end
	end)
	Wheel.Refresh(player)
	publish(player)
end
return Wheel
