local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Inventory = require(SS:WaitForChild("BrainrotInventory"))

local dropCarriedRemote = RS:WaitForChild("DropBrainrot")
local dropInvRemote = RS:WaitForChild("DropFromInventory")
local placeRemote = RS:WaitForChild("PlaceBrainrot")
local updateRemote = RS:WaitForChild("InventoryUpdate")

local RED = Color3.fromRGB(255, 130, 130)
local GREEN = Color3.fromRGB(140, 255, 160)
local WHITE = Color3.new(1, 1, 1)

-- Dying makes you drop what you're carrying (your inventory is safe)
local function hookCharacter(plr, char)
	Inventory.resetCarried(plr)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		hum.Died:Connect(function()
			Inventory.dropAllCarried(plr, char)
		end)
	end
end

local function hookPlayer(plr)
	plr.CharacterAdded:Connect(function(char) hookCharacter(plr, char) end)
	if plr.Character then task.spawn(hookCharacter, plr, plr.Character) end
end
Players.PlayerAdded:Connect(hookPlayer)
for _, plr in ipairs(Players:GetPlayers()) do hookPlayer(plr) end

-- Main loop: auto-deposit in the safe zone, keep the HUD in sync, push inventory to clients
local sentVersion = {}
local sentDisc = {}
local indexRemote = RS:WaitForChild("IndexUpdate")
task.spawn(function()
	while true do
		task.wait(0.25)
		local gameFolder = workspace:FindFirstChild("Game")
		local zone = gameFolder and gameFolder:FindFirstChild("SafeZone")
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")

			-- Reaching the safe zone moves what you carry into your inventory
			if zone and root and Inventory.carryCount(plr) > 0 then
				local rel = zone.CFrame:PointToObjectSpace(root.Position)
				local h = zone.Size / 2
				if math.abs(rel.X) < h.X and math.abs(rel.Z) < h.Z and math.abs(rel.Y) < 40 then
					local n = Inventory.depositCarried(plr)
					if n > 0 then
						Inventory.notify(plr, "Added " .. n .. (n == 1 and " brainrot" or " brainrots") .. " to your inventory", GREEN)
					end
				end
			end

			-- Money HUD shows what you're carrying
			local list = Inventory.carriedList(plr)
			local total = 0
			for _, d in ipairs(list) do total += d.value end
			plr:SetAttribute("CarryValue", total)
			local n = #list
			plr:SetAttribute("CarryName", n == 0 and "" or (n .. "/" .. Inventory.CARRY_MAX .. (n == 1 and " brainrot" or " brainrots")))

			-- Send newly discovered brainrots (for the Index)
			local dv = Inventory.discoveredVersion(plr)
			if sentDisc[plr] ~= dv then
				sentDisc[plr] = dv
				indexRemote:FireClient(plr, Inventory.discoveredList(plr))
			end

			-- Send inventory changes to the player's screen
			local v = Inventory.version(plr)
			if sentVersion[plr] ~= v then
				sentVersion[plr] = v
				updateRemote:FireClient(plr, Inventory.storedList(plr))
			end
		end
	end
end)

-- Drop one brainrot you're carrying (G key / small Drop button)
local lastDrop = {}
dropCarriedRemote.OnServerEvent:Connect(function(plr)
	if lastDrop[plr] and os.clock() - lastDrop[plr] < 0.4 then return end
	lastDrop[plr] = os.clock()
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	local data = Inventory.dropOneCarried(plr)
	if not data then
		Inventory.notify(plr, "You're not carrying anything", RED)
		return
	end
	local pos = Inventory.groundInFront(char, 5, 0)
	if pos then Inventory.spawnPickup(pos, data, plr) end
	Inventory.notify(plr, "Dropped " .. data.name, WHITE)
end)

-- Drop brainrots from your inventory (one, or up to 20 at a time)
local lastInvDrop = {}
dropInvRemote.OnServerEvent:Connect(function(plr, name, all)
	if typeof(name) ~= "string" then return end
	if name == "67 Brainrot" then
		Inventory.notify(plr, "The 67 Brainrot is permanent - it can't be dropped!", RED)
		return
	end
	if lastInvDrop[plr] and os.clock() - lastInvDrop[plr] < 0.25 then return end
	lastInvDrop[plr] = os.clock()
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	local amount = (all == true) and 20 or 1
	local dropped = 0
	for i = 1, amount do
		local data = Inventory.removeStored(plr, name)
		if not data then break end
		local pos = Inventory.groundInFront(char, 5 + (i % 4), ((i % 5) - 2) * 2)
		if pos then
			Inventory.spawnPickup(pos, data, plr)
			dropped += 1
		else
			Inventory.addStored(plr, data)
			break
		end
	end
	if dropped > 0 then
		Inventory.notify(plr, "Dropped " .. dropped .. " x " .. name, WHITE)
	end
end)

-- Place a brainrot from your inventory onto a pedestal in your base
placeRemote.OnServerInvoke = function(plr, name, baseIndex, slotNumber)
	if typeof(name) ~= "string" or typeof(baseIndex) ~= "number" or typeof(slotNumber) ~= "number" then
		return false, "Invalid request"
	end
	local fn = SS:FindFirstChild("PlaceFromInventory")
	if not fn then return false, "Not ready yet" end
	return fn:Invoke(plr, name, baseIndex, slotNumber)
end
