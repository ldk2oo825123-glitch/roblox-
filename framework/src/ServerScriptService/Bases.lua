--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Config)
local Logic = require(RS.InventoryLogic).new(Config)
local WheelLogic = require(RS.WheelLogic).new(Config)
local Wheel = require(script.Parent.Wheel)
local WorldItems = require(script.Parent.WorldItems)
local Bases = {}
local zero, one = Config.Math.Zero, Config.Math.One
local plots, assignments = {}, {}
local inventory, cashHandler
local started = false
local function part(name, size, position, parent, colour)
	local p = Instance.new("Part"); p.Name = name; p.Anchored = true
	p.Size = size; p.Position = position; p.Color = colour; p.Parent = parent; return p
end
-- Shop/Saving installs fn(player, amount) to credit authoritative profile cash.
-- Without a handler no cash is credited: no separate competing cash store.
function Bases.SetCashHandler(fn) assert(type(fn) == "function", "Cash handler must be a function"); cashHandler = fn end
function Bases.getBase(player) return assignments[player] end
local function income(player, state)
	local values = {}
	for slot, item in pairs(state.pedestals) do values[slot] = item.value end
	local ordinary = Logic.incomePerTick(state, one)
	local total = Wheel.getIncome(player, values, ordinary)
	return math.floor(total * Config.Math.ValueRoundingScale + one / (one + one)) / Config.Math.ValueRoundingScale
end
-- Minimal 67 hook: overlays the first empty ordinary pedestal, without reserving
-- or storing an Item. If all six are occupied, the slot-one label also shows 67.
-- All six ordinary slots remain usable: placement moves the overlay to the next
-- empty slot, or shares slot one. 67 itself never has a Pick Up action.
function Bases.Show67(player, owns67)
	local base = assignments[player]; local state = inventory.getState(player)
	if not base or not state then return end
	if base.display67Slot then
		local previous = state.pedestals[base.display67Slot]
		base.labels[base.display67Slot].Text = previous and (previous.tier .. " / " .. previous.variant .. " $" .. tostring(previous.value)) or "Empty"
	end
	base.display67Slot = nil
	if not owns67 then return end
	local slot = one
	for i = one, Config.Bases.PedestalCount do if not state.pedestals[i] then slot = i; break end end
	base.display67Slot = slot
	local values = {}; for i, item in pairs(state.pedestals) do values[i] = item.value end
	local value = WheelLogic.brainrot67Value(values)
	base.labels[slot].Text = base.labels[slot].Text .. "\n67 Brainrot $" .. tostring(value)
end
function Bases.Refresh(player)
	local base = assignments[player]; local state = inventory.getState(player)
	if not base or not state then return end
	for slot = one, Config.Bases.PedestalCount do
		local item = state.pedestals[slot]; local label = base.labels[slot]
		label.Text = item and (item.tier .. " / " .. item.variant .. " $" .. tostring(item.value)) or "Empty"
		local variant
		for _, v in ipairs(Config.Brainrots.Variants) do if item and v.Name == item.variant then variant = v end end
		label.TextColor3 = variant and Config.Brainrots.VariantColours[variant.Colour] or Config.Inventory.UI.TextColour
		label:SetAttribute("RainbowLabel", variant and variant.ColourCycling or false)
		base.prompts[slot].ActionText = item and "Pick Up" or "Place"
	end
	Bases.Show67(player, player:GetAttribute("OwnsBrainrot67") == true)
	base.sign.Text = player.DisplayName .. "\n$" .. string.format("%." .. tostring(Config.Bases.IncomeDisplayDecimals) .. "f", income(player, state)) .. " / " .. tostring(Config.Bases.IncomeIntervalSeconds) .. "s"
