local WheelConfig = {}

WheelConfig.DURATION = 15 * 60        -- every potion lasts 15 minutes
WheelConfig.COOLDOWN = 24 * 60 * 60   -- one spin per day

WheelConfig.Rewards = {
	{id = "Speed",     name = "Speed Boost",      icon = "⚡", color = Color3.fromRGB(255, 205, 60),  weight = 18, attr = "BoostSpeed",     desc = "+8 walk speed for 15 minutes"},
	{id = "Money",     name = "Double Money",     icon = "💵", color = Color3.fromRGB(70, 200, 90),   weight = 18, attr = "BoostMoney",     desc = "2x income for 15 minutes"},
	{id = "Health",    name = "Health Boost",     icon = "❤️", color = Color3.fromRGB(235, 70, 80),   weight = 16, attr = "BoostHealth",    desc = "+50 max health for 15 minutes"},
	{id = "Ragdoll",   name = "Ragdoll Resist",   icon = "⏱️", color = Color3.fromRGB(150, 110, 235), weight = 14, attr = "BoostRagdoll",   desc = "-40% ragdoll time for 15 minutes"},
	{id = "Jump",      name = "Jump Boost",       icon = "🦘", color = Color3.fromRGB(255, 150, 50),  weight = 14, attr = "BoostJump",      desc = "+25 jump power for 15 minutes"},
	{id = "Knockback", name = "Knockback Resist", icon = "🧱", color = Color3.fromRGB(90, 160, 220),  weight = 14, attr = "BoostKnockback", desc = "-40% knockback for 15 minutes"},
	{id = "Rare67",    name = "67 Brainrot",      icon = "67", color = Color3.fromRGB(255, 60, 200),  weight = 0.67, special = true,           desc = "PERMANENT! Earns as much as your best brainrot"},
}

return WheelConfig
