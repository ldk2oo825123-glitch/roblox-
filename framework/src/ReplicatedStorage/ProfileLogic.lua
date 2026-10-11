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
		return { id = raw.id, tier = raw.tier, variant = raw.variant, value = raw.value, r = finite(raw.r) and raw.r <= one and raw.r or nil,
			g = finite(raw.g) and raw.g <= one and raw.g or nil, b = finite(raw.b) and raw.b <= one and raw.b or nil,
			mat = type(raw.mat) == "string" and raw.mat or nil }
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
		p.legacyDiscovered = nil
		if type(raw.legacyDiscovered) == "table" then
			p.legacyDiscovered = {}
			for _, name in ipairs(raw.legacyDiscovered) do if type(name) == "string" then table.insert(p.legacyDiscovered, name) end end
		end
		return p
	end
	local levelFields = { Speed = "speed", Cash = "cashBoost", Health = "health", Jump = "jump",
		["Knockback Resist"] = "knockback", ["Ragdoll Resist"] = "ragdollRes" }
	local boostFields = { SpeedBoost = "boostSpeed", DoubleMoney = "boostMoney", HealthBoost = "boostHealth",
		RagdollResist = "boostRagdoll", JumpBoost = "boostJump", KnockbackResist = "boostKnockback" }
	local function parseName(name)
		if type(name) ~= "string" or name == "" then return nil end
		for _, variant in ipairs(Config.Brainrots.Variants) do
			local prefix = variant.Name .. " "
			if variant.Name ~= "Normal" and name:sub(one, #prefix) == prefix then
				return name:sub(#prefix + one), variant.Name
			end
		end
		return name, "Normal"
	end
	function L.migrate(raw, now)
		if raw == nil then return L.default() end
		if type(raw) ~= "table" then return nil, "invalid profile" end
		if raw.version == Config.Saving.SchemaVersion then return L.validate(raw) end
		if raw.version ~= nil and raw.version ~= Config.Saving.LegacyVersion then
			return nil, finite(raw.version) and raw.version > Config.Saving.SchemaVersion and "future version" or "unsupported version"
		end
		now = now or os.time()
		local p = L.default()
		p.cash = finite(raw.cash) and raw.cash or zero
		for name, field in pairs(levelFields) do p.upgrades[name] = raw[field] or zero end
		p.wheel.owns67 = raw.has67 == true
		if integer(raw.nextSpin) and raw.nextSpin > zero then
			p.wheel.lastSpinAt = raw.nextSpin - Config.Wheel.CooldownSeconds
		end
		for name, field in pairs(boostFields) do
			if integer(raw[field]) and raw[field] > now then p.wheel.potions[name] = raw[field] end
		end
		local slot = zero
		local function add(old, pedestal)
			if type(old) ~= "table" then return end
			if old.name == "67 Brainrot" then p.wheel.owns67 = true; return end
			local tier, variant = parseName(old.name)
			if not tier then return end
			local value = values[tier .. "|" .. variant] or (finite(old.value) and old.value or one)
			local v = { id = id(), tier = tier, variant = variant, value = value,
				r = old.r, g = old.g, b = old.b, mat = old.mat }
			if pedestal and slot < Config.Bases.PedestalCount then
				slot = slot + one; p.pedestals[slot] = v
			else table.insert(p.inventory, v) end
			local k = tier .. "|" .. variant; if keys[k] then p.indexFound[k] = true end
		end
		for _, i in ipairs(ordered(raw.inventory)) do
			local old = raw.inventory[i]
			if type(old) == "table" then
				local count = integer(old.count) and old.count or one
				for _ = one, count do add(old, false) end
			end
		end
		for _, i in ipairs(ordered(raw.stored)) do add(raw.stored[i], true) end
		for _, name in ipairs(tableOrEmpty(raw.discovered)) do
			if name == "67 Brainrot" then p.wheel.owns67 = true end
			local tier, variant = parseName(name)
			local k = tier and tier .. "|" .. variant
			if k and keys[k] then p.indexFound[k] = true
			elseif type(name) == "string" then
				p.legacyDiscovered = p.legacyDiscovered or {}; table.insert(p.legacyDiscovered, name)
			end
		end
		return L.validate(p)
	end
	-- Diagnostic/export codec only. Saving never writes this result to v1.
	function L.toLegacyV1(profile)
		local p, reason = L.validate(profile); if not p then return nil, reason end
		local raw = { cash = p.cash, inventory = {}, stored = {}, discovered = {}, has67 = p.wheel.owns67,
			nextSpin = p.wheel.lastSpinAt == zero and zero or p.wheel.lastSpinAt + Config.Wheel.CooldownSeconds }
		for name, field in pairs(levelFields) do raw[field] = p.upgrades[name] end
		for name, field in pairs(boostFields) do raw[field] = p.wheel.potions[name] or zero end
		local function record(v)
			local tierData, variantData
			for _, t in ipairs(Config.Brainrots.Tiers) do if t.Name == v.tier then tierData = t end end
			for _, variant in ipairs(Config.Brainrots.Variants) do if variant.Name == v.variant then variantData = variant end end
			local c = variantData.BaseColour or (tierData and tierData.Colour)
			return { name = (v.variant == "Normal" and "" or v.variant .. " ") .. v.tier, value = v.value,
				r = v.r or (c and c.R) or 0.8, g = v.g or (c and c.G) or 0.8, b = v.b or (c and c.B) or 0.8,
				mat = v.mat or variantData.Material or (tierData and tierData.Material) or "SmoothPlastic" }
		end
		local groups = {}
		for _, v in ipairs(p.inventory) do
			local r = record(v)
			local k = table.concat({r.name, r.value, r.r, r.g, r.b, r.mat}, "|")
			if groups[k] then groups[k].count = groups[k].count + one
			else r.count = one; groups[k] = r; table.insert(raw.inventory, r) end
		end
		for slot = one, Config.Bases.PedestalCount do if p.pedestals[slot] then table.insert(raw.stored, record(p.pedestals[slot])) end end
		if p.wheel.owns67 then table.insert(raw.inventory, {name = "67 Brainrot", value = one, r = 1, g = 60/255, b = 200/255, mat = "Neon", count = one}) end
		for k in pairs(p.indexFound) do
			local tier, variant = k:match("^(.*)|([^|]+)$")
			table.insert(raw.discovered, (variant == "Normal" and "" or variant .. " ") .. tier)
		end
		for _, name in ipairs(p.legacyDiscovered or {}) do table.insert(raw.discovered, name) end
		return raw
	end
	function L.serialize(profile)
		local p, reason = L.validate(profile); if not p then return nil, reason end
		local slots = {}; for slot, v in pairs(p.pedestals) do slots[tostring(slot)] = v end
		p.pedestals = slots; return p
	end
	function L.deserialize(raw, now) return L.migrate(raw, now) end
	return L
end
return ProfileLogic
