--!strict

-- Authoritative design values.
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
		-- TODO(T4-geometry): Studio/MapBuilder geometry MUST match these placeholder
		-- bounds: safe zone z=-100..0, danger corridor z=0..800, floor y=0.
		SafeZone = { MinX = -160, MaxX = 160, MinY = -10, MaxY = 60, MinZ = -100, MaxZ = 0 },
		DangerHalfWidth = 50,
		-- Distances from the safe-zone edge: five equal 160-stud bands, band i = tier i.
		RarityBoundaries = { 160, 320, 480, 640 },
	},
	Bases = {
		PlotCount = 5,
		MaxPlayers = 5,
		PedestalCount = 6,
		IncomeIntervalSeconds = 5,
		-- Base signs retain fractional variant income instead of rounding to whole dollars.
		IncomeDisplayDecimals = 1,
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
	Brainrots = {
		RespawnSeconds = 8,
		SpawnsPerTier = 8, SpawnMargin = 4, SpawnAttempts = 100,
		SpawnY = 3, SafeZonePollSeconds = 0.2,
		Tiers = {
			{ Name = "Noodle Goblin", BaseValue = 1 },
			{ Name = "Sigma Frog", BaseValue = 3 },
			{ Name = "Turbo Toast", BaseValue = 8 },
			{ Name = "Cosmic Banana", BaseValue = 20 },
			{ Name = "Golden Gigarot", BaseValue = 60 },
		},
		-- Normal takes the 0.5% remainder (80.5%) so the odds sum to exactly 1.0.
		Variants = {
			{ Name = "Normal", Bonus = 0, Odds = 0.805, Colour = "normal", ColourCycling = false },
			{ Name = "Gold", Bonus = 0.10, Odds = 0.10, Colour = "gold", ColourCycling = false },
			{ Name = "Diamond", Bonus = 0.20, Odds = 0.05, Colour = "diamond", ColourCycling = false },
			{ Name = "Emerald", Bonus = 0.30, Odds = 0.03, Colour = "emerald", ColourCycling = false },
			{ Name = "Rainbow", Bonus = 0.40, Odds = 0.015, Colour = "rainbow", ColourCycling = true },
		},
		-- Variant.Colour is the lookup key for these exact label colours.
		-- Rainbow labels AND inventory dots cycle hue by time on the client when
		-- ColourCycling=true; white is only the initial colour, not a static rainbow.
		VariantColours = {
			normal = Color3.fromRGB(255, 255, 255),
			gold = Color3.fromRGB(255, 200, 40),
			diamond = Color3.fromRGB(170, 230, 255),
			emerald = Color3.fromRGB(60, 230, 110),
			rainbow = Color3.fromRGB(255, 255, 255),
		},
	},
	Wall = {
		WaitSeconds = 20,
		WarningSeconds = 5,
		-- At 120 studs/s the corridor is crossed in 800/120 = 6.67 seconds.
		-- Faster tiers get longer warnings within the existing 20-second wait.
		WarningSecondsByTier = {
			SLOW = 5, MEDIUM = 5, FAST = 5, EXTREME = 5, INSANE = 7, LIGHTSPEED = 8,
		},
		GroundClearance = 2,
		HitDebounceSeconds = 2.5,
		Speed = { Min = 14, Max = 120 },
		-- Health caps at 100 + 25*10 = 350. Damage scales linearly 60..400:
		-- damage reaches full upgraded health at approximately speed 104.41,
		-- in upper LIGHTSPEED; this lethality at the top end is intended.
		Damage = { Min = 60, Max = 400 },
		RagdollSeconds = { Min = 2, Max = 9 },
		-- Launch toward the safe zone and upward, linearly across speed 14..120.
		Fling = { Horizontal = { Min = 60, Max = 350 }, Vertical = { Min = 30, Max = 120 } },
		-- Integer weights replace qualitative odds and sum to 100.
		Tiers = {
			{ Name = "SLOW", MinSpeed = 14, MaxSpeed = 22, Colour = Color3.fromRGB(60, 200, 80), Weight = 30 },
			{ Name = "MEDIUM", MinSpeed = 22, MaxSpeed = 32, Colour = Color3.fromRGB(240, 210, 50), Weight = 28 },
			{ Name = "FAST", MinSpeed = 32, MaxSpeed = 45, Colour = Color3.fromRGB(245, 140, 30), Weight = 22 },
			{ Name = "EXTREME", MinSpeed = 45, MaxSpeed = 60, Colour = Color3.fromRGB(225, 40, 40), Weight = 12 },
			{ Name = "INSANE", MinSpeed = 60, MaxSpeed = 85, Colour = Color3.fromRGB(120, 10, 20), Weight = 6 },
			{ Name = "LIGHTSPEED", MinSpeed = 85, MaxSpeed = 120, Colour = Color3.fromRGB(150, 60, 230), Weight = 2 },
		},
		-- Name lookup populated below from the tier records (one source for RGB).
		TierColours = {},
	},
	Jump = {
		-- Override the spec's +5: +1.5 gives 50 + 1.5*10 = 65.
		-- Hard clamp total JumpPower, including potion bonuses, to 70.
		-- At standard gravity 196.2, apex rise = v^2/(2*g): 100 gives 25.48
		-- studs, 65 gives 10.77, and 70 gives 12.49, below pit depth 14 +
		-- clearance 2 = 16. Character geometry/engine behaviour needs Studio checks.
		MaxEffectiveJumpPower = 70,
	},
	Shop = {
		SignHideDistance = 140,
		PanelSizeIncrease = 0.35,
		MaxUpgradeLevel = 10,
		-- Each row owns its base price; n is the zero-based number of purchases.
		-- Price = floor(row.BasePrice * GrowthFactor^n).
		PriceCurve = { GrowthFactor = 1.6 },
		-- Baselines: WalkSpeed 16, JumpPower 50, MaxHealth 100.
		-- Per level: Speed +2, Health +25, Cash +25% additive income bonus.
		Upgrades = {
			{ Name = "Speed", Stat = "WalkSpeed", Step = 2, BaseValue = 16, BasePrice = 25 },
			{ Name = "Jump", Stat = "JumpPower", Step = 1.5, BaseValue = 50, MaxValue = 65, BasePrice = 30 },
			{ Name = "Health", Stat = "MaxHealth", Step = 25, BaseValue = 100, MaxValue = 350, BasePrice = 30 },
			{ Name = "Cash", Stat = "IncomeBonus", Step = 0.25, BaseValue = 0, BasePrice = 40 },
			{ Name = "Knockback Resist", Stat = "KnockbackReduction", Step = 0.08, BaseValue = 0, MaxValue = 0.80, BasePrice = 50 },
			{ Name = "Ragdoll Resist", Stat = "RagdollReduction", Step = 0.08, BaseValue = 0, MaxValue = 0.80, BasePrice = 50 },
		},
		PriceSuffixes = {
			{ Threshold = 1000, Suffix = "K" },
			{ Threshold = 1000000, Suffix = "M" },
			{ Threshold = 1000000000, Suffix = "B" },
		},
	},
	Inventory = {
		Unlimited = true,
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
	Saving = {
		SchemaVersion = 2, LegacyVersion = 1, IntervalSeconds = 60,
		StoreName = "EscapeWallProfiles", KeyPrefix = "Player_",
		RetryAttempts = 3, RetryDelaySeconds = 1, RetryBackoff = 2,
		SessionLockSeconds = 180, CloseBudgetSeconds = 25, PollSeconds = 0.05,
		LegacyIdPrefix = "legacy-",
		LoadFailureMessage = "Your progress could not be loaded. Please rejoin.",
	},
	Wheel = {
		CooldownSeconds = 86400,
		PotionDurationSeconds = 900,
		PotionStackCapSeconds = 3600,
		MaxCombinedReduction = 0.90,
		RewardWeightTotal = 10000,
		RewardOrder = { "SpeedBoost", "DoubleMoney", "HealthBoost", "RagdollResist", "JumpBoost", "KnockbackResist", "Brainrot67" },
		RewardWeights = { SpeedBoost = 1660, DoubleMoney = 1660, HealthBoost = 1660,
			RagdollResist = 1660, JumpBoost = 1660, KnockbackResist = 1660, Brainrot67 = 40 },
		PotionEffects = {
			SpeedBoost = { walkSpeedMult = 1.5 }, DoubleMoney = { incomeMult = 2 },
			HealthBoost = { maxHealthBonus = 100 }, RagdollResist = { ragdollReduction = 0.40 },
			JumpBoost = { jumpBonus = 15 }, KnockbackResist = { knockbackReduction = 0.40 },
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

for _, tier in ipairs(Config.Wall.Tiers) do
	Config.Wall.TierColours[tier.Name] = tier.Colour
end

return Config
