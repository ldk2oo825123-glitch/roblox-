--!strict
-- Pure table codec. Inject Config, optional BrainrotData and an ID factory.
-- Pedestal keys are strings on disk so sparse slots survive DataStore encoding.
local ProfileLogic = {}
function ProfileLogic.new(Config, BrainrotData, newId)
	local L = {}
	local zero, one = Config.Math.Zero, Config.Math.One
	local sequence = zero
	local values, tiers, variants, keys = {}, {}, {}, {}
	for _, tier in ipairs(Config.Brainrots.Tiers) do
		tiers[tier.Name] = true
		for _, variant in ipairs(Config.Brainrots.Variants) do
			variants[variant.Name] = true
			local key = tier.Name .. "|" .. variant.Name
			keys[key] = true
			values[key] = math.floor(tier.BaseValue * (one + variant.Bonus) * Config.Math.ValueRoundingScale + one / (one + one)) / Config.Math.ValueRoundingScale
		end
	end
	local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge and n >= zero end
	local function integer(n) return finite(n) and n == math.floor(n) end
	local function tableOrEmpty(t) return type(t) == "table" and t or {} end
	local function id()
		sequence = sequence + one
		return newId and newId() or Config.Saving.LegacyIdPrefix .. tostring(sequence)
	end
	function L.default()
		local p = { version = Config.Saving.SchemaVersion, cash = zero, upgrades = {}, pedestals = {},
			inventory = {}, indexFound = {}, wheel = { lastSpinAt = zero, potions = {}, owns67 = false }, savedAt = zero }
		for _, upgrade in ipairs(Config.Shop.Upgrades) do p.upgrades[upgrade.Name] = zero end
		return p
	end
	local function item(raw, seen)
		if type(raw) ~= "table" or type(raw.id) ~= "string" or #raw.id == zero
			or #raw.id > Config.Inventory.MaxItemIdLength or seen[raw.id]
			or type(raw.tier) ~= "string" or #raw.tier == zero or not variants[raw.variant]
			or not finite(raw.value) then return nil end
		local expected = values[raw.tier .. "|" .. raw.variant]
		if tiers[raw.tier] and expected ~= raw.value then return nil end
		seen[raw.id] = true
		return { id = raw.id, tier = raw.tier, variant = raw.variant, value = raw.value }
	end
	-- Iterate numeric keys in order, tolerating holes and corrupt individual entries.
	local function ordered(t)
		local order = {}
		for k in pairs(tableOrEmpty(t)) do if integer(k) and k >= one then table.insert(order, k) end end
		table.sort(order); return order
	end
	function L.validate(raw)
		if type(raw) ~= "table" then return nil, "invalid profile" end
		if finite(raw.version) and raw.version > Config.Saving.SchemaVersion then return nil, "future version" end
		if raw.version ~= Config.Saving.SchemaVersion then return nil, "unsupported version" end
		if raw.cash ~= nil and not finite(raw.cash) then return nil, "invalid cash" end
		local p, seen = L.default(), {}
		p.cash = raw.cash or zero
		for name in pairs(p.upgrades) do
			local level = tableOrEmpty(raw.upgrades)[name]
			if integer(level) and level <= Config.Shop.MaxUpgradeLevel then p.upgrades[name] = level end
		end
		local slots = tableOrEmpty(raw.pedestals)
		for slot = one, Config.Bases.PedestalCount do p.pedestals[slot] = item(slots[slot] or slots[tostring(slot)], seen) end
		for _, i in ipairs(ordered(raw.inventory)) do
			local v = item(raw.inventory[i], seen); if v then table.insert(p.inventory, v) end
		end
		for k, v in pairs(tableOrEmpty(raw.indexFound)) do if keys[k] and v == true then p.indexFound[k] = true end end
		local wheel = tableOrEmpty(raw.wheel)
		if integer(wheel.lastSpinAt) then p.wheel.lastSpinAt = wheel.lastSpinAt end
		p.wheel.owns67 = wheel.owns67 == true
		for name, expiry in pairs(tableOrEmpty(wheel.potions)) do
			if Config.Wheel.PotionEffects[name] and integer(expiry) then p.wheel.potions[name] = expiry end
		end
		if integer(raw.savedAt) then p.savedAt = raw.savedAt end
		return p
	end
	function L.migrate(raw)
		if raw == nil then return L.default() end
		if type(raw) ~= "table" then return nil, "invalid profile" end
		if raw.version == Config.Saving.SchemaVersion then return L.validate(raw) end
		if raw.version ~= nil and raw.version ~= Config.Saving.LegacyVersion then
			return nil, finite(raw.version) and raw.version > Config.Saving.SchemaVersion and "future version" or "unsupported version"
		end
		local p = L.default()
		p.cash = raw.Cash == nil and zero or raw.Cash
		local legacyNames = { Speed = "SpeedLevel", Cash = "CashLevel", Health = "HealthLevel", Jump = "JumpLevel",
			["Knockback Resist"] = "KnockbackLevel", ["Ragdoll Resist"] = "RagdollLevel" }
		for name, legacy in pairs(legacyNames) do p.upgrades[name] = raw[legacy] or zero end
		local count = zero
		for _, i in ipairs(ordered(raw.Brainrots)) do
			local old = raw.Brainrots[i]
			if type(old) == "table" then
				local tier, variant = old.tier or old.Name, old.Variant or old.variant or "Normal"
				if type(tier) == "string" and variants[variant] then
					local value = values[tier .. "|" .. variant] or old.Value
					if tiers[tier] and BrainrotData then value = BrainrotData.CalculateValue(tier, variant) end
					if finite(value) then
						local v = { id = id(), tier = tier, variant = variant, value = value }
						count = count + one
						if count <= Config.Bases.PedestalCount then p.pedestals[count] = v else table.insert(p.inventory, v) end
						local k = tier .. "|" .. variant; if keys[k] then p.indexFound[k] = true end
					end
				end
			end
		end
		return L.validate(p)
	end
	function L.serialize(profile)
		local p, reason = L.validate(profile); if not p then return nil, reason end
		local slots = {}; for slot, v in pairs(p.pedestals) do slots[tostring(slot)] = v end
		p.pedestals = slots; return p
	end
	function L.deserialize(raw) return L.migrate(raw) end
	return L
end
return ProfileLogic
