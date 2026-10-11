--!strict

-- Inject Config once: require(Balance).new(require(Config)). No engine APIs or RNG.
local Balance = {}

function Balance.new(Config)
	local helpers = {}
	local zero = Config.Math.Zero
	local one = Config.Math.One

	local function finiteNumber(value)
		return type(value) == "number" and value == value and math.abs(value) < math.huge
	end

	local function interpolate(speed, range)
		assert(finiteNumber(speed), "Wall speed must be finite")
		local limits = Config.Wall.Speed
		local fraction = math.max(zero, math.min(one, (speed - limits.Min) / (limits.Max - limits.Min)))
		return range.Min + (range.Max - range.Min) * fraction
	end

	function helpers.wallDamage(speed)
		return interpolate(speed, Config.Wall.Damage)
	end

	function helpers.wallRagdollSeconds(speed)
		return interpolate(speed, Config.Wall.RagdollSeconds)
	end

	function helpers.wallFling(speed)
		return interpolate(speed, Config.Wall.Fling.Horizontal), interpolate(speed, Config.Wall.Fling.Vertical)
	end

	function helpers.upgradePrice(name, purchases)
		assert(finiteNumber(purchases) and purchases >= zero and purchases == math.floor(purchases),
			"Purchases must be a non-negative integer")
		for _, upgrade in ipairs(Config.Shop.Upgrades) do
			if upgrade.Name == name then
				return math.floor(upgrade.BasePrice * Config.Shop.PriceCurve.GrowthFactor ^ purchases)
			end
		end
		error("Unknown upgrade: " .. tostring(name))
	end

	function helpers.formatPrice(n)
		assert(finiteNumber(n) and n >= zero, "Price must be finite and non-negative")
		local suffixes = Config.Shop.PriceSuffixes
		for index = #suffixes, one, -one do
			local entry = suffixes[index]
			if n >= entry.Threshold then
				local format = "%." .. tostring(Config.Math.ValueDecimalPlaces) .. "f"
				return string.format(format, n / entry.Threshold) .. entry.Suffix
			end
		end
		return string.format("%." .. tostring(zero) .. "f", math.floor(n))
	end

	-- roll is a uniformly chosen integer in [1, sum(weights)], supplied by caller.
	-- Returns the complete tier record; speed selection remains the caller's job.
	function helpers.pickWallTier(roll)
		assert(finiteNumber(roll) and roll >= one and roll == math.floor(roll),
			"Wall roll must be a positive integer")
		local cumulative = zero
		for _, tier in ipairs(Config.Wall.Tiers) do
			cumulative = cumulative + tier.Weight
			if roll <= cumulative then
				return tier
			end
		end
		error("Wall roll exceeds total tier weight")
	end

	return helpers
end

return Balance
