local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local function isRainbow(data)
	return string.sub(data.name, 1, 8) == "Rainbow " or data.name == "67 Brainrot"
end

local Inventory = {}
Inventory.CARRY_MAX = 3          -- how many you can carry out of the danger zone at once

local carried = setmetatable({}, {__mode = "k"})   -- plr -> list of data (at risk)
local stored = setmetatable({}, {__mode = "k"})    -- plr -> {name -> {data, count}} (safe, unlimited)
local versions = setmetatable({}, {__mode = "k"})

local function bump(plr)
	versions[plr] = (versions[plr] or 0) + 1
end

function Inventory.version(plr)
	return versions[plr] or 0
end

function Inventory.notify(plr, text, color)
	local remote = ReplicatedStorage:FindFirstChild("Notify")
	if remote and plr and plr.Parent then remote:FireClient(plr, text, color) end
end

-- ===== Carried (visible above your head, lost if you die or get ragdolled) =====
function Inventory.carriedList(plr)
	return carried[plr] or {}
end

function Inventory.carryCount(plr)
	return #(carried[plr] or {})
end

function Inventory.carryFull(plr)
	return Inventory.carryCount(plr) >= Inventory.CARRY_MAX
end

local function refreshVisual(plr)
	local char = plr.Character
	if not char then return end
	local old = char:FindFirstChild("CarriedStack")
	if old then old:Destroy() end
	local list = carried[plr]
	if not list or #list == 0 then return end
	local head = char:FindFirstChild("Head")
	if not head then return end

	local folder = Instance.new("Folder")
	folder.Name = "CarriedStack"
	for i, data in ipairs(list) do
		local p = Instance.new("Part")
		p.Name = "Carried_" .. data.name
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(2.4, 2.4, 2.4)
		p.Color = data.color
		p.Material = data.material
		if isRainbow(data) then CollectionService:AddTag(p, "RainbowBrainrot") end
		p.CanCollide = false
		p.Massless = true
		p.CFrame = head.CFrame * CFrame.new(0, 1.8 + (i - 1) * 2.5, 0)
		p.Parent = folder
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = p
		weld.Parent = p
	end
	folder.Parent = char
end

function Inventory.addCarried(plr, data)
	if Inventory.carryFull(plr) then return false end
	carried[plr] = carried[plr] or {}
	table.insert(carried[plr], data)
	refreshVisual(plr)
	return true
end

function Inventory.takeAllCarried(plr)
	local list = carried[plr] or {}
	carried[plr] = {}
	refreshVisual(plr)
	return list
end

function Inventory.dropOneCarried(plr)
	local list = carried[plr]
	if not list or #list == 0 then return nil end
	local data = table.remove(list)
	refreshVisual(plr)
	return data
end

function Inventory.resetCarried(plr)
	carried[plr] = {}
end

-- ===== Inventory (safe: kept through death, unlimited) =====
function Inventory.addStored(plr, data, amount)
	amount = amount or 1
	Inventory.markDiscovered(plr, data.name)
	stored[plr] = stored[plr] or {}
	local e = stored[plr][data.name]
	if e then
		e.count += amount
	else
		stored[plr][data.name] = {data = data, count = amount}
	end
	bump(plr)
end

function Inventory.removeStored(plr, name)
	local s = stored[plr]
	local e = s and s[name]
	if not e or e.count <= 0 then return nil end
	e.count -= 1
	local data = e.data
	if e.count <= 0 then s[name] = nil end
	bump(plr)
	return data
end

function Inventory.storedList(plr)
	local out = {}
	for _, e in pairs(stored[plr] or {}) do
		table.insert(out, {name = e.data.name, value = e.data.value, color = e.data.color, count = e.count})
	end
	table.sort(out, function(a, b)
		if a.value ~= b.value then return a.value > b.value end
		return a.name < b.name
	end)
	return out
end

function Inventory.serializeStored(plr)
	local out = {}
	for _, e in pairs(stored[plr] or {}) do
		local c = e.data.color
		table.insert(out, {
			name = e.data.name, value = e.data.value,
			r = c.R, g = c.G, b = c.B,
			mat = e.data.material.Name, count = e.count,
		})
	end
	return out
end

function Inventory.loadStored(plr, list)
	stored[plr] = {}
	for _, it in ipairs(list or {}) do
		if typeof(it) == "table" and it.name and it.count and it.count > 0 then
			Inventory.addStored(plr, {
				name = it.name,
				value = it.value or 1,
				color = Color3.new(it.r or 0.8, it.g or 0.8, it.b or 0.8),
				material = Enum.Material[it.mat or "SmoothPlastic"] or Enum.Material.SmoothPlastic,
			}, it.count)
		end
	end
	bump(plr)
