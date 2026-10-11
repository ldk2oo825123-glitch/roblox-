--!strict

-- Tested mirror of game-scripts; never install both script sets together.
local Config = {
	Math = {
		Zero = 0,
		One = 1,
		ValueDecimalPlaces = 1,
		ValueRoundingScale = 10,
	},
	Map = {
		DangerLength = 800,
		WallHeight = 46,
		RarityBoundaryCount = 4,
		BrainrotTierCount = 5,
		-- TODO(T4-geometry): Studio/world adapter geometry MUST match these placeholder
		-- bounds: safe zone z=-100..0, danger corridor z=0..800, floor y=0.
		SafeZone = { MinX = -160, MaxX = 160, MinY = -10, MaxY = 60, MinZ = -100, MaxZ = 0 },
		DangerHalfWidth = 50,
		-- Distances from the safe-zone edge: five equal 160-stud bands, band i = tier i.
		RarityBoundaries = { 160, 320, 480, 640 },
	},
	-- Source: game-scripts/ServerScriptService/BaseServer.server.lua (MAX_SLOTS/PAY_INTERVAL).
	Bases = {
		PlotCount = 5,
		MaxPlayers = 5,
		PedestalCount = 6,
		IncomeIntervalSeconds = 5,
		-- Real base payouts floor the final multiplied sum.
		IncomeDisplayDecimals = 0,
		-- TODO(T4-geometry): five placeholder plots across the safe-zone back wall.
		PlotSpacing = 60, PlotZ = -75, PlotY = 0, PlotSize = { 50, 1, 35 },
		PedestalSize = { 4, 2, 4 }, PedestalSpacing = 7, PedestalZ = 5,
		SpawnHeight = 4, InteractionRange = 12,
		SignSize = { 300, 70 }, SignHeight = 9,
		PlotColour = Color3.fromRGB(150, 200, 255),
		PedestalColour = Color3.fromRGB(235, 235, 255),
	},
	Pits = {
		Count = 14,
		Width = 24,
		Length = 28,
		Depth = 14,
		MinimumSpacing = 30,
		RampSide = "West",
		MarkerColour = "yellow",
	},
	-- Source: game-scripts/ServerScriptService/BrainrotServer.server.lua and ReplicatedStorage/BrainrotCatalog.lua.
	Brainrots = {
		RespawnSeconds = 8,
		SpawnsPerTier = { 10, 8, 6, 4, 2 }, SpawnMargin = 4, SpawnAttempts = 100,
		SpawnY = 3, SafeZonePollSeconds = 0.2,
		Tiers = {
			{ Name = "Noodle Goblin", BaseValue = 1, Colour = Color3.fromRGB(200, 200, 200), Material = "SmoothPlastic" },
			{ Name = "Sigma Frog", BaseValue = 3, Colour = Color3.fromRGB(80, 200, 100), Material = "SmoothPlastic" },
			{ Name = "Turbo Toast", BaseValue = 8, Colour = Color3.fromRGB(70, 140, 255), Material = "SmoothPlastic" },
			{ Name = "Cosmic Banana", BaseValue = 20, Colour = Color3.fromRGB(180, 80, 255), Material = "Neon" },
			{ Name = "Golden Gigarot", BaseValue = 60, Colour = Color3.fromRGB(255, 205, 40), Material = "Neon" },
		},
		-- Source: game-scripts/ServerScriptService/BrainrotServer.server.lua (total weight 99.5).
		VariantWeightTotal = 99.5,
		Variants = {
			{ Name = "Normal", Bonus = 0, Weight = 80, Odds = 80 / 99.5, Colour = "normal", ColourCycling = false },
			{ Name = "Gold", Bonus = 0.10, Weight = 10, Odds = 10 / 99.5, Colour = "gold", ColourCycling = false, BaseColour = Color3.fromRGB(255, 200, 40), Material = "Metal" },
			{ Name = "Diamond", Bonus = 0.20, Weight = 5, Odds = 5 / 99.5, Colour = "diamond", ColourCycling = false, BaseColour = Color3.fromRGB(150, 235, 255), Material = "Ice" },
			{ Name = "Emerald", Bonus = 0.30, Weight = 3, Odds = 3 / 99.5, Colour = "emerald", ColourCycling = false, BaseColour = Color3.fromRGB(30, 200, 90), Material = "Glass" },
			{ Name = "Rainbow", Bonus = 0.40, Weight = 1.5, Odds = 1.5 / 99.5, Colour = "rainbow", ColourCycling = true, BaseColour = Color3.fromRGB(255, 60, 200), Material = "Neon" },
		},
		-- Variant.Colour is the lookup key for these exact label colours.
		-- Rainbow labels AND inventory dots cycle hue by time on the client when
		-- ColourCycling=true; the configured RGB is the initial colour.
		VariantColours = {
			normal = Color3.fromRGB(255, 255, 255),
			gold = Color3.fromRGB(255, 215, 60),
			diamond = Color3.fromRGB(150, 235, 255),
			emerald = Color3.fromRGB(80, 255, 140),
			rainbow = Color3.fromRGB(255, 120, 230),
		},
	},
	-- Source: game-scripts/ServerScriptService/WallServer.server.lua.
	Wall = {
		WaitSeconds = 20,
		WarningSeconds = 5,
		GroundClearance = 2,
		HitDebounceSeconds = 2.5,
		Speed = { Min = 14, Max = 120 },
		-- Health caps at 100 + 25*10 = 350. Damage scales linearly 60..400:
		-- damage reaches full upgraded health at approximately speed 104.41,
		-- in upper LIGHTSPEED; this lethality at the top end is intended.
		Damage = { Min = 60, Max = 400 },
		RagdollSeconds = { Min = 2, Max = 9 },
		-- Launch toward the safe zone and upward, linearly across speed 14..120.
		Fling = { Horizontal = { Min = 60, Max = 360 }, Vertical = { Min = 50, Max = 200 } },
		-- Integer weights replace qualitative odds and sum to 100.
		Tiers = {
			{ Name = "SLOW", MinSpeed = 14, MaxSpeed = 22, Colour = Color3.fromRGB(60, 220, 60), Weight = 22 },
			{ Name = "MEDIUM", MinSpeed = 22, MaxSpeed = 32, Colour = Color3.fromRGB(255, 225, 40), Weight = 22 },
			{ Name = "FAST", MinSpeed = 32, MaxSpeed = 45, Colour = Color3.fromRGB(255, 140, 30), Weight = 20 },
			{ Name = "EXTREME", MinSpeed = 45, MaxSpeed = 60, Colour = Color3.fromRGB(230, 30, 30), Weight = 15 },
			{ Name = "INSANE", MinSpeed = 60, MaxSpeed = 85, Colour = Color3.fromRGB(140, 0, 0), Weight = 12 },
			{ Name = "LIGHTSPEED", MinSpeed = 85, MaxSpeed = 120, Colour = Color3.fromRGB(190, 70, 255), Weight = 9 },
		},
		-- Name lookup populated below from the tier records (one source for RGB).
		TierColours = {},
	},
	Resist = { MinimumMultiplier = 0.1, PerLevel = 0.08, PotionLevels = 5 }, -- WallServer.server.lua
	Jump = {
		-- SUGGESTED, NOT ACTIVE: cap jump near 65-70 so a pit-floor jump cannot reach the wall.
		SuggestedCapEnabled = false, SuggestedCap = 70,
	},
	-- Source: game-scripts/ReplicatedStorage/ShopConfig.lua; ShopServer.server.lua.
	Shop = {
		SignHideDistance = 140,
		PanelSizeIncrease = 0.35,
		MaxUpgradeLevel = 10,
		-- Each row owns its base price; n is the zero-based number of purchases.
		-- Price = floor(row.BasePrice * row.Growth^n).
		-- Baselines: WalkSpeed 16, JumpPower 50, MaxHealth 100.
		-- Per level: Speed +2, Health +25, Cash +25% additive income bonus.
		Upgrades = {
			{ Name = "Speed", Stat = "WalkSpeed", Step = 2, BaseValue = 16, Growth = 1.6, MaxLevel = 10, BasePrice = 25 },
			{ Name = "Jump", Stat = "JumpPower", Step = 5, BaseValue = 50, MaxValue = 100, Growth = 1.7, MaxLevel = 10, BasePrice = 30 },
			{ Name = "Health", Stat = "MaxHealth", Step = 25, BaseValue = 100, MaxValue = 350, Growth = 1.7, MaxLevel = 10, BasePrice = 30 },
			{ Name = "Cash", Stat = "IncomeBonus", Step = 0.25, BaseValue = 0, Growth = 1.8, MaxLevel = 10, BasePrice = 40 },
			{ Name = "Knockback Resist", Stat = "KnockbackLevel", Step = 1, BaseValue = 0, MaxValue = 10, Growth = 1.8, MaxLevel = 10, BasePrice = 60 },
			{ Name = "Ragdoll Resist", Stat = "RagdollLevel", Step = 1, BaseValue = 0, MaxValue = 10, Growth = 1.8, MaxLevel = 10, BasePrice = 60 },
		},
		PriceSuffixes = {
			{ Threshold = 1000, Suffix = "K" },
			{ Threshold = 1000000, Suffix = "M" },
			{ Threshold = 1000000000, Suffix = "B" },
		},
	},
	Inventory = {
		-- Source: game-scripts/ServerStorage/BrainrotInventory.lua.
		Unlimited = true, CarryMax = 3,
		RemoteCooldownSeconds = 0.15, MaxItemIdLength = 100,
		PickupRange = 10, GroundDropHeight = 2,
		WorldItemSize = { 3, 3, 3 }, LabelSize = { 240, 55 }, LabelHeight = 4,
		LabelTextSize = 16, LabelMaxDistance = 120,
		RainbowCycleSeconds = 4,
		UI = {
			PanelPosition = { 0.28, 0.18 }, PanelSize = { 520, 420 },
			IndexPosition = { 0.25, 0.16 }, IndexSize = { 660, 480 },
			ButtonPosition = { 0.02, 0.40 }, IndexButtonPosition = { 0.02, 0.48 },
			ButtonSize = { 150, 36 }, CarryPosition = { 0.35, 0.06 }, CarrySize = { 500, 40 },
			MessagePosition = { 0.35, 0.12 }, MessageSize = { 500, 40 }, MessageSeconds = 3,
			HeaderHeight = 40, RowHeight = 36, DropWidth = 70, SidebarWidth = 130,
			Padding = 8, ProgressHeight = 30, TextSize = 16,
			Background = Color3.fromRGB(30, 35, 45), TextColour = Color3.fromRGB(255, 255, 255),
			SelectedColour = Color3.fromRGB(60, 90, 120), RowColour = Color3.fromRGB(45, 50, 60),
			ProgressColour = Color3.fromRGB(60, 180, 100),
		},
		GroundItemExpirySeconds = 40,
		OwnerRepickupLockSeconds = 2,
		DropKey = "G",
		PedestalKey = "E",
	},
	Home = { CooldownSeconds = 2, Key = "H" },
	Index = { EntryCount = 25, Key = "I" },
	-- Source: game-scripts/ServerScriptService/SaveServer.server.lua; v1 is READ ONLY here.
	Saving = {
		SchemaVersion = 2, LegacyVersion = 1, IntervalSeconds = 60,
		StoreName = "BrainrotPlayerData_v2", LegacyStoreName = "BrainrotPlayerData_v1", KeyPrefix = "Player_",
		RetryAttempts = 3, RetryDelaySeconds = 1, RetryBackoff = 2,
		SessionLockSeconds = 180, CloseBudgetSeconds = 25, PollSeconds = 0.05,
		LegacyIdPrefix = "legacy-",
		LoadFailureMessage = "Your progress could not be loaded. Please rejoin.",
	},
	-- Source: game-scripts/ReplicatedStorage/WheelConfig.lua and ServerScriptService/WheelServer.server.lua.
	Wheel = {
		CooldownSeconds = 86400,
		PotionDurationSeconds = 900,
		-- Weights scaled by 100 for exact integer RNG: 18/18/16/14/14/14/0.67.
		RewardWeightTotal = 9467,
		RewardOrder = { "SpeedBoost", "DoubleMoney", "HealthBoost", "RagdollResist", "JumpBoost", "KnockbackResist", "Brainrot67" },
		RewardWeights = { SpeedBoost = 1800, DoubleMoney = 1800, HealthBoost = 1600,
			RagdollResist = 1400, JumpBoost = 1400, KnockbackResist = 1400, Brainrot67 = 67 },
		PotionEffects = {
			SpeedBoost = { walkSpeedBonus = 8 }, DoubleMoney = { incomeMult = 2 },
			HealthBoost = { maxHealthBonus = 50 }, RagdollResist = { ragdollLevels = 5 },
			JumpBoost = { jumpBonus = 25 }, KnockbackResist = { knockbackLevels = 5 },
		},
		PermanentReward = { Name = "Brainrot67", Droppable = false, Tradeable = false,
			HasVariants = false, LostOnDeath = false, CountsInIndex = false },
		-- Shared UI/expiry scheduling constants; all gameplay amounts live above.
		UI = {
			RefreshSeconds = 1, AnimationSeconds = 3, AnimationTurns = 4, FullTurnDegrees = 360,
			SecondsPerMinute = 60, MinutesPerHour = 60,
			ButtonPosition = { 0.02, 0.65 }, ButtonSize = { 150, 40 },
			PanelPosition = { 0.5, 0.5 }, PanelSize = { 340, 390 }, Anchor = { 0.5, 0.5 },
			HeaderPosition = { 10, 10 }, HeaderSize = { 320, 35 },
			WheelPosition = { 90, 65 }, WheelSize = { 160, 160 },
			ResultPosition = { 10, 235 }, ResultSize = { 320, 65 },
			SpinPosition = { 70, 325 }, SpinSize = { 200, 45 },
			StripPosition = { 0.02, 0.75 }, StripSize = { 300, 160 },
			RewardLabelSize = { 100, 25 }, RewardRadiusScale = 0.35, RewardTextSize = 11,
			TextSize = 18, BackgroundRGB = { 30, 35, 45 }, TextRGB = { 255, 255, 255 },
		},
	},
}

