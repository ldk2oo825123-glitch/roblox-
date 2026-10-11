local ShopConfig = {}

ShopConfig.Items = {
	{id = "Speed",     title = "+2 Speed",             icon = "👟", baseCost = 25, growth = 1.6, maxLevel = 10, attr = "SpeedLevel",     base = 16,  step = 2,  suffix = ""},
	{id = "Jump",      title = "+5 Jump",              icon = "🦘", baseCost = 30, growth = 1.7, maxLevel = 10, attr = "JumpLevel",      base = 50,  step = 5,  suffix = ""},
	{id = "Health",    title = "+25 Health",           icon = "❤️", baseCost = 30, growth = 1.7, maxLevel = 10, attr = "HealthLevel",    base = 100, step = 25, suffix = ""},
	{id = "Cash",      title = "+25% Cash",            icon = "💰", baseCost = 40, growth = 1.8, maxLevel = 10, attr = "CashLevel",      base = 100, step = 25, suffix = "%"},
	{id = "Knockback", title = "+8% Knockback Resist", icon = "🛡️", baseCost = 60, growth = 1.8, maxLevel = 10, attr = "KnockbackLevel", base = 0,   step = 8,  suffix = "%"},
	{id = "Ragdoll",   title = "+8% Ragdoll Resist",   icon = "⏱️", baseCost = 60, growth = 1.8, maxLevel = 10, attr = "RagdollLevel",   base = 0,   step = 8,  suffix = "%"},
}

function ShopConfig.cost(item, level)
	return math.floor(item.baseCost * item.growth ^ level)
end

function ShopConfig.value(item, level)
	return item.base + item.step * level
end

return ShopConfig
