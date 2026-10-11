local Players = game:GetService("Players")

local gameFolder = workspace:WaitForChild("Game")
local safe = gameFolder:WaitForChild("SafeZone")
local danger = gameFolder:WaitForChild("DangerZone")
local container = gameFolder:WaitForChild("Brainrots")
local trenchesFolder = gameFolder:WaitForChild("Trenches")

-- Rarity tiers: the farther from the safe zone, the rarer and more valuable
local TIERS = {
	{name = "Noodle Goblin",  value = 1,  color = Color3.fromRGB(200, 200, 200), count = 10, neon = false},
	{name = "Sigma Frog",     value = 3,  color = Color3.fromRGB(80, 200, 100),  count = 8, neon = false},
	{name = "Turbo Toast",    value = 8,  color = Color3.fromRGB(70, 140, 255),  count = 6, neon = false},
	{name = "Cosmic Banana",  value = 20, color = Color3.fromRGB(180, 80, 255),  count = 4, neon = true},
	{name = "Golden Gigarot", value = 60, color = Color3.fromRGB(255, 205, 40),  count = 2, neon = true},
}
local RESPAWN_TIME = 8

local dangerMinX = danger.Position.X - danger.Size.X / 2
local tierWidth = danger.Size.X / #TIERS
local halfZ = danger.Size.Z / 2 - 6
local groundY = danger.Position.Y + danger.Size.Y / 2

local function setupPlayer(plr)
	if plr:FindFirstChild("leaderstats") then return end
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = ls
	ls.Parent = plr
	plr:SetAttribute("CarryValue", 0)
	plr:SetAttribute("CarryName", "")
	plr.CharacterAdded:Connect(function()
		plr:SetAttribute("CarryValue", 0)
		plr:SetAttribute("CarryName", "")
	end)
end
Players.PlayerAdded:Connect(setupPlayer)
for _, plr in ipairs(Players:GetPlayers()) do setupPlayer(plr) end

local Inventory = require(game:GetService("ServerStorage"):WaitForChild("BrainrotInventory"))

-- Picking up a brainrot now puts it in the player's inventory (backpack)
local function carry(plr, data)
	return Inventory.addCarried(plr, data)
end

local CollectionService = game:GetService("CollectionService")

-- Variants: the rarer the variant, the more it's worth
local VARIANTS = {
	{name = "",        bonus = 0,    weight = 80,  textColor = Color3.new(1, 1, 1)},
	{name = "Gold",    bonus = 0.10, weight = 10,  color = Color3.fromRGB(255, 200, 40),  material = Enum.Material.Metal, textColor = Color3.fromRGB(255, 215, 60)},
	{name = "Diamond", bonus = 0.20, weight = 5,   color = Color3.fromRGB(150, 235, 255), material = Enum.Material.Ice,   textColor = Color3.fromRGB(150, 235, 255)},
	{name = "Emerald", bonus = 0.30, weight = 3,   color = Color3.fromRGB(30, 200, 90),   material = Enum.Material.Glass, textColor = Color3.fromRGB(80, 255, 140)},
	{name = "Rainbow", bonus = 0.40, weight = 1.5, color = Color3.fromRGB(255, 60, 200),  material = Enum.Material.Neon,  textColor = Color3.fromRGB(255, 120, 230), rainbow = true},
}
local variantTotal = 0
for _, v in ipairs(VARIANTS) do variantTotal += v.weight end

local function rollVariant()
	local r = math.random() * variantTotal
	for _, v in ipairs(VARIANTS) do
		r -= v.weight
		if r <= 0 then return v end
	end
	return VARIANTS[1]
end

local function makeData(tier, variant)
	local name = (variant.name == "") and tier.name or (variant.name .. " " .. tier.name)
	local value = math.floor(tier.value * (1 + variant.bonus) * 10 + 0.5) / 10
	return {
		name = name,
		value = value,
		color = variant.color or tier.color,
		material = variant.material or (tier.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic),
		variant = variant.name,
	}
end

local function spawnBrainrot(tierIndex)
	local tier = TIERS[tierIndex]
	local variant = rollVariant()
	local data = makeData(tier, variant)
	local minX = dangerMinX + (tierIndex - 1) * tierWidth + 5
	local maxX = dangerMinX + tierIndex * tierWidth - 5
	local x, z
	for _ = 1, 30 do
		x = math.random(math.floor(minX), math.floor(maxX))
		z = danger.Position.Z + math.random(-math.floor(halfZ), math.floor(halfZ))
		local clear = true
		for _, t in ipairs(trenchesFolder:GetChildren()) do
			local zone = t:FindFirstChild("TrenchZone")
			if zone and math.abs(x - zone.Position.X) < zone.Size.X / 2 + 4 and math.abs(z - zone.Position.Z) < zone.Size.Z / 2 + 4 then
				clear = false
				break
			end
		end
		if clear then break end
	end

	local body = Instance.new("Part")
	body.Name = data.name
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(3, 3, 3)
	body.Position = Vector3.new(x, groundY + 2, z)
	body.Anchored = true
	body.CanCollide = false
	body.Color = data.color
	body.Material = data.material
	if variant.rainbow then CollectionService:AddTag(body, "RainbowBrainrot") end
	body.Parent = container

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 44)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = data.name .. "\n$" .. data.value
	label.TextColor3 = variant.textColor
	if variant.rainbow then CollectionService:AddTag(label, "RainbowText") end
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local taken = false
	body.Touched:Connect(function(hit)
		if taken then return end
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if not plr then return end
		local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return end
		if Inventory.carryFull(plr) then return end -- carrying the maximum
		taken = true
		if carry(plr, data) then
			body:Destroy()
			task.delay(RESPAWN_TIME, spawnBrainrot, tierIndex)
		else
			taken = false
		end
	end)
end

for i, tier in ipairs(TIERS) do
	for _ = 1, tier.count do
		spawnBrainrot(i)
	end
end

-- Cashing in now happens by storing brainrots in your base (see BaseServer)
