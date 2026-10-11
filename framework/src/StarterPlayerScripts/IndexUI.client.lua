--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Config = require(RS.Config)
local Client = require(RS.InventoryClient)
local zero, one = Config.Math.Zero, Config.Math.One
local ui = Config.Inventory.UI
local gui = Instance.new("ScreenGui"); gui.Name = "IndexUI"; gui.ResetOnSpawn = false; gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local function widget(class, text, parent, x, y, w, h)
	local v = Instance.new(class); v.Text = text; v.TextColor3 = ui.TextColour; v.TextSize = ui.TextSize; v.BackgroundColor3 = ui.RowColour
	v.Position = UDim2.fromOffset(x, y); v.Size = UDim2.fromOffset(w, h); v.Parent = parent; return v
end
local panel = Instance.new("Frame"); panel.Size = UDim2.fromOffset(table.unpack(ui.IndexSize)); panel.Position = UDim2.fromScale(table.unpack(ui.IndexPosition)); panel.BackgroundColor3 = ui.Background; panel.Visible = false; panel.Parent = gui
widget("TextLabel", "Index", panel, zero, zero, ui.IndexSize[one] - ui.DropWidth, ui.HeaderHeight)
local close = widget("TextButton", "Close", panel, ui.IndexSize[one] - ui.DropWidth, zero, ui.DropWidth, ui.HeaderHeight); close.Activated:Connect(function() panel.Visible = false end)
local open = widget("TextButton", "Index (" .. Config.Index.Key .. ")", gui, zero, zero, table.unpack(ui.ButtonSize)); open.Position = UDim2.fromScale(table.unpack(ui.IndexButtonPosition))
local function toggle() panel.Visible = not panel.Visible end
open.Activated:Connect(toggle)
UIS.InputBegan:Connect(function(input, processed) if not processed and not UIS:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode[Config.Index.Key] then toggle() end end)
local progress = widget("TextLabel", "Collected 0 / " .. tostring(Config.Index.EntryCount), panel, zero, ui.IndexSize[one + one] - ui.ProgressHeight, ui.IndexSize[one], ui.ProgressHeight)
local fill = Instance.new("Frame"); fill.BackgroundColor3 = ui.ProgressColour; fill.Size = UDim2.fromScale(zero, one); fill.ZIndex = progress.ZIndex; fill.Parent = progress
local progressText = widget("TextLabel", progress.Text, progress, zero, zero, ui.IndexSize[one], ui.ProgressHeight); progressText.BackgroundTransparency = one; progressText.ZIndex = fill.ZIndex + one; progress.Text = ""
local list = Instance.new("ScrollingFrame"); list.Position = UDim2.fromOffset(ui.SidebarWidth, ui.HeaderHeight); list.Size = UDim2.fromOffset(ui.IndexSize[one] - ui.SidebarWidth, ui.IndexSize[one + one] - ui.HeaderHeight - ui.ProgressHeight); list.BackgroundTransparency = one; list.Parent = panel
local filter = "All"
local filters, buttons = { "All" }, {}
for _, variant in ipairs(Config.Brainrots.Variants) do table.insert(filters, variant.Name) end
local function render(state)
	local counts = { All = state.index.found }
	for _, variant in ipairs(Config.Brainrots.Variants) do counts[variant.Name] = zero end
	for _, tier in ipairs(Config.Brainrots.Tiers) do for _, variant in ipairs(Config.Brainrots.Variants) do if state.indexFound[tier.Name .. "|" .. variant.Name] then counts[variant.Name] = counts[variant.Name] + one end end end
	for name, button in pairs(buttons) do button.Text = name .. " " .. tostring(counts[name]); button.BackgroundColor3 = name == filter and ui.SelectedColour or ui.RowColour end
	for _, child in ipairs(list:GetChildren()) do child:Destroy() end
	local row = zero
	for _, tier in ipairs(Config.Brainrots.Tiers) do
		for _, variant in ipairs(Config.Brainrots.Variants) do
			if filter == "All" or filter == variant.Name then
				local found = state.indexFound[tier.Name .. "|" .. variant.Name]
				local label = widget("TextLabel", found and (tier.Name .. " / " .. variant.Name) or "???", list, zero, row * ui.RowHeight, ui.IndexSize[one] - ui.SidebarWidth - ui.Padding, ui.RowHeight)
				label.TextColor3 = Config.Brainrots.VariantColours[variant.Colour]; label:SetAttribute("RainbowLabel", variant.ColourCycling)
				row = row + one
			end
		end
	end
	list.CanvasSize = UDim2.fromOffset(zero, row * ui.RowHeight)
	progressText.Text = "Collected " .. tostring(state.index.found) .. " / " .. tostring(state.index.total)
	fill.Size = UDim2.fromScale(state.index.found / state.index.total, one)
end
for i, name in ipairs(filters) do
	local button = widget("TextButton", name .. " 0", panel, zero, ui.HeaderHeight + (i - one) * ui.RowHeight, ui.SidebarWidth, ui.RowHeight); buttons[name] = button
	button.Activated:Connect(function() filter = name; if Client.state then render(Client.state) end end)
end
Client.Changed:Connect(render); if Client.state then render(Client.state) end
-- Both progress text and bar are children of the closed-by-default panel.
