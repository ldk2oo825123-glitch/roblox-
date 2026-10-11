--!strict
-- Engine-independent. Inject Config once; all mutations preserve item identity.
local InventoryLogic = {}
function InventoryLogic.new(Config, allowLegacyTiers)
	local L = {}
	local zero, one = Config.Math.Zero, Config.Math.One
	local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
	local function slotValid(slot)
		return finite(slot) and slot == math.floor(slot) and slot >= one and slot <= Config.Bases.PedestalCount
	end
	local function key(item) return item.tier .. "|" .. item.variant end
	local validKeys, values, tiers, variants = {}, {}, {}, {}
	for _, tier in ipairs(Config.Brainrots.Tiers) do
		tiers[tier.Name] = true
		for _, variant in ipairs(Config.Brainrots.Variants) do
			variants[variant.Name] = true
			local k = tier.Name .. "|" .. variant.Name
			validKeys[k] = true
			values[k] = math.floor(tier.BaseValue * (one + variant.Bonus) * Config.Math.ValueRoundingScale + one / (one + one)) / Config.Math.ValueRoundingScale
		end
	end
	function L.newState() return { carried = {}, inventory = {}, indexFound = {}, pedestals = {} } end
	function L.validItem(item)
		return type(item) == "table" and type(item.id) == "string" and #item.id > zero
			and #item.id <= Config.Inventory.MaxItemIdLength and type(item.tier) == "string"
			and #item.tier > zero and type(item.variant) == "string" and variants[item.variant] == true
			and finite(item.value) and item.value >= zero
			and (values[key(item)] == item.value or (allowLegacyTiers == true and not tiers[item.tier])) -- Preserve retired legacy tiers.
	end
	function L.validateState(state)
		if type(state) ~= "table" then return false end
		local seen = {}
		for _, name in ipairs({ "carried", "inventory", "pedestals" }) do
			if type(state[name]) ~= "table" then return false end
			local count = zero
			for i, item in pairs(state[name]) do
				if not finite(i) or i < one or i ~= math.floor(i) or
					(name == "pedestals" and not slotValid(i)) or not L.validItem(item) or seen[item.id] then return false end
				seen[item.id] = true; count = count + one
			end
			if name ~= "pedestals" and count ~= #state[name] then return false end
		end
		if type(state.indexFound) ~= "table" then return false end
		for k, found in pairs(state.indexFound) do if not validKeys[k] or found ~= true then return false end end
		return true
	end
	function L.copyState(state)
		local copy = L.newState()
		for _, name in ipairs({ "carried", "inventory", "pedestals" }) do
			for i, item in pairs(state[name]) do
				copy[name][i] = { id = item.id, tier = item.tier, variant = item.variant, value = item.value }
			end
		end
		for k, found in pairs(state.indexFound) do copy.indexFound[k] = found end
		return copy
	end
	function L.addCarried(state, item)
		if not L.validItem(item) then return nil, "invalid item" end
		for _, name in ipairs({ "carried", "inventory", "pedestals" }) do
			for _, existing in pairs(state[name]) do if existing.id == item.id then return nil, "duplicate item" end end
		end
		table.insert(state.carried, item); return item
	end
	function L.moveCarriedToInventory(state)
		local moved = state.carried; state.carried = {}
		for _, item in ipairs(moved) do table.insert(state.inventory, item); if validKeys[key(item)] then state.indexFound[key(item)] = true end end
		return moved
	end
	function L.dropCarried(state, reason)
		assert(reason == "death" or reason == "ragdoll", "Invalid drop reason")
		local dropped = state.carried; state.carried = {}; return dropped
	end
	function L.dropFromInventory(state, itemId)
		for i, item in ipairs(state.inventory) do if item.id == itemId then return table.remove(state.inventory, i) end end
		return nil, "item not in inventory"
	end
	function L.placeOnPedestal(state, itemId, slot)
		if not slotValid(slot) then return nil, "invalid slot" end
		if state.pedestals[slot] then return nil, "occupied slot" end
		local item, reason = L.dropFromInventory(state, itemId)
		if not item then return nil, reason end
		state.pedestals[slot] = item; return item
	end
	function L.pickUpFromPedestal(state, slot)
		if not slotValid(slot) then return nil, "invalid slot" end
		local item = state.pedestals[slot]
		if not item then return nil, "empty slot" end
		state.pedestals[slot] = nil; table.insert(state.inventory, item); if validKeys[key(item)] then state.indexFound[key(item)] = true end
		return item
	end
	function L.incomePerTick(state, incomeMult)
		assert(finite(incomeMult) and incomeMult >= zero, "Invalid income multiplier")
		local total = zero
		for _, item in pairs(state.pedestals) do total = total + item.value end
		return math.floor(total * incomeMult * Config.Math.ValueRoundingScale + one / (one + one)) / Config.Math.ValueRoundingScale
	end
	function L.bestPedestalValue(state)
		local best = zero
		for _, item in pairs(state.pedestals) do best = math.max(best, item.value) end
		return best
	end
	function L.indexProgress(state)
		local found = zero
		for k, v in pairs(state.indexFound) do if v and validKeys[k] then found = found + one end end
		return found, Config.Index.EntryCount
	end
	function L.groupInventory(state)
		local groups, lookup = {}, {}
		for _, item in ipairs(state.inventory) do
			local k = key(item); local group = lookup[k]
			if not group then group = { tier = item.tier, variant = item.variant, count = zero, items = {} }; lookup[k] = group; table.insert(groups, group) end
			group.count = group.count + one; table.insert(group.items, item)
		end
		table.sort(groups, function(a, b) return key(a) < key(b) end)
		return groups
	end
	-- Coordinates are plain {X,Y,Z} records or Roblox Vector3 (adapter supplied).
	function L.inSafeZone(position)
		local b = Config.Map.SafeZone
		return position.X >= b.MinX and position.X <= b.MaxX and position.Y >= b.MinY and position.Y <= b.MaxY and position.Z >= b.MinZ and position.Z <= b.MaxZ
	end
	function L.canAccessBase(player, base, slot, distance)
		if not base then return false, "no base available" end
		if base.owner ~= player then return false, "not your base" end
		if not slotValid(slot) then return false, "invalid slot" end
		if not finite(distance) or distance > Config.Bases.InteractionRange or distance < zero then return false, "too far from pedestal" end
		return true
	end
	return L
end
return InventoryLogic
