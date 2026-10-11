--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(RS.Config)
local Logic = require(RS.BrainrotLogic).new(Config)
local WorldItems = require(script.Parent.WorldItems)
local Brainrots = {}
local rng = Random.new()
local pits = {}
local nodes = {}
local folder, inventory
local started = false
local zero, one = Config.Math.Zero, Config.Math.One
-- MapBuilder must call this BEFORE Start and whenever pit geometry changes.
-- Rects: array of world-space {MinX,MaxX,MinZ,MaxZ}; bounds include pit rims.
-- Existing spawns over updated pits are relocated rather than left in holes.
function Brainrots.SetPitRects(rects)
	assert(type(rects) == "table", "Pit rects must be an array")
	local copy = {}
	for _, r in ipairs(rects) do
		for _, key in ipairs({ "MinX", "MaxX", "MinZ", "MaxZ" }) do assert(type(r[key]) == "number" and r[key] == r[key] and math.abs(r[key]) < math.huge, "Invalid pit rect") end
		assert(r.MinX <= r.MaxX and r.MinZ <= r.MaxZ, "Inverted pit rect")
		table.insert(copy, { MinX = r.MinX, MaxX = r.MaxX, MinZ = r.MinZ, MaxZ = r.MaxZ })
	end
	pits = copy
	for _, node in ipairs(nodes) do
		if node.part and Logic.overPit(node.part.Position.X, node.part.Position.Z, pits) then
			node.part:Destroy(); node.part = nil; node.respawn()
		end
	end
end
function Brainrots.Start(inventoryModule)
	if started then return end
	started = true; inventory = inventoryModule
	folder = Instance.new("Folder"); folder.Name = "DangerBrainrots"; folder.Parent = workspace
	for tier = one, #Config.Brainrots.Tiers do
		for _ = one, Config.Brainrots.SpawnsPerTier do
			local node = {}; table.insert(nodes, node)
			node.respawn = function()
				local point = Logic.spawnPoint(tier, pits, function(low, high) return rng:NextNumber(low, high) end)
				if not point then task.delay(Config.Brainrots.RespawnSeconds, node.respawn); return end
				local item = inventory.newItem(Config.Brainrots.Tiers[tier].Name, Logic.rollVariant(rng:NextNumber()))
				local p = WorldItems.create(item, Vector3.new(point.X, point.Y, point.Z), folder); node.part = p
				local consumed = false
				p.Touched:Connect(function(hit)
					if consumed or node.part ~= p or not p.Parent then return end
					local model = hit:FindFirstAncestorOfClass("Model")
					local player = model and Players:GetPlayerFromCharacter(model)
					local hrp = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if not hrp or (hrp.Position - p.Position).Magnitude > Config.Inventory.PickupRange then return end
					if inventory.addCarried(player, item) then
						consumed = true; p:Destroy(); node.part = nil
						task.delay(Config.Brainrots.RespawnSeconds, node.respawn)
					end
				end)
			end
			node.respawn()
		end
	end
	local elapsed = zero
	RunService.Heartbeat:Connect(function(dt)
		elapsed = elapsed + dt; if elapsed < Config.Brainrots.SafeZonePollSeconds then return end; elapsed = zero
		for _, player in ipairs(Players:GetPlayers()) do inventory.RecordPosition(player); inventory.enterSafeZone(player) end
	end)
end
return Brainrots
