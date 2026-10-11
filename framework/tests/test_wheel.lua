-- Run from project root: lua tests/test_wheel.lua
Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end }
local Config = dofile("src/ReplicatedStorage/Config.lua")
local Wheel = dofile("src/ReplicatedStorage/WheelLogic.lua").new(Config)
local checks = 0
local function equal(actual, expected)
	assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
	checks = checks + 1
end
local function rejects(fn) equal(pcall(fn), false) end
local function fresh() return { lastSpinAt = 0, potions = {}, owns67 = false } end
local function clone(state)
	local copy = fresh()
	copy.lastSpinAt, copy.owns67 = state.lastSpinAt, state.owns67
	for name, expiry in pairs(state.potions) do copy.potions[name] = expiry end
	return copy
end
local state = fresh()
equal(Wheel.validateState(state), true)
equal(Wheel.canSpin(state, 100000), true)
equal(Wheel.nextSpinAt(state), 0)
state.lastSpinAt = 100000
local allowed, remaining = Wheel.canSpin(state, 186399)
equal(allowed, false); equal(remaining, 1)
allowed, remaining = Wheel.canSpin(state, 186400)
equal(allowed, true); equal(remaining, 0)
equal(Wheel.nextSpinAt(state), 186400)
local boundaries = { {1, "SpeedBoost"}, {1800, "SpeedBoost"}, {1801, "DoubleMoney"},
	{9400, "KnockbackResist"}, {9401, "Brainrot67"}, {9467, "Brainrot67"} }
for _, entry in ipairs(boundaries) do equal(Wheel.rollReward(entry[1]), entry[2]) end
local weights, total = {}, 0
for _, name in ipairs(Config.Wheel.RewardOrder) do
	equal(Config.Wheel.RewardWeights[name] % 1, 0)
	total = total + Config.Wheel.RewardWeights[name]
end
equal(total, 9467)
equal(Wheel.rewardWeightTotal(true), 9400)
local ownedWeights = {}
for roll = 1, 9400 do
 local name = Wheel.rollReward(roll, true)
 assert(name ~= "Brainrot67")
 ownedWeights[name] = (ownedWeights[name] or 0) + 1
end
for name, weight in pairs(Config.Wheel.RewardWeights) do if name ~= "Brainrot67" then equal(ownedWeights[name], weight) end end
rejects(function() Wheel.rollReward(9401, true) end)
for roll = 1, 9467 do
	local name = Wheel.rollReward(roll)
	weights[name] = (weights[name] or 0) + 1
end
for name, weight in pairs(Config.Wheel.RewardWeights) do equal(weights[name], weight) end
local default = { walkSpeedBonus = 0, incomeMult = 1, maxHealthBonus = 0,
	ragdollLevels = 0, knockbackLevels = 0, jumpBonus = 0 }
local expected = { SpeedBoost = {walkSpeedBonus = 8}, DoubleMoney = {incomeMult = 2},
	HealthBoost = {maxHealthBonus = 50}, RagdollResist = {ragdollLevels = 5},
	JumpBoost = {jumpBonus = 25}, KnockbackResist = {knockbackLevels = 5} }
for name, effects in pairs(expected) do
	state = fresh()
	equal(Wheel.applyReward(state, name, 100000), "granted")
	equal(state.potions[name], 100900)
	local before = Wheel.potionModifiers(clone(state), 100899)
	for key, value in pairs(default) do equal(before[key], effects[key] or value) end
	local after = Wheel.potionModifiers(state, 100900)
	for key, value in pairs(default) do equal(after[key], value) end
	equal(state.potions[name], nil)
	Wheel.applyReward(state, name, 101000)
	Wheel.applyReward(state, name, 101100)
	equal(state.potions[name], 102800)
	for _ = 1, 10 do Wheel.applyReward(state, name, 101100) end
	equal(state.potions[name], 111800)
	-- Each grant extends the absolute expiry by 900, with no cap.
	Wheel.applyReward(state, name, 101200)
	equal(state.potions[name], 112700)
	Wheel.applyReward(state, name, 112700)
	equal(state.potions[name], 113600)
end
state = fresh()
for name in pairs(expected) do Wheel.applyReward(state, name, 100000) end
local base = {WalkSpeed = 36, JumpPower = 100, MaxHealth = 350, IncomeMult = 3.5,
	RagdollLevel = 10, KnockbackLevel = 10}
local effective = Wheel.effectiveStats(clone(state), 100899, base)
equal(effective.WalkSpeed, 44); equal(effective.JumpPower, 125); equal(effective.MaxHealth, 400)
equal(effective.IncomeMult, 7); equal(effective.RagdollReduction, 0.9); equal(effective.KnockbackReduction, 0.9)
effective = Wheel.effectiveStats(state, 100900, base)
equal(effective.WalkSpeed, 36); equal(effective.JumpPower, 100); equal(effective.MaxHealth, 350)
equal(effective.IncomeMult, 3.5); equal(effective.RagdollReduction, 0.8); equal(effective.KnockbackReduction, 0.8)
equal(next(state.potions), nil)
local pedestals = {1, 3, 84}
equal(Wheel.brainrot67Value(pedestals), 84)
pedestals[3] = nil
equal(Wheel.brainrot67Value(pedestals), 3)
pedestals[6] = 100
equal(Wheel.brainrot67Value(pedestals), 100)
equal(Wheel.brainrot67Value({}), 1)
state = fresh()
equal(Wheel.applyReward(state, "Brainrot67", 100000), "granted")
equal(state.owns67, true)
state.lastSpinAt = 200000 -- server consumes the spin before applying the reward
local before = clone(state)
equal(Wheel.applyReward(state, "Brainrot67", 200000), "already owned")
equal(state.lastSpinAt, before.lastSpinAt); equal(state.owns67, before.owns67)
equal(next(state.potions), nil)
equal(Wheel.canSpin(state, 200001), false)
equal(state.value, nil)
for _, key in ipairs({"Droppable", "Tradeable", "HasVariants", "LostOnDeath", "CountsInIndex"}) do
	equal(Config.Wheel.PermanentReward[key], false)
end
-- Saved absolute expiries consume offline time; snapshots survive rejoin unchanged.
state = fresh(); Wheel.applyReward(state, "SpeedBoost", 100000)
local restored = clone(state)
equal(Wheel.potionModifiers(restored, 100500).walkSpeedBonus, 8)
equal(restored.potions.SpeedBoost, 100900)
equal(Wheel.potionModifiers(restored, 100900).walkSpeedBonus, 0)
rejects(function() Wheel.rollReward(0) end)
rejects(function() Wheel.rollReward(10001) end)
rejects(function() Wheel.rollReward(1.5) end)
rejects(function() Wheel.rollReward(0/0) end)
rejects(function() Wheel.applyReward(fresh(), "Fake", 100000) end)
rejects(function() Wheel.canSpin(fresh(), math.huge) end)
rejects(function() Wheel.brainrot67Value({-1}) end)
equal(Wheel.validateState({ lastSpinAt = -1, potions = {}, owns67 = false }), false)
equal(Wheel.validateState({ lastSpinAt = 0, potions = {Fake = 123}, owns67 = false }), false)
equal(Wheel.validateState({ lastSpinAt = 0, potions = {SpeedBoost = math.huge}, owns67 = false }), false)
equal(Wheel.validateState({ lastSpinAt = 0, potions = {}, owns67 = "true" }), false)
print("PASS: " .. checks .. " wheel checks (all 9467 rolls enumerated)")
