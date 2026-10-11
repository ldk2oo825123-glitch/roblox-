--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Config = require(RS.Config)
local Client = require(RS.InventoryClient)
local Data = require(RS.BrainrotData)
local player = Players.LocalPlayer
local zero, one = Config.Math.Zero, Config.Math.One
local ui = Config.Inventory.UI
local gui = Instance.new("ScreenGui"); gui.Name = "InventoryUI"; gui.ResetOnSpawn = false; gui.Parent = player:WaitForChild("PlayerGui")
local function widget(class, text, parent, x, y, width, height)
	local w = Instance.new(class); w.Position = UDim2.fromOffset(x, y); w.Size = UDim2.fromOffset(width, height)
	w.BackgroundColor3 = ui.RowColour; w.TextColor3 = ui.TextColour; w.TextSize = ui.TextSize; w.Text = text; w.Parent = parent; return w
end
local panel = Instance.new("Frame"); panel.Position = UDim2.fromScale(table.unpack(ui.PanelPosition)); panel.Size = UDim2.fromOffset(table.unpack(ui.PanelSize)); panel.BackgroundColor3 = ui.Background; panel.Visible = false; panel.Parent = gui
local selected, pendingSlot
local header = widget("TextLabel", "Inventory", panel, zero, zero, ui.PanelSize[one] - ui.DropWidth, ui.HeaderHeight)
local close = widget("TextButton", "Close", panel, ui.PanelSize[one] - ui.DropWidth, zero, ui.DropWidth, ui.HeaderHeight)
close.Activated:Connect(function() panel.Visible = false; pendingSlot = nil; header.Text = "Inventory" end)
local list = Instance.new("ScrollingFrame"); list.Position = UDim2.fromOffset(zero, ui.HeaderHeight); list.Size = UDim2.new(one, zero, one, -ui.HeaderHeight); list.BackgroundTransparency = one; list.CanvasSize = UDim2.fromOffset(zero, zero); list.Parent = panel
local button = widget("TextButton", "Inventory", gui, zero, zero, table.unpack(ui.ButtonSize)); button.Position = UDim2.fromScale(table.unpack(ui.ButtonPosition))
button.Activated:Connect(function() pendingSlot = nil; header.Text = "Inventory"; panel.Visible = not panel.Visible end)
local carrying = widget("TextLabel", "Carrying: none", gui, zero, zero, table.unpack(ui.CarrySize)); carrying.Position = UDim2.fromScale(table.unpack(ui.CarryPosition)); carrying.BackgroundTransparency = one
local message = widget("TextLabel", "", gui, zero, zero, table.unpack(ui.MessageSize)); message.Position = UDim2.fromScale(table.unpack(ui.MessagePosition)); message.Visible = false
local messageVersion = zero
local function notify(text)
	messageVersion = messageVersion + one; local version = messageVersion
	message.Text = text; message.Visible = true
	task.delay(ui.MessageSeconds, function() if version == messageVersion then message.Visible = false end end)
end
local function invoke(name, ...)
	local result = Client.invoke(name, ...)
	if not result.ok then notify(result.reason) end
	return result.ok
end
local function drop()
	if selected then invoke("DropItem", selected) else notify("Select an inventory item first") end
end
local function render(state)
	local carryNames = {}; for _, item in ipairs(state.carried) do table.insert(carryNames, item.tier .. " / " .. item.variant) end
	carrying.Text = #carryNames == zero and "Carrying: none" or "Carrying: " .. table.concat(carryNames, ", ")
	local selectedExists = false
	for _, group in ipairs(state.inventory) do for _, item in ipairs(group.items) do if item.id == selected then selectedExists = true end end end
	if not selectedExists then selected = nil end
	for _, child in ipairs(list:GetChildren()) do child:Destroy() end
	for i, group in ipairs(state.inventory) do
		local id = group.items[one].id
		local row = widget("TextButton", group.tier .. " / " .. group.variant .. " x" .. tostring(group.count), list, zero, (i - one) * ui.RowHeight, ui.PanelSize[one] - ui.DropWidth, ui.RowHeight)
		local variant = Data.GetVariant(group.variant); row.TextColor3 = Config.Brainrots.VariantColours[variant.Colour]; row:SetAttribute("RainbowLabel", variant.ColourCycling)
		row.BackgroundColor3 = selected == id and ui.SelectedColour or ui.RowColour
		row.Activated:Connect(function()
			selected = id
			if pendingSlot then
				local slot = pendingSlot; pendingSlot = nil
				header.Text = "Inventory"
				if invoke("PlaceItem", selected, slot) then panel.Visible = false end
			else render(Client.state) end
		end)
		local dropButton = widget("TextButton", "DROP", list, ui.PanelSize[one] - ui.DropWidth, (i - one) * ui.RowHeight, ui.DropWidth, ui.RowHeight)
		dropButton.Activated:Connect(function() selected = id; drop() end)
	end
	list.CanvasSize = UDim2.fromOffset(zero, #state.inventory * ui.RowHeight)
end
Client.Changed:Connect(render); if Client.state then render(Client.state) end
UIS.InputBegan:Connect(function(input, processed)
	if not processed and not UIS:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode[Config.Inventory.DropKey] then drop() end
end)
-- Prompt visibility is local to the owner. All authority remains in Inventory.
local watched, rainbow = {}, {}
local function observe(object)
	if object:IsA("ProximityPrompt") and object.Name == "BaseItemPrompt" and not watched[object] then
		local connections = {}
		watched[object] = connections
		local function visibility() object.Enabled = object:GetAttribute("OwnerUserId") == player.UserId end
		table.insert(connections, object:GetAttributeChangedSignal("OwnerUserId"):Connect(visibility)); visibility()
		table.insert(connections, object.Triggered:Connect(function(who)
			if who ~= player or object:GetAttribute("OwnerUserId") ~= player.UserId then return end
			local slot = object:GetAttribute("PedestalSlot")
			if object.ActionText == "Pick Up" then invoke("PickUpItem", slot)
			else pendingSlot = slot; header.Text = "Choose an item for pedestal " .. tostring(slot); panel.Visible = true end
		end))
		table.insert(connections, object.Destroying:Connect(function() for _, connection in ipairs(connections) do connection:Disconnect() end; watched[object] = nil end))
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") then
		-- Track labels once; no workspace-wide descendant scan per frame.
		rainbow[object] = true
		object.Destroying:Once(function() rainbow[object] = nil end)
	end
end
workspace.DescendantAdded:Connect(observe); player.PlayerGui.DescendantAdded:Connect(observe)
for _, object in ipairs(workspace:GetDescendants()) do observe(object) end
for _, object in ipairs(player.PlayerGui:GetDescendants()) do observe(object) end
RunService.RenderStepped:Connect(function()
	local colour = Color3.fromHSV((os.clock() / Config.Inventory.RainbowCycleSeconds) % one, one, one)
	for label in pairs(rainbow) do if label:GetAttribute("RainbowLabel") then label.TextColor3 = colour end end
end)