-- Exact original WheelConfig reward rows (including UI colour/attribute names).
Config.Wheel.Rewards = {
	{id = "Speed",     name = "Speed Boost",      icon = "⚡", color = Color3.fromRGB(255, 205, 60),  weight = 18, attr = "BoostSpeed",     desc = "+8 walk speed for 15 minutes"},
	{id = "Money",     name = "Double Money",     icon = "💵", color = Color3.fromRGB(70, 200, 90),   weight = 18, attr = "BoostMoney",     desc = "2x income for 15 minutes"},
	{id = "Health",    name = "Health Boost",     icon = "❤️", color = Color3.fromRGB(235, 70, 80),   weight = 16, attr = "BoostHealth",    desc = "+50 max health for 15 minutes"},
	{id = "Ragdoll",   name = "Ragdoll Resist",   icon = "⏱️", color = Color3.fromRGB(150, 110, 235), weight = 14, attr = "BoostRagdoll",   desc = "-40% ragdoll time for 15 minutes"},
	{id = "Jump",      name = "Jump Boost",       icon = "🦘", color = Color3.fromRGB(255, 150, 50),  weight = 14, attr = "BoostJump",      desc = "+25 jump power for 15 minutes"},
	{id = "Knockback", name = "Knockback Resist", icon = "🧱", color = Color3.fromRGB(90, 160, 220),  weight = 14, attr = "BoostKnockback", desc = "-40% knockback for 15 minutes"},
	{id = "Rare67",    name = "67 Brainrot",      icon = "67", color = Color3.fromRGB(255, 60, 200),  weight = 0.67, special = true,           desc = "PERMANENT! Earns as much as your best brainrot"},
}

