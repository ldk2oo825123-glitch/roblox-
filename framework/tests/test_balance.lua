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
	near(Balance.wallDamage(speed), math.floor(60 + (speed - 14) / 106 * 340))
	near(Balance.wallRagdollSeconds(speed), 2 + (speed - 14) / 106 * 7)
end
equal(Balance.wallRagdollSeconds(14), 2)
equal(Balance.wallRagdollSeconds(120), 9)
equal(Balance.wallDamage(-1), 60)
equal(Balance.wallDamage(121), 400)
local h, v = Balance.wallFling(14)
equal(h, 60)
equal(v, 50)
h, v = Balance.wallFling(120)
equal(h, 360)
equal(v, 200)
h, v = Balance.wallFling(67)
equal(h, 210)
equal(v, 125)
equal(Balance.upgradePrice("Speed", 0), 25)
equal(Balance.upgradePrice("Speed", 1), 40)
equal(Balance.upgradePrice("Jump", 0), 30)
equal(Balance.upgradePrice("Health", 0), 30)
equal(Balance.upgradePrice("Cash", 0), 40)
equal(Balance.upgradePrice("Knockback Resist", 0), 60)
equal(Balance.upgradePrice("Ragdoll Resist", 0), 60)
equal(Balance.formatPrice(1500), "1.5K")
equal(Balance.formatPrice(2500000), "2.5M")
equal(Balance.formatPrice(2500000000), "2.5B")
equal(Balance.formatPrice(25), "25")
equal(Balance.formatPrice(0), "0")
local jump = Config.Shop.Upgrades[2]
equal(jump.BaseValue + jump.Step * Config.Shop.MaxUpgradeLevel, 100)
equal(Config.Jump.SuggestedCapEnabled, false)
local health = Config.Shop.Upgrades[3]
equal(health.BaseValue + health.Step * Config.Shop.MaxUpgradeLevel, 350)
local odds = 0
for _, variant in ipairs(Config.Brainrots.Variants) do
	odds = odds + variant.Odds
end
near(odds, 1)
equal(Config.Brainrots.Variants[5].ColourCycling, true)
equal(Config.Bases.IncomeDisplayDecimals, 0)
equal(Config.Wall.Tiers[6].Weight, 9)
equal(Config.Wall.Tiers[5].Weight, 12)
equal(Config.Wall.WarningSeconds, 5)
for level = 0, 10 do
 near(Balance.resistMultiplier(level, false), math.max(0.1, 1-0.08*level))
 near(Balance.resistMultiplier(level, true), math.max(0.1, 1-0.08*(level+5)))
end
for _, tier in ipairs(Config.Wall.Tiers) do
 equal(Balance.wallSpeed(tier, 0), tier.MinSpeed)
 equal(Balance.wallSpeed(tier, 1), tier.MaxSpeed)
end
equal(Balance.upgradePrice("Jump", 1), 51)
equal(Balance.upgradePrice("Health", 1), 51)
equal(Balance.upgradePrice("Cash", 1), 72)
equal(Balance.upgradePrice("Knockback Resist", 1), 108)
equal(Balance.upgradePrice("Ragdoll Resist", 1), 108)
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
-- Independent real-script fixtures check translated rows and exact counts/colours.
local expectedWeights = {22,22,20,15,12,9}
local expectedCounts = {10,8,6,4,2}
local expectedVariants = {80,10,5,3,1.5}
for i, value in ipairs(expectedWeights) do equal(Config.Wall.Tiers[i].Weight, value) end
for i, value in ipairs(expectedCounts) do equal(Config.Brainrots.SpawnsPerTier[i], value) end
for i, value in ipairs(expectedVariants) do equal(Config.Brainrots.Variants[i].Weight, value); near(Config.Brainrots.Variants[i].Odds, value/99.5) end
local realShop = dofile("../game-scripts/ReplicatedStorage/ShopConfig.lua")
for i, real in ipairs(realShop.Items) do
 local copy = Config.Shop.Items[i]
 for field, value in pairs(real) do equal(copy[field], value) end
 local row = Config.Shop.Upgrades[i]
 equal(row.BasePrice, real.baseCost); equal(row.Growth, real.growth); equal(row.MaxLevel, real.maxLevel)
 for level = 0, 10 do equal(Balance.upgradePrice(row.Name, level), realShop.cost(real, level)) end
end
equal(Config.Brainrots.VariantColours.gold.G,215)
equal(Config.Brainrots.VariantColours.diamond.R,150)
equal(Config.Brainrots.Variants[2].BaseColour.G,200)
equal(Config.Brainrots.Variants[3].Material,"Ice")
equal(Config.Brainrots.Tiers[4].Material,"Neon")
equal(Config.Wall.WaitSeconds,20);equal(Config.Wall.HitDebounceSeconds,2.5)
equal(Config.Bases.PedestalCount,6);equal(Config.Bases.IncomeIntervalSeconds,5)
equal(Config.Brainrots.RespawnSeconds,8)

local realWheel = dofile("../game-scripts/ReplicatedStorage/WheelConfig.lua")
equal(Config.Wheel.PotionDurationSeconds, realWheel.DURATION)
equal(Config.Wheel.CooldownSeconds, realWheel.COOLDOWN)
for n, reward in ipairs(realWheel.Rewards) do
 for field, value in pairs(reward) do
  if field == "color" then
   equal(Config.Wheel.Rewards[n].color.R,value.R);equal(Config.Wheel.Rewards[n].color.G,value.G);equal(Config.Wheel.Rewards[n].color.B,value.B)
  else equal(Config.Wheel.Rewards[n][field],value) end
 end
 equal(Config.Wheel.RewardWeights[Config.Wheel.RewardOrder[n]],reward.weight*100)
end

print("PASS: " .. checks .. " balance checks")
