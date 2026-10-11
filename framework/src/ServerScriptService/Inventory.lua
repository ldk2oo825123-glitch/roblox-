--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Config = require(RS.Config)
local Logic = require(RS.InventoryLogic).new(Config, true)
local Data = require(RS.BrainrotData)
local Remotes = require(RS.Remotes)
local WorldItems = require(script.Parent.WorldItems)
local Inventory = {}
local zero, one = Config.Math.Zero, Config.Math.One
local entries = {}
local bases, update
local started = false
local ground = Instance.new("Folder")
ground.Name = "GroundBrainrots"; ground.Parent = workspace
local function valid(player) return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players end
local function root(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local function alive(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return valid(player) and humanoid and humanoid.Health > zero and root(player)
end
function Inventory.SetBases(module) bases = module end
-- Saving reads the live authoritative state before Remove. setState/Init detach
-- and validate loaded tables; failed loads must never call Init with defaults.
function Inventory.getState(player) return entries[player] and entries[player].state end
function Inventory.snapshot(player)
	local state = Inventory.getState(player)
	if not state then return nil end
	local detached = Logic.copyState(state)
	local found, total = Logic.indexProgress(detached)
	return { carried = detached.carried, inventory = Logic.groupInventory(detached),
		indexFound = detached.indexFound, index = { found = found, total = total } }
end
function Inventory.Publish(player)
	if entries[player] and valid(player) then update:FireClient(player, Inventory.snapshot(player)) end
	if bases then bases.Refresh(player) end
end
function Inventory.setState(player, state)
	assert(valid(player) and entries[player], "Inventory player must be initialized")
	assert(Logic.validateState(state), "Invalid saved inventory state")
	entries[player].state = Logic.copyState(state); Inventory.Publish(player)
end
function Inventory.newItem(tier, variant)
	return { id = HttpService:GenerateGUID(false), tier = tier, variant = variant, value = Data.CalculateValue(tier, variant) }
end
function Inventory.addCarried(player, item)
	if not entries[player] or not alive(player) then return nil, "not ready" end
	local added, reason = Logic.addCarried(entries[player].state, item)
	if added then Inventory.Publish(player) end
	return added, reason
end
-- Server-only entry point. Position is re-read here; no client conversion remote.
function Inventory.enterSafeZone(player)
	local position = alive(player)
	local state = Inventory.getState(player)
	if not state or not position or not Logic.inSafeZone(position.Position) or player:GetAttribute("Ragdolled") then return end
	if #state.carried == zero then return end
	local moved = Logic.moveCarriedToInventory(state); Inventory.Publish(player); return moved
end
function Inventory.spawnGround(item, position, owner)
	local part = WorldItems.create(item, position, ground)
	local unlockedAt = os.clock() + Config.Inventory.OwnerRepickupLockSeconds
	local consumed = false
	part.Touched:Connect(function(hit)
		if consumed or not part.Parent then return end
		local model = hit:FindFirstAncestorOfClass("Model")
		local player = model and Players:GetPlayerFromCharacter(model)
		if not player or not entries[player] then return end
		local hrp = alive(player)
		if not hrp or (hrp.Position - part.Position).Magnitude > Config.Inventory.PickupRange then return end
		if player == owner and os.clock() < unlockedAt then return end
		-- addCarried has no yields; concurrent touch events cannot consume twice.
		if Inventory.addCarried(player, item) then consumed = true; part:Destroy() end
	end)
	task.delay(Config.Inventory.GroundItemExpirySeconds, function() if part.Parent then part:Destroy() end end)
	return part
end
local function dropRisk(player, reason)
	local entry = entries[player]; local hrp = root(player)
	if not entry then return end
	local position = hrp and hrp.Position or entry.lastPosition
	-- Last known character position is captured by the server poll before death.
	if not position then return end
	local dropped = Logic.dropCarried(entry.state, reason)
	for _, item in ipairs(dropped) do Inventory.spawnGround(item, position, player) end
	Inventory.Publish(player); return dropped
end
function Inventory.onRagdoll(player) return dropRisk(player, "ragdoll") end
function Inventory.onDeath(player) return dropRisk(player, "death") end
function Inventory.RecordPosition(player)
	local hrp = root(player)
	if entries[player] and hrp then entries[player].lastPosition = hrp.Position end
end
function Inventory.Remove(player)
	local entry = entries[player]
	if entry then
		if entry.characterConnection then entry.characterConnection:Disconnect() end
		if entry.deathConnection then entry.deathConnection:Disconnect() end
	end
	entries[player] = nil
end
local function characterAdded(player, character, entry)
	if entry.deathConnection then entry.deathConnection:Disconnect(); entry.deathConnection = nil end
	local humanoid = character:WaitForChild("Humanoid")
	if entries[player] ~= entry or player.Character ~= character then return end
	Inventory.RecordPosition(player)
	entry.deathConnection = humanoid.Died:Connect(function() Inventory.onDeath(player) end)
end
local function request(player, name, ...)
	local entry = entries[player]
	if not valid(player) or not entry or not alive(player) then return { ok = false, reason = "not ready" } end
	local now = os.clock()
	if now < entry.nextRequest then return { ok = false, reason = "please wait" } end
	entry.nextRequest = now + Config.Inventory.RemoteCooldownSeconds
	local args = { ... }; local count = select("#", ...)
	local expected = name == "PlaceItem" and (one + one) or one
	if count ~= expected then return { ok = false, reason = "invalid arguments" } end
	local itemId, slot
	if name == "PickUpItem" then slot = args[one] else itemId = args[one]; slot = args[one + one] end
	if itemId ~= nil and (type(itemId) ~= "string" or #itemId == zero or #itemId > Config.Inventory.MaxItemIdLength) then return { ok = false, reason = "invalid item id" } end
	if name ~= "PickUpItem" and itemId == nil then return { ok = false, reason = "invalid item id" } end
	local item, reason
	if name == "DropItem" then
		item, reason = Logic.dropFromInventory(entry.state, itemId)
		if item then Inventory.spawnGround(item, root(player).Position + Vector3.new(zero, Config.Inventory.GroundDropHeight, zero), player) end
	else
		local base = bases and bases.getBase(player)
		local pedestal = base and base.pedestals[slot]
		local distance = pedestal and (root(player).Position - pedestal.Position).Magnitude or math.huge
		local allowed; allowed, reason = Logic.canAccessBase(player, base, slot, distance)
		if allowed and not Logic.inSafeZone(root(player).Position) then allowed, reason = false, "outside safe zone" end
		if allowed then
			if name == "PlaceItem" then item, reason = Logic.placeOnPedestal(entry.state, itemId, slot)
			else item, reason = Logic.pickUpFromPedestal(entry.state, slot) end
		end
	end
	if not item then return { ok = false, reason = reason } end
	Inventory.Publish(player); return { ok = true }
end
function Inventory.Start(managedLifecycle)
	if started then return end
	started = true; Remotes.Setup(); update = Remotes.Get("InventoryUpdate")
	for _, name in ipairs({ "DropItem", "PlaceItem", "PickUpItem" }) do
		Remotes.Get(name).OnServerInvoke = function(player, ...) return request(player, name, ...) end
	end
	Remotes.Get("GetInventoryState").OnServerInvoke = function(player, ...)
		if not valid(player) or not entries[player] or select("#", ...) ~= zero then return { ok = false, reason = "not ready" } end
		local entry = entries[player]; local now = os.clock()
		if now < entry.nextSnapshot then return { ok = false, reason = "please wait" } end
		entry.nextSnapshot = now + Config.Inventory.RemoteCooldownSeconds
		return { ok = true, state = Inventory.snapshot(player) }
	end
	if not managedLifecycle then Players.PlayerRemoving:Connect(Inventory.Remove) end
end
function Inventory.Init(player, saved)
	assert(valid(player), "Invalid inventory player")
	local state = saved or Logic.newState()
	assert(Logic.validateState(state), "Invalid saved inventory state; never default a failed load")
	Inventory.Start(); Inventory.Remove(player)
	local entry = { state = Logic.copyState(state), nextRequest = zero, nextSnapshot = zero }
	entries[player] = entry
	entry.characterConnection = player.CharacterAdded:Connect(function(character) characterAdded(player, character, entry) end)
	if player.Character then task.spawn(characterAdded, player, player.Character, entry) end
	Inventory.Publish(player)
end
return Inventory