-- Exact original ShopConfig rows retained for tools consuming the real field names.
Config.Shop.Items = {
	{id = "Speed",     title = "+2 Speed",             icon = "👟", baseCost = 25, growth = 1.6, maxLevel = 10, attr = "SpeedLevel",     base = 16,  step = 2,  suffix = ""},
	{id = "Jump",      title = "+5 Jump",              icon = "🦘", baseCost = 30, growth = 1.7, maxLevel = 10, attr = "JumpLevel",      base = 50,  step = 5,  suffix = ""},
	{id = "Health",    title = "+25 Health",           icon = "❤️", baseCost = 30, growth = 1.7, maxLevel = 10, attr = "HealthLevel",    base = 100, step = 25, suffix = ""},
	{id = "Cash",      title = "+25% Cash",            icon = "💰", baseCost = 40, growth = 1.8, maxLevel = 10, attr = "CashLevel",      base = 100, step = 25, suffix = "%"},
	{id = "Knockback", title = "+8% Knockback Resist", icon = "🛡️", baseCost = 60, growth = 1.8, maxLevel = 10, attr = "KnockbackLevel", base = 0,   step = 8,  suffix = "%"},
	{id = "Ragdoll",   title = "+8% Ragdoll Resist",   icon = "⏱️", baseCost = 60, growth = 1.8, maxLevel = 10, attr = "RagdollLevel",   base = 0,   step = 8,  suffix = "%"},
}

for _, tier in ipairs(Config.Wall.Tiers) do
	Config.Wall.TierColours[tier.Name] = tier.Colour
end

return Config
