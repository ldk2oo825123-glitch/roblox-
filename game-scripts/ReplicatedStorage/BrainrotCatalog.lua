local Catalog = {}

-- Must match the tiers / variants used when brainrots spawn
Catalog.Tiers = {
	{name = "Noodle Goblin",  value = 1,  color = Color3.fromRGB(200, 200, 200)},
	{name = "Sigma Frog",     value = 3,  color = Color3.fromRGB(80, 200, 100)},
	{name = "Turbo Toast",    value = 8,  color = Color3.fromRGB(70, 140, 255)},
	{name = "Cosmic Banana",  value = 20, color = Color3.fromRGB(180, 80, 255)},
	{name = "Golden Gigarot", value = 60, color = Color3.fromRGB(255, 205, 40)},
}

Catalog.Variants = {
	{name = "Normal",  prefix = "",         bonus = 0,    textColor = Color3.new(1, 1, 1)},
	{name = "Gold",    prefix = "Gold ",    bonus = 0.10, color = Color3.fromRGB(255, 200, 40),  textColor = Color3.fromRGB(255, 215, 60)},
	{name = "Diamond", prefix = "Diamond ", bonus = 0.20, color = Color3.fromRGB(150, 235, 255), textColor = Color3.fromRGB(150, 235, 255)},
	{name = "Emerald", prefix = "Emerald ", bonus = 0.30, color = Color3.fromRGB(30, 200, 90),   textColor = Color3.fromRGB(80, 255, 140)},
	{name = "Rainbow", prefix = "Rainbow ", bonus = 0.40, color = Color3.fromRGB(255, 60, 200),  textColor = Color3.fromRGB(255, 120, 230), rainbow = true},
}

function Catalog.fullName(tier, variant)
	return variant.prefix .. tier.name
end

function Catalog.value(tier, variant)
	return math.floor(tier.value * (1 + variant.bonus) * 10 + 0.5) / 10
end

return Catalog
