-- Run from project root: lua tests/test_balance.lua
-- Config alone needs Color3; Balance itself uses only the Lua standard library.
Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end }
local Config = dofile("src/ReplicatedStorage/Config.lua")
local Balance = dofile("src/ReplicatedStorage/Balance.lua").new(Config)
local checks = 0

local function equal(actual, expected)
	assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
	checks = checks + 1
end

local function near(actual, expected)
	assert(math.abs(actual - expected) < 1e-9, tostring(actual) .. " ~= " .. tostring(expected))
	checks = checks + 1
end

local function rejects(fn)
	equal(pcall(fn), false)
end

local weight = 0
for _, tier in ipairs(Config.Wall.Tiers) do
	equal(tier.Weight % 1, 0)
	weight = weight + tier.Weight
end
equal(weight, 100)
equal(Balance.wallDamage(14), 60)
equal(Balance.wallDamage(120), 400)
equal(Balance.wallDamage(67), 230)
for speed = 14, 120 do
	near(Balance.wallDamage(speed), 60 + (speed - 14) / 106 * 340)
	near(Balance.wallRagdollSeconds(speed), 2 + (speed - 14) / 106 * 7)
end
equal(Balance.wallRagdollSeconds(14), 2)
equal(Balance.wallRagdollSeconds(120), 9)
equal(Balance.wallDamage(-1), 60)
equal(Balance.wallDamage(121), 400)
local h, v = Balance.wallFling(14)
equal(h, 60)
equal(v, 30)
h, v = Balance.wallFling(120)
equal(h, 350)
equal(v, 120)
h, v = Balance.wallFling(67)
equal(h, 205)
equal(v, 75)
equal(Balance.upgradePrice("Speed", 0), 25)
equal(Balance.upgradePrice("Speed", 1), 40)
equal(Balance.upgradePrice("Jump", 0), 30)
equal(Balance.upgradePrice("Health", 0), 30)
equal(Balance.upgradePrice("Cash", 0), 40)
equal(Balance.upgradePrice("Knockback Resist", 0), 50)
equal(Balance.upgradePrice("Ragdoll Resist", 0), 50)
equal(Balance.formatPrice(1500), "1.5K")
equal(Balance.formatPrice(2500000), "2.5M")
equal(Balance.formatPrice(2500000000), "2.5B")
equal(Balance.formatPrice(25), "25")
equal(Balance.formatPrice(0), "0")
local jump = Config.Shop.Upgrades[2]
equal(jump.BaseValue + jump.Step * Config.Shop.MaxUpgradeLevel, 65)
equal(Config.Jump.MaxEffectiveJumpPower, 70)
local health = Config.Shop.Upgrades[3]
equal(health.BaseValue + health.Step * Config.Shop.MaxUpgradeLevel, 350)
local odds = 0
for _, variant in ipairs(Config.Brainrots.Variants) do
	odds = odds + variant.Odds
end
near(odds, 1)
equal(Config.Brainrots.Variants[5].ColourCycling, true)
equal(Config.Bases.IncomeDisplayDecimals, 1)
equal(Config.Wall.WarningSecondsByTier.LIGHTSPEED, 8)
equal(Config.Wall.WarningSecondsByTier.INSANE, 7)
equal(Config.Wall.WarningSeconds, 5)
local counts = {}
for roll = 1, 100 do
	local tier = Balance.pickWallTier(roll)
	counts[tier.Name] = (counts[tier.Name] or 0) + 1
end
for _, tier in ipairs(Config.Wall.Tiers) do
	equal(counts[tier.Name], tier.Weight)
end
rejects(function() Balance.pickWallTier(0) end)
rejects(function() Balance.pickWallTier(101) end)
rejects(function() Balance.pickWallTier(1.5) end)
rejects(function() Balance.upgradePrice("Missing", 0) end)
rejects(function() Balance.upgradePrice("Speed", -1) end)
rejects(function() Balance.upgradePrice("Speed", 0.5) end)
rejects(function() Balance.wallDamage(0 / 0) end)
rejects(function() Balance.formatPrice(math.huge) end)
print("PASS: " .. checks .. " balance checks")
