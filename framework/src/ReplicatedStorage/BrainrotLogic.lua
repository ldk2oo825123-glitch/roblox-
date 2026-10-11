--!strict
local BrainrotLogic = {}
function BrainrotLogic.new(Config)
	local L = {}
	local zero, one = Config.Math.Zero, Config.Math.One
	function L.rollVariant(roll)
		assert(type(roll) == "number" and roll >= zero and roll < one, "Invalid variant roll")
		local sum = zero
		for _, variant in ipairs(Config.Brainrots.Variants) do
			sum = sum + variant.Odds
			if roll < sum then return variant.Name end
		end
		return Config.Brainrots.Variants[#Config.Brainrots.Variants].Name
	end
	function L.band(tier)
		assert(type(tier) == "number" and tier == math.floor(tier) and tier >= one and tier <= #Config.Brainrots.Tiers, "Invalid tier")
		return Config.Map.RarityBoundaries[tier - one] or zero, Config.Map.RarityBoundaries[tier] or Config.Map.DangerLength
	end
	function L.overPit(x, z, rects)
		for _, r in ipairs(rects) do if x >= r.MinX and x <= r.MaxX and z >= r.MinZ and z <= r.MaxZ then return true end end
		return false
	end
	function L.spawnPoint(tier, rects, nextNumber)
		local low, high = L.band(tier); local margin = Config.Brainrots.SpawnMargin
		for _ = one, Config.Brainrots.SpawnAttempts do
			local x = nextNumber(-Config.Map.DangerHalfWidth + margin, Config.Map.DangerHalfWidth - margin)
			local z = nextNumber(low + margin, high - margin)
			if not L.overPit(x, z, rects) then return { X = x, Y = Config.Brainrots.SpawnY, Z = z } end
		end
		return nil -- Fully obstructed band: skip/retry rather than spawn over a pit.
	end
	return L
end
return BrainrotLogic
