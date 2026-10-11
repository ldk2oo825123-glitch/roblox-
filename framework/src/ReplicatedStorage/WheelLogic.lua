--!strict

-- Inject Config; this module runs unchanged in plain Lua. State is mutated only
-- by activePotions/applyReward. lastSpinAt=0 is the never-spun sentinel.
local WheelLogic = {}

function WheelLogic.new(Config)
	local helpers = {}
	local zero, one = Config.Math.Zero, Config.Math.One
	local policy = Config.Wheel
	local function integer(value)
		return type(value) == "number" and value == value and value < math.huge
			and value >= zero and value == math.floor(value)
	end
	function helpers.validateState(state)
		if type(state) ~= "table" or not integer(state.lastSpinAt)
			or type(state.owns67) ~= "boolean" or type(state.potions) ~= "table" then
			return false
		end
		for name, expiry in pairs(state.potions) do
			if not policy.PotionEffects[name] or not integer(expiry) then return false end
		end
		return true
	end
	function helpers.nextSpinAt(state)
		if state.lastSpinAt == zero then return zero end
		return state.lastSpinAt + policy.CooldownSeconds
	end
	function helpers.canSpin(state, now)
		assert(integer(now), "Time must be a non-negative integer")
		local remaining = math.max(zero, helpers.nextSpinAt(state) - now)
		return remaining == zero, remaining
	end
	function helpers.rollReward(roll)
		assert(integer(roll) and roll >= one and roll <= policy.RewardWeightTotal, "Invalid wheel roll")
		local cumulative = zero
		for _, name in ipairs(policy.RewardOrder) do
			cumulative = cumulative + policy.RewardWeights[name]
			if roll <= cumulative then return name end
		end
		error("Invalid wheel weights")
	end
	function helpers.activePotions(state, now)
		assert(integer(now), "Time must be a non-negative integer")
		local active = {}
		for name, expiry in pairs(state.potions) do
			if expiry > now then active[name] = expiry else state.potions[name] = nil end
		end
		return active
	end
	function helpers.applyReward(state, rewardName, now)
		assert(integer(now), "Time must be a non-negative integer")
		assert(policy.PotionEffects[rewardName] or rewardName == policy.PermanentReward.Name, "Unknown reward")
		helpers.activePotions(state, now)
		if rewardName == policy.PermanentReward.Name then
			if state.owns67 then return "already owned" end
			state.owns67 = true
			return "granted"
		end
		state.potions[rewardName] = math.min(now + policy.PotionStackCapSeconds,
			math.max(now, state.potions[rewardName] or now) + policy.PotionDurationSeconds)
		return "granted"
	end
	function helpers.potionModifiers(state, now)
		local result = { walkSpeedMult = one, incomeMult = one, maxHealthBonus = zero,
			ragdollReduction = zero, knockbackReduction = zero, jumpBonus = zero }
		for name in pairs(helpers.activePotions(state, now)) do
			for key, value in pairs(policy.PotionEffects[name]) do result[key] = value end
		end
		result.ragdollReduction = math.min(policy.MaxCombinedReduction, result.ragdollReduction)
		result.knockbackReduction = math.min(policy.MaxCombinedReduction, result.knockbackReduction)
		result.jumpBonus = math.min(Config.Jump.MaxEffectiveJumpPower, result.jumpBonus)
		return result
	end
	-- Upgrade stats are supplied separately: wheel state stores no upgrade data.
	function helpers.effectiveStats(state, now, base)
		local m = helpers.potionModifiers(state, now)
		return { WalkSpeed = base.WalkSpeed * m.walkSpeedMult,
			JumpPower = math.min(Config.Jump.MaxEffectiveJumpPower, base.JumpPower + m.jumpBonus),
			MaxHealth = base.MaxHealth + m.maxHealthBonus,
			IncomeMult = base.IncomeMult * m.incomeMult,
			RagdollReduction = math.min(policy.MaxCombinedReduction, base.RagdollReduction + m.ragdollReduction),
			KnockbackReduction = math.min(policy.MaxCombinedReduction, base.KnockbackReduction + m.knockbackReduction) }
	end
	function helpers.brainrot67Value(pedestalValues)
		local highest = zero
		for _, value in pairs(pedestalValues) do
			assert(type(value) == "number" and value == value and value >= zero and value < math.huge,
				"Pedestal value must be finite and non-negative")
			highest = math.max(highest, value)
		end
		return highest
	end
	return helpers
end
return WheelLogic
