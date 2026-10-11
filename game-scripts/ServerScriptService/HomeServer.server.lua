local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Inventory = require(SS:WaitForChild("BrainrotInventory"))
local remote = RS:WaitForChild("TeleportHome")

local RED = Color3.fromRGB(255, 130, 130)
local GREEN = Color3.fromRGB(140, 255, 160)
local COOLDOWN = 2

local last = {}

remote.OnServerEvent:Connect(function(plr)
	if last[plr] and os.clock() - last[plr] < COOLDOWN then return end
	last[plr] = os.clock()

	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end

	if char:GetAttribute("Ragdolled") then
		Inventory.notify(plr, "You can't teleport while ragdolled!", RED)
		return
	end

	local gameFolder = workspace:FindFirstChild("Game")
	local zone = gameFolder and gameFolder:FindFirstChild("SafeZone")
	local spawn = plr.RespawnLocation
	if not zone then return end
	if not spawn then
		Inventory.notify(plr, "You don't have a base yet", RED)
		return
	end

	-- Must be inside the safe zone
	local rel = zone.CFrame:PointToObjectSpace(root.Position)
	local h = zone.Size / 2
	if not (math.abs(rel.X) < h.X and math.abs(rel.Z) < h.Z and math.abs(rel.Y) < 40) then
		Inventory.notify(plr, "Teleport home only works in the safe zone!", RED)
		return
	end

	char:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	Inventory.notify(plr, "Welcome home!", GREEN)
end)
