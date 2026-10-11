local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local WheelConfig = require(RS:WaitForChild("WheelConfig"))
local Inventory = require(SS:WaitForChild("BrainrotInventory"))
local spinRemote = RS:WaitForChild("SpinWheel")

local rewards = WheelConfig.Rewards

local function pick(has67)
	local total = 0
	for _, r in ipairs(rewards) do
		if not (r.special and has67) then total += r.weight end
	end
	local roll = math.random() * total
	for i, r in ipairs(rewards) do
		if not (r.special and has67) then
			roll -= r.weight
			if roll <= 0 then return i, r end
		end
	end
	return 1, rewards[1]
end

spinRemote.OnServerInvoke = function(plr)
	if not plr:GetAttribute("DataLoaded") then
		return false, "Still loading your data, try again in a moment"
	end
	local now = os.time()
	if now < (plr:GetAttribute("NextSpin") or 0) then
		return false, "You already spun today!"
	end

	local index, reward = pick(plr:GetAttribute("Has67") == true)
	plr:SetAttribute("NextSpin", now + WheelConfig.COOLDOWN)

	if reward.special then
		-- Permanent: can't be dropped, kept through death, saved
		Inventory.addStored(plr, {
			name = "67 Brainrot",
			value = 1,
			color = Color3.fromRGB(255, 60, 200),
			material = Enum.Material.Neon,
		})
		plr:SetAttribute("Has67", true)
	else
		local current = plr:GetAttribute(reward.attr) or 0
		plr:SetAttribute(reward.attr, math.max(current, now) + WheelConfig.DURATION)   -- extends if already active
	end
	return true, index
end

-- Clear potions when they run out
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()
		for _, plr in ipairs(Players:GetPlayers()) do
			for _, r in ipairs(rewards) do
				if r.attr then
					local t = plr:GetAttribute(r.attr)
					if t and t <= now then
						plr:SetAttribute(r.attr, nil)
					end
				end
			end
		end
	end
end)
