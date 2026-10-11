local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Inventory = require(ServerStorage:WaitForChild("BrainrotInventory"))

local basesFolder = workspace:WaitForChild("Game"):WaitForChild("Bases")
local MAX_SLOTS = 6
local PAY_INTERVAL = 5

local RED = Color3.fromRGB(255, 130, 130)
local GREEN = Color3.fromRGB(140, 255, 160)

local bases = {}
local releasedItems = {}

local function multiplier(plr)
	local m = 1 + 0.25 * (plr:GetAttribute("CashLevel") or 0)
	if (plr:GetAttribute("BoostMoney") or 0) > os.time() then m *= 2 end
	return m
end

-- The 67 Brainrot is worth as much as the best other brainrot placed in this base right now
local function bestOther(base)
	local best = 0
	for _, slot in ipairs(base.slots) do
		if slot.item and not slot.item.dynamic and slot.item.value > best then
			best = slot.item.value
		end
	end
	return best
end

local function itemValue(base, item)
	if item.dynamic then return math.max(1, bestOther(base)) end
	return item.value
end

local function totals(base)
	local count, sum = 0, 0
	for _, slot in ipairs(base.slots) do
		if slot.item then
			count += 1
			sum += itemValue(base, slot.item)
		end
	end
	return count, sum
end

local function updateSign(base)
	for _, slot in ipairs(base.slots) do
		if slot.item and slot.item.dynamic and slot.item.label then
			slot.item.label.Text = slot.item.name .. "\n$" .. itemValue(base, slot.item) .. "/" .. PAY_INTERVAL .. "s"
		end
	end
	if not base.owner then
		base.label.Text = "BASE " .. base.index .. "\nFREE"
		return
	end
	local count, sum = totals(base)
	local pay = math.floor(sum * multiplier(base.owner))
	base.label.Text = string.format("%s\nStored %d/%d\n$%d per %ds", base.owner.Name, count, MAX_SLOTS, pay, PAY_INTERVAL)
end

local function snapshot(base)
	local list = {}
	for _, slot in ipairs(base.slots) do
		if slot.item then
			local c = slot.item.part.Color
			table.insert(list, {
				name = slot.item.name,
				value = slot.item.value,
				r = c.R, g = c.G, b = c.B,
				mat = slot.item.part.Material.Name,
			})
		end
	end
	return list
end

local function resetSlot(slot, n)
	slot.prompt.ActionText = "Place"
	slot.prompt.ObjectText = "Slot " .. n
end

local function clearSlots(base)
	for n, slot in ipairs(base.slots) do
		if slot.item then
			slot.item.part:Destroy()
			slot.item = nil
		end
		resetSlot(slot, n)
	end
end

-- data = {name, value, color (Color3), material (Enum.Material)}
local function placeItem(base, slot, data)
	local ped = slot.pedestal
	local part = Instance.new("Part")
	part.Name = "Stored_" .. data.name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(3, 3, 3)
	part.Position = ped.Position + Vector3.new(0, ped.Size.Y / 2 + 2.2, 0)
	part.Anchored = true
	part.CanCollide = false
	part.Color = data.color
	part.Material = data.material
	if string.sub(data.name, 1, 8) == "Rainbow " or data.name == "67 Brainrot" then CollectionService:AddTag(part, "RainbowBrainrot") end
	part.Parent = base.model

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Parent = part
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = data.name .. "\n$" .. data.value .. "/" .. PAY_INTERVAL .. "s"
	text.TextColor3 = Inventory.textColor(data.name)
	if string.sub(data.name, 1, 8) == "Rainbow " or data.name == "67 Brainrot" then CollectionService:AddTag(text, "RainbowText") end
	text.TextStrokeTransparency = 0
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.Parent = gui

	slot.item = {name = data.name, value = data.value, part = part, label = text, dynamic = (data.name == "67 Brainrot")}
	slot.prompt.ActionText = "Pick Up"
	slot.prompt.ObjectText = data.name
end

-- Pedestal prompt: occupied = move that brainrot into your inventory.
-- (Empty pedestals: the client opens the inventory picker, then asks the server to place.)
local function onTriggered(base, slot, plr)
	if base.owner ~= plr then
		Inventory.notify(plr, "This isn't your base!", RED)
		return
	end
	if slot.item then
		local it = slot.item
		local data = {name = it.name, value = it.value, color = it.part.Color, material = it.part.Material}
		Inventory.addStored(plr, data)
		it.part:Destroy()
		slot.item = nil
		resetSlot(slot, slot.number)
		updateSign(base)
		Inventory.notify(plr, data.name .. " moved to your inventory", GREEN)
	end