end

-- Moves everything you're carrying into your inventory
function Inventory.depositCarried(plr)
	local list = Inventory.takeAllCarried(plr)
	local total = 0
	for _, data in ipairs(list) do
		Inventory.addStored(plr, data)
		total += data.value
	end
	return #list, total
end

-- ===== Ground pickups =====
function Inventory.groundAt(char, worldPos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	local hit = workspace:Raycast(worldPos + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), params)
	return hit and (hit.Position + Vector3.new(0, 2, 0)) or (worldPos - Vector3.new(0, 1, 0))
end

function Inventory.groundInFront(char, distance, sideways)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local origin = root.Position + root.CFrame.LookVector * distance + root.CFrame.RightVector * (sideways or 0)
	return Inventory.groundAt(char, origin)
end

-- A brainrot lying on the ground that anyone can pick up (vanishes after 40 seconds)
function Inventory.spawnPickup(position, data, dropper)
	local part = Instance.new("Part")
	part.Name = "Dropped_" .. data.name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2.6, 2.6, 2.6)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Color = data.color
	part.Material = data.material
	if isRainbow(data) then CollectionService:AddTag(part, "RainbowBrainrot") end
	part.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 70
	gui.AlwaysOnTop = true
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = data.name .. "\n$" .. data.value
	label.TextColor3 = Inventory.textColor(data.name)
	if isRainbow(data) then CollectionService:AddTag(label, "RainbowText") end
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local born = os.clock()
	local taken = false
	part.Touched:Connect(function(hit)
		if taken then return end
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if not plr then return end
		if plr == dropper and os.clock() - born < 2 then return end
		local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return end
		if Inventory.carryFull(plr) then return end
		taken = true
		if Inventory.addCarried(plr, data) then
			part:Destroy()
		else
			taken = false
		end
	end)
	Debris:AddItem(part, 40)
	return part
end

-- Drops everything you're carrying around you (used when you die or get ragdolled)
function Inventory.dropAllCarried(plr, char)
	char = char or plr.Character
	local list = Inventory.takeAllCarried(plr)
	if #list == 0 then return 0 end
	local root = char and char:FindFirstChild("HumanoidRootPart")
	for i, data in ipairs(list) do
		local pos
		if root then
			local angle = (i / #list) * math.pi * 2 + math.random()
			pos = Inventory.groundAt(char, root.Position + Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4))
		end
		Inventory.spawnPickup(pos or Vector3.new(0, 5, 0), data, plr)
	end
	Inventory.notify(plr, "You dropped what you were carrying!", Color3.fromRGB(255, 130, 130))
	return #list
end

-- Text colour that matches a brainrot's variant (Gold, Diamond, Emerald, Rainbow)
local TEXT_COLORS = {
	Gold = Color3.fromRGB(255, 215, 60),
	Diamond = Color3.fromRGB(150, 235, 255),
	Emerald = Color3.fromRGB(80, 255, 140),
	Rainbow = Color3.fromRGB(255, 120, 230),
}
function Inventory.textColor(name)
	if name == "67 Brainrot" then return Color3.fromRGB(255, 120, 230) end
	local prefix = string.match(name, "^(%a+) ")
	return TEXT_COLORS[prefix] or Color3.new(1, 1, 1)
end

-- ===== Index: which brainrots has this player collected? =====
local discovered = setmetatable({}, {__mode = "k"})
local discVersions = setmetatable({}, {__mode = "k"})

function Inventory.markDiscovered(plr, name)
	discovered[plr] = discovered[plr] or {}
	if not discovered[plr][name] then
		discovered[plr][name] = true
		discVersions[plr] = (discVersions[plr] or 0) + 1
	end
end

function Inventory.discoveredVersion(plr)
	return discVersions[plr] or 0
end

function Inventory.discoveredList(plr)
	local out = {}
	for name in pairs(discovered[plr] or {}) do
		table.insert(out, name)
	end
	return out
end

-- Adds to what's already known (loading your inventory also counts)
function Inventory.loadDiscovered(plr, list)
	discovered[plr] = discovered[plr] or {}
	for _, n in ipairs(list or {}) do
		if typeof(n) == "string" then discovered[plr][n] = true end
	end
	discVersions[plr] = (discVersions[plr] or 0) + 1
end

return Inventory