end
function Bases.Assign(player)
	if assignments[player] then return assignments[player] end
	for _, base in ipairs(plots) do
		if not base.owner then
			base.owner = player; assignments[player] = base
			for _, prompt in ipairs(base.prompts) do prompt:SetAttribute("OwnerUserId", player.UserId) end
			base.ownsConnection = player:GetAttributeChangedSignal("OwnsBrainrot67"):Connect(function() Bases.Refresh(player) end)
			base.characterConnection = player.CharacterAdded:Connect(function(character)
				local hrp = character:WaitForChild("HumanoidRootPart")
				if assignments[player] == base and player.Character == character then hrp.CFrame = CFrame.new(base.spawnPosition) end
			end)
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.CFrame = CFrame.new(base.spawnPosition) end
			Bases.Refresh(player); return base
		end
	end
	return nil -- Sixth joiner has no base; no waitlist steals first-five ownership.
end
function Bases.Remove(player)
	local base = assignments[player]; if not base then return end
	if base.characterConnection then base.characterConnection:Disconnect() end
	if base.ownsConnection then base.ownsConnection:Disconnect() end
	local state = inventory.getState(player)
	if state then state.pedestals = {} end -- Saving must snapshot before departure cleanup.
	base.owner = nil; base.display67Slot = nil; assignments[player] = nil; base.sign.Text = "FREE"
	for i, prompt in ipairs(base.prompts) do
		prompt:SetAttribute("OwnerUserId", nil); prompt.ActionText = "Place"
		base.labels[i].Text = "Empty"; base.labels[i]:SetAttribute("RainbowLabel", false)
		base.labels[i].TextColor3 = Config.Inventory.UI.TextColour
	end
end
function Bases.Start(inventoryModule)
	if started then return end
	started = true; inventory = inventoryModule; inventory.SetBases(Bases)
	local folder = Instance.new("Folder"); folder.Name = "PlayerBases"; folder.Parent = workspace
	for i = one, Config.Bases.PlotCount do
		local model = Instance.new("Model"); model.Name = "Base" .. tostring(i); model.Parent = folder
		local x = (i - (Config.Bases.PlotCount + one) / (one + one)) * Config.Bases.PlotSpacing
		local position = Vector3.new(x, Config.Bases.PlotY, Config.Bases.PlotZ)
		local floor = part("Plot", Vector3.new(table.unpack(Config.Bases.PlotSize)), position, model, Config.Bases.PlotColour)
		local sign = WorldItems.label(floor, "FREE", "Normal")
		sign.Parent.Size = UDim2.fromOffset(table.unpack(Config.Bases.SignSize))
		sign.Parent.StudsOffset = Vector3.new(zero, Config.Bases.SignHeight, zero)
		local base = { model = model, pedestals = {}, labels = {}, prompts = {}, sign = sign,
			spawnPosition = position + Vector3.new(zero, Config.Bases.SpawnHeight, -Config.Bases.PedestalZ) }
		for slot = one, Config.Bases.PedestalCount do
			local dx = (slot - (Config.Bases.PedestalCount + one) / (one + one)) * Config.Bases.PedestalSpacing
			local p = part("Pedestal" .. tostring(slot), Vector3.new(table.unpack(Config.Bases.PedestalSize)), position + Vector3.new(dx, Config.Bases.PedestalSize[one + one], Config.Bases.PedestalZ), model, Config.Bases.PedestalColour)
			local prompt = Instance.new("ProximityPrompt"); prompt.Name = "BaseItemPrompt"; prompt.ActionText = "Place"; prompt.ObjectText = "Pedestal " .. tostring(slot)
			prompt.KeyboardKeyCode = Enum.KeyCode[Config.Inventory.PedestalKey]; prompt.HoldDuration = zero; prompt.MaxActivationDistance = Config.Bases.InteractionRange
			prompt:SetAttribute("PedestalSlot", slot); prompt.Parent = p
			base.pedestals[slot] = p; base.prompts[slot] = prompt; base.labels[slot] = WorldItems.label(p, "Empty", "Normal")
		end
		table.insert(plots, base)
	end
	-- Main owns player lifecycle ordering; T3 must save before Bases/Inventory.Remove.
	task.spawn(function()
		while true do
			task.wait(Config.Bases.IncomeIntervalSeconds)
			for player in pairs(assignments) do
				local state = inventory.getState(player)
				if state then
					local amount = income(player, state)
					if cashHandler then cashHandler(player, amount) end
					Bases.Refresh(player)
				end
			end
		end
	end)
end
return Bases
