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
	function helpers.rewardWeightTotal(owns67)
		return policy.RewardWeightTotal - (owns67 and policy.RewardWeights.Brainrot67 or zero)
	end
	function helpers.rollReward(roll, owns67)
		assert(integer(roll) and roll >= one and roll <= helpers.rewardWeightTotal(owns67), "Invalid wheel roll")
		local cumulative = zero
		for _, name in ipairs(policy.RewardOrder) do
			cumulative = cumulative + ((owns67 and name == "Brainrot67") and zero or policy.RewardWeights[name])
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
		state.potions[rewardName] = math.max(now, state.potions[rewardName] or now) + policy.PotionDurationSeconds
		return "granted"
	end
	function helpers.potionModifiers(state, now)
		local result = { walkSpeedBonus = zero, incomeMult = one, maxHealthBonus = zero,
			ragdollLevels = zero, knockbackLevels = zero, jumpBonus = zero }
		for name in pairs(helpers.activePotions(state, now)) do
			for key, value in pairs(policy.PotionEffects[name]) do result[key] = value end
		end
		return result
	end
	-- Upgrade stats are supplied separately: wheel state stores no upgrade data.
	function helpers.effectiveStats(state, now, base)
		local m = helpers.potionModifiers(state, now)
		return { WalkSpeed = base.WalkSpeed + m.walkSpeedBonus,
			JumpPower = base.JumpPower + m.jumpBonus,
			MaxHealth = base.MaxHealth + m.maxHealthBonus,
			IncomeMult = base.IncomeMult * m.incomeMult,
			RagdollReduction = one - math.max(Config.Resist.MinimumMultiplier, one - Config.Resist.PerLevel * ((base.RagdollLevel or zero) + m.ragdollLevels)),
			KnockbackReduction = one - math.max(Config.Resist.MinimumMultiplier, one - Config.Resist.PerLevel * ((base.KnockbackLevel or zero) + m.knockbackLevels)) }
	end
	function helpers.brainrot67Value(pedestalValues)
		local highest = one -- BaseServer.itemValue: dynamic items have a minimum value of 1.
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
