local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local ShopConfig = require(RS:WaitForChild("ShopConfig"))
local remote = RS:WaitForChild("BuyUpgrade")

local BASE_SPEED = 16
local BASE_HEALTH = 100

local function active(plr, name)
	return (plr:GetAttribute("Boost" .. name) or 0) > os.time()
end

local function applyStats(plr, refill)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	hum.WalkSpeed = BASE_SPEED + 2 * (plr:GetAttribute("SpeedLevel") or 0) + (active(plr, "Speed") and 8 or 0)
	hum.UseJumpPower = true
	hum.JumpPower = 50 + 5 * (plr:GetAttribute("JumpLevel") or 0) + (active(plr, "Jump") and 25 or 0)

	local newMax = BASE_HEALTH + 25 * (plr:GetAttribute("HealthLevel") or 0) + (active(plr, "Health") and 50 or 0)
	local oldMax = hum.MaxHealth
	hum.MaxHealth = newMax
	if refill then
		hum.Health = newMax
	elseif newMax > oldMax then
		hum.Health = math.min(newMax, hum.Health + (newMax - oldMax))
	end
end

local function setup(plr)
	for _, item in ipairs(ShopConfig.Items) do
		if plr:GetAttribute(item.attr) == nil then plr:SetAttribute(item.attr, 0) end
	end
	plr.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid")
		applyStats(plr, true)
	end)
	for _, attr in ipairs({"BoostSpeed", "BoostJump", "BoostHealth"}) do
		plr:GetAttributeChangedSignal(attr):Connect(function()
			applyStats(plr, false)
		end)
	end
	applyStats(plr, false)
end
Players.PlayerAdded:Connect(setup)
for _, plr in ipairs(Players:GetPlayers()) do setup(plr) end

remote.OnServerInvoke = function(plr, id)
	if typeof(id) ~= "string" then return false, "Invalid item" end
	local item
	for _, it in ipairs(ShopConfig.Items) do
		if it.id == id then item = it break end
	end
	if not item then return false, "Invalid item" end

	local level = plr:GetAttribute(item.attr) or 0
	if level >= item.maxLevel then return false, "Max level" end

	local cash = plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Cash")
	if not cash then return false, "Try again in a moment" end

	local cost = ShopConfig.cost(item, level)
	if cash.Value < cost then return false, "Not enough cash" end

	cash.Value -= cost
	plr:SetAttribute(item.attr, level + 1)
	applyStats(plr, false)
	return true, item.title .. " bought!"
end