end

for i = 1, 5 do
	local model = basesFolder:WaitForChild("Base" .. i)
	local base = {
		index = i,
		model = model,
		plate = model:WaitForChild("Plate"),
		label = model:WaitForChild("Sign"):WaitForChild("SurfaceGui"):WaitForChild("TextLabel"),
		spawn = model:WaitForChild("BaseSpawn"),
		slots = {},
		owner = nil,
	}
	model:SetAttribute("OwnerUserId", 0)
	for n = 1, MAX_SLOTS do
		local pedestal = model:WaitForChild("Slot" .. n)
		local old = pedestal:FindFirstChild("SlotPrompt")
		if old then old:Destroy() end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SlotPrompt"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = pedestal
		local slot = {pedestal = pedestal, prompt = prompt, item = nil, number = n}
		resetSlot(slot, n)
		prompt.Triggered:Connect(function(plr)
			onTriggered(base, slot, plr)
		end)
		base.slots[n] = slot
	end
	bases[i] = base
end

local function assign(plr)
	for _, base in ipairs(bases) do
		if not base.owner then
			base.owner = plr
			base.model:SetAttribute("OwnerUserId", plr.UserId)
			plr:SetAttribute("BaseIndex", base.index)
			plr.RespawnLocation = base.spawn
			updateSign(base)
			task.spawn(function()
				local char = plr.Character or plr.CharacterAdded:Wait()
				char:WaitForChild("HumanoidRootPart")
				char:PivotTo(base.spawn.CFrame + Vector3.new(0, 4, 0))
			end)
			return
		end
	end
end

local function release(plr)
	for _, base in ipairs(bases) do
		if base.owner == plr then
			releasedItems[plr] = snapshot(base)
			task.delay(60, function() releasedItems[plr] = nil end)
			clearSlots(base)
			base.owner = nil
			base.model:SetAttribute("OwnerUserId", 0)
			updateSign(base)
		end
	end
end

Players.PlayerAdded:Connect(assign)
Players.PlayerRemoving:Connect(release)
for _, plr in ipairs(Players:GetPlayers()) do assign(plr) end

-- Passive income for stored brainrots
task.spawn(function()
	while true do
		task.wait(PAY_INTERVAL)
		for _, base in ipairs(bases) do
			local plr = base.owner
			if plr then
				local _, sum = totals(base)
				local cash = plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Cash")
				if cash and sum > 0 then
					cash.Value += math.floor(sum * multiplier(plr))
				end
				updateSign(base)
			end
		end
	end
end)

-- Saving hooks (used by SaveServer)
local getFn = Instance.new("BindableFunction")
getFn.Name = "GetStoredItems"
getFn.OnInvoke = function(plr)
	for _, b in ipairs(bases) do
		if b.owner == plr then return snapshot(b) end
	end
	return releasedItems[plr]
end
getFn.Parent = ServerStorage

local restoreFn = Instance.new("BindableFunction")
restoreFn.Name = "RestoreStoredItems"
restoreFn.OnInvoke = function(plr, items)
	for _, b in ipairs(bases) do
		if b.owner == plr then
			for _, it in ipairs(items or {}) do
				local free
				for _, slot in ipairs(b.slots) do
					if not slot.item then free = slot break end
				end
				if not free then break end
				Inventory.markDiscovered(plr, it.name)
				placeItem(b, free, {
					name = it.name,
					value = it.value,
					color = Color3.new(it.r, it.g, it.b),
					material = Enum.Material[it.mat] or Enum.Material.SmoothPlastic,
				})
			end
			updateSign(b)
			return true
		end
	end
	return false
end
restoreFn.Parent = ServerStorage

-- Place a brainrot from the inventory onto a pedestal (called by InventoryServer)
local placeFn = Instance.new("BindableFunction")
placeFn.Name = "PlaceFromInventory"
placeFn.OnInvoke = function(plr, name, baseIndex, slotNumber)
	local b = bases[baseIndex]
	if not b or b.owner ~= plr then return false, "This isn't your base!" end
	local slot = b.slots[slotNumber]
	if not slot then return false, "Invalid slot" end
	if slot.item then return false, "That pedestal is taken" end
	local data = Inventory.removeStored(plr, name)
	if not data then return false, "You don't have that brainrot" end
	placeItem(b, slot, data)
	updateSign(b)
	return true, "Placed " .. data.name
end
placeFn.Parent = ServerStorage
