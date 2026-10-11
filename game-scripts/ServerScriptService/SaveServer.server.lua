local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")
local Inventory = require(ServerStorage:WaitForChild("BrainrotInventory"))

local dataStore = DataStoreService:GetDataStore("BrainrotPlayerData_v1")
local AUTOSAVE_INTERVAL = 60

local loaded = {}        -- player -> true once their data is loaded (only then can we save)
local restored = {}      -- player -> true once stored brainrots were put back in their base
local lastStored = {}    -- player -> stored brainrots from their save (kept if they had no base)
local saving = {}

local function keyFor(plr)
	return "Player_" .. plr.UserId
end

local function getStored(plr)
	local fn = ServerStorage:FindFirstChild("GetStoredItems")
	if not fn then return nil end
	local ok, result = pcall(function() return fn:Invoke(plr) end)
	if ok then return result end
	return nil
end

local function serialize(plr)
	local cash = plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Cash")
	local stored
	if restored[plr] then
		stored = getStored(plr)
	end
	stored = stored or lastStored[plr] or {}
	lastStored[plr] = stored
	return {
		cash = cash and cash.Value or 0,
		speed = plr:GetAttribute("SpeedLevel") or 0,
		cashBoost = plr:GetAttribute("CashLevel") or 0,
		health = plr:GetAttribute("HealthLevel") or 0,
		knockback = plr:GetAttribute("KnockbackLevel") or 0,
		jump = plr:GetAttribute("JumpLevel") or 0,
		ragdollRes = plr:GetAttribute("RagdollLevel") or 0,
		inventory = Inventory.serializeStored(plr),
		discovered = Inventory.discoveredList(plr),
		nextSpin = plr:GetAttribute("NextSpin") or 0,
		has67 = plr:GetAttribute("Has67") == true,
		boostSpeed = plr:GetAttribute("BoostSpeed") or 0,
		boostMoney = plr:GetAttribute("BoostMoney") or 0,
		boostHealth = plr:GetAttribute("BoostHealth") or 0,
		boostRagdoll = plr:GetAttribute("BoostRagdoll") or 0,
		boostJump = plr:GetAttribute("BoostJump") or 0,
		boostKnockback = plr:GetAttribute("BoostKnockback") or 0,
		stored = stored,
	}
end

local function save(plr)
	if not loaded[plr] or saving[plr] then return end
	saving[plr] = true
	local data = serialize(plr)
	local ok, err
	for attempt = 1, 3 do
		ok, err = pcall(function()
			dataStore:SetAsync(keyFor(plr), data)
		end)
		if ok then break end
		warn("Save failed for " .. plr.Name .. " (attempt " .. attempt .. "): " .. tostring(err))
		task.wait(2)
	end
	saving[plr] = nil
	return ok
end

local function load(plr)
	local data, ok
	for attempt = 1, 3 do
		ok, data = pcall(function()
			return dataStore:GetAsync(keyFor(plr))
		end)
		if ok then break end
		warn("Load failed for " .. plr.Name .. " (attempt " .. attempt .. "): " .. tostring(data))
		task.wait(2)
	end
	if not ok then
		-- Don't let them play (and later overwrite their save with empty data)
		plr:Kick("Couldn't load your saved data. Please rejoin in a moment.")
		return
	end
	if plr.Parent ~= Players then return end
	data = data or {}

	local ls = plr:WaitForChild("leaderstats", 15)
	local cash = ls and ls:WaitForChild("Cash", 15)
	if not cash then
		plr:Kick("Couldn't set up your data. Please rejoin.")
		return
	end

	cash.Value = data.cash or 0
	plr:SetAttribute("SpeedLevel", data.speed or 0)
	plr:SetAttribute("CashLevel", data.cashBoost or 0)
	plr:SetAttribute("HealthLevel", data.health or 0)
	plr:SetAttribute("KnockbackLevel", data.knockback or 0)
	plr:SetAttribute("JumpLevel", data.jump or 0)
	plr:SetAttribute("RagdollLevel", data.ragdollRes or 0)
	Inventory.loadStored(plr, data.inventory)
	Inventory.loadDiscovered(plr, data.discovered)

	plr:SetAttribute("NextSpin", data.nextSpin or 0)
	plr:SetAttribute("Has67", data.has67 == true)
	local boostKeys = {
		BoostSpeed = "boostSpeed", BoostMoney = "boostMoney", BoostHealth = "boostHealth",
		BoostRagdoll = "boostRagdoll", BoostJump = "boostJump", BoostKnockback = "boostKnockback",
	}
	for attr, key in pairs(boostKeys) do
		local t = data[key] or 0
		if t > os.time() then plr:SetAttribute(attr, t) end
	end
	plr:SetAttribute("DataLoaded", true)

	-- Apply speed to the current character (future respawns are handled by ShopServer)
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 16 + 2 * (data.speed or 0)
		hum.UseJumpPower = true
		hum.JumpPower = 50 + 5 * (data.jump or 0)
		local maxHp = 100 + 25 * (data.health or 0)
		hum.MaxHealth = maxHp
		hum.Health = maxHp
	end

	lastStored[plr] = data.stored or {}
	loaded[plr] = true

	-- Put stored brainrots back once the player has a base
	local waited = 0
	while plr.Parent == Players and not plr:GetAttribute("BaseIndex") and waited < 10 do
		task.wait(0.2)
		waited += 0.2
	end
	if plr.Parent ~= Players then return end
	if plr:GetAttribute("BaseIndex") then
		local fn = ServerStorage:WaitForChild("RestoreStoredItems", 10)
		if fn then
			local okRestore, result = pcall(function()
				return fn:Invoke(plr, lastStored[plr])
			end)
			if okRestore and result then restored[plr] = true end
		end
	end
end

Players.PlayerAdded:Connect(function(plr) task.spawn(load, plr) end)
for _, plr in ipairs(Players:GetPlayers()) do task.spawn(load, plr) end

Players.PlayerRemoving:Connect(function(plr)
	save(plr)
	loaded[plr] = nil
	restored[plr] = nil
	lastStored[plr] = nil
end)

-- Autosave
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, plr in ipairs(Players:GetPlayers()) do
			task.spawn(save, plr)
		end
	end
end)

-- Save everyone when the server shuts down
game:BindToClose(function()
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(save, plr)
	end
	task.wait(3)
end)
