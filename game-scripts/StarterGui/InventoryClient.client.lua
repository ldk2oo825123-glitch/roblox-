local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local PPS = game:GetService("ProximityPromptService")

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local notify = RS:WaitForChild("Notify")
local dropCarriedRemote = RS:WaitForChild("DropBrainrot")
local dropInvRemote = RS:WaitForChild("DropFromInventory")
local placeRemote = RS:WaitForChild("PlaceBrainrot")
local updateRemote = RS:WaitForChild("InventoryUpdate")
local FONT = Enum.Font.FredokaOne

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end
local function border(inst, color, thick)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thick
	s.Parent = inst
end
local function tstroke(inst, thick)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = Color3.new(0, 0, 0)
	s.Thickness = thick
	s.Parent = inst
	return s
end
local function gradient(inst, c0, c1, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rot or 90
	g.Parent = inst
	return g
end
local function label(parent, str, size, pos, textSize)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Text = str
	l.Font = FONT
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Parent = parent
	return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "InventoryGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui

-- ===== Pop-up messages =====
local function toast(text, color)
	local l = label(gui, text, UDim2.fromOffset(560, 36), UDim2.new(0.5, -280, 0.72, 0), 24)
	l.TextColor3 = color or Color3.new(1, 1, 1)
	local s = tstroke(l, 3)
	local info = TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(l, info, {Position = UDim2.new(0.5, -280, 0.66, 0), TextTransparency = 1}):Play()
	TweenService:Create(s, info, {Transparency = 1}):Play()
	task.delay(1.9, function() l:Destroy() end)
end
notify.OnClientEvent:Connect(toast)

-- ===== Small drop button (only while carrying) =====
local dropButton = Instance.new("TextButton")
dropButton.AnchorPoint = Vector2.new(0.5, 1)
dropButton.Size = UDim2.fromOffset(96, 30)
dropButton.Position = UDim2.new(0.5, 0, 1, -60)
dropButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
dropButton.Text = "DROP (G)"
dropButton.Font = FONT
dropButton.TextSize = 16
dropButton.TextColor3 = Color3.new(1, 1, 1)
dropButton.Visible = false
dropButton.Parent = gui
corner(dropButton, 8)
border(dropButton, Color3.new(1, 1, 1), 2)

dropButton.MouseButton1Click:Connect(function()
	dropCarriedRemote:FireServer()
end)

task.spawn(function()
	while true do
		task.wait(0.2)
		local carrying = (plr:GetAttribute("CarryName") or "") ~= ""
		dropButton.Visible = carrying
	end
end)

-- ===== Inventory panel =====
local inventory = {}      -- array of {name, value, color, count}
local mode = "browse"     -- "browse" or "place"
local target = nil        -- {baseIndex, slotNumber} when placing

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Size = UDim2.fromOffset(460, 440)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(15, 22, 30)
frame.BackgroundTransparency = 0.4
frame.ClipsDescendants = true
frame.Visible = false
frame.Parent = gui
corner(frame, 12)
border(frame, Color3.fromRGB(235, 245, 255), 3)

local scale = Instance.new("UIScale")
scale.Parent = frame
local function updateScale()
	local cam = workspace.CurrentCamera
	if cam then scale.Scale = math.clamp(cam.ViewportSize.Y / 1080, 0.6, 1.2) end
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.new(1, 1, 1)
header.BackgroundTransparency = 0.15
header.BorderSizePixel = 0
header.Parent = frame
gradient(header, Color3.fromRGB(70, 200, 255), Color3.fromRGB(20, 110, 235), 90)

local title = label(header, "Inventory", UDim2.new(1, -70, 1, 0), UDim2.fromOffset(16, 0), 30)
title.TextXAlignment = Enum.TextXAlignment.Left
tstroke(title, 3)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(50, 50)
closeButton.Position = UDim2.new(1, -50, 0, 0)
closeButton.BackgroundColor3 = Color3.new(1, 1, 1)
closeButton.BorderSizePixel = 0
closeButton.Text = ""
closeButton.Parent = frame
gradient(closeButton, Color3.fromRGB(245, 70, 70), Color3.fromRGB(170, 20, 20), 90)
border(closeButton, Color3.fromRGB(90, 0, 0), 3)
tstroke(label(closeButton, "X", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 30), 3)

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, 0, 0, 3)
divider.Position = UDim2.fromOffset(0, 50)
divider.BackgroundColor3 = Color3.fromRGB(235, 245, 255)
divider.BackgroundTransparency = 0.3
divider.BorderSizePixel = 0
divider.Parent = frame

local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(0, 58)
list.Size = UDim2.new(1, 0, 1, -66)
list.ScrollBarThickness = 8
list.ScrollBarImageColor3 = Color3.fromRGB(150, 220, 255)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = frame
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.PaddingTop = UDim.new(0, 4)
pad.Parent = list

local emptyLabel = label(frame, "Your inventory is empty\nBring brainrots back from the danger zone!",
	UDim2.new(1, -40, 0, 80), UDim2.new(0, 20, 0.5, -20), 22)
tstroke(emptyLabel, 2)

-- Button on the side of the screen
local invButton = Instance.new("TextButton")
invButton.AnchorPoint = Vector2.new(0, 0.5)
invButton.Size = UDim2.fromOffset(150, 40)
invButton.Position = UDim2.new(0, 12, 0.5, 0)
invButton.BackgroundColor3 = Color3.new(1, 1, 1)
invButton.BackgroundTransparency = 0.15
invButton.Text = ""
invButton.Parent = gui
corner(invButton, 10)
border(invButton, Color3.fromRGB(235, 245, 255), 2)
gradient(invButton, Color3.fromRGB(70, 200, 255), Color3.fromRGB(20, 110, 235), 90)
local invButtonText = label(invButton, "🎒 Inventory", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 18)
tstroke(invButtonText, 2)

local TEXT_COLORS = {
	Gold = Color3.fromRGB(255, 215, 60),
	Diamond = Color3.fromRGB(150, 235, 255),
	Emerald = Color3.fromRGB(80, 255, 140),
}
local rainbowLabels = {}
task.spawn(function()
	local hue = 0
	while true do
		task.wait(0.1)
		hue = (hue + 0.02) % 1
		local col = Color3.fromHSV(hue, 1, 1)
		for i = #rainbowLabels, 1, -1 do
			local l = rainbowLabels[i]
			if l.Parent then
				l.TextColor3 = col
			else
				table.remove(rainbowLabels, i)
			end
		end
	end
end)

local function totalCount()
	local n = 0
	for _, e in ipairs(inventory) do n += e.count end
	return n
end

local function rebuild()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	invButtonText.Text = "🎒 Inventory (" .. totalCount() .. ")"
	emptyLabel.Visible = (#inventory == 0)

	for i, e in ipairs(inventory) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 64)
		row.LayoutOrder = i
		row.BackgroundColor3 = Color3.fromRGB(10, 18, 28)
		row.BackgroundTransparency = 0.5
		row.Parent = list
		corner(row, 8)
		border(row, Color3.fromRGB(150, 220, 255), 2)

		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(40, 40)
		dot.Position = UDim2.fromOffset(10, 12)
		dot.BackgroundColor3 = e.color
		dot.Parent = row
		corner(dot, 20)
		border(dot, Color3.new(0, 0, 0), 2)

		local name = label(row, e.name, UDim2.fromOffset(170, 28), UDim2.fromOffset(60, 6), 20)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local prefix = string.match(e.name, "^(%a+) ")
		if prefix == "Rainbow" or e.name == "67 Brainrot" then
			table.insert(rainbowLabels, name)
		elseif TEXT_COLORS[prefix] then
			name.TextColor3 = TEXT_COLORS[prefix]
		end
		tstroke(name, 2)
		local sub = label(row, ((e.name == "67 Brainrot") and "= your best brainrot" or ("$" .. e.value .. " per 5s")), UDim2.fromOffset(170, 22), UDim2.fromOffset(60, 34), 15)
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextColor3 = Color3.fromRGB(200, 240, 200)
		tstroke(sub, 2)
		local count = label(row, "x" .. e.count, UDim2.fromOffset(56, 36), UDim2.fromOffset(232, 14), 24)
		tstroke(count, 2)

		if mode == "place" then
			local place = Instance.new("TextButton")
			place.Size = UDim2.fromOffset(104, 38)
			place.Position = UDim2.new(1, -116, 0.5, -19)
			place.BackgroundColor3 = Color3.fromRGB(70, 210, 70)
			place.Text = ""
			place.Parent = row
			corner(place, 8)
			border(place, Color3.fromRGB(235, 255, 200), 2)
			tstroke(label(place, "Place", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 22), 2)
			place.MouseButton1Click:Connect(function()
				if not target then return end
				local ok, msg = placeRemote:InvokeServer(e.name, target.baseIndex, target.slotNumber)
				toast(msg or "", ok and Color3.fromRGB(140, 255, 160) or Color3.fromRGB(255, 130, 130))
				if ok then
					frame.Visible = false
					mode = "browse"
					target = nil
				end
			end)
		else
			local drop = Instance.new("TextButton")
			drop.Size = UDim2.fromOffset(60, 30)
			drop.Position = UDim2.new(1, -134, 0.5, -15)
			drop.BackgroundColor3 = Color3.fromRGB(215, 55, 55)
			drop.Text = ""
			drop.Parent = row
			corner(drop, 6)
			border(drop, Color3.new(1, 1, 1), 2)
			tstroke(label(drop, "Drop", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 16), 2)
			drop.MouseButton1Click:Connect(function()
				dropInvRemote:FireServer(e.name, false)
			end)

			local all = Instance.new("TextButton")
			all.Size = UDim2.fromOffset(60, 30)
			all.Position = UDim2.new(1, -68, 0.5, -15)
			all.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
			all.Text = ""
			all.Parent = row
			corner(all, 6)
			border(all, Color3.new(1, 1, 1), 2)
			tstroke(label(all, "Drop All", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 14), 2)
			all.MouseButton1Click:Connect(function()
				dropInvRemote:FireServer(e.name, true)
			end)
		end
	end
end

local function openBrowse()
	mode = "browse"
	target = nil
	title.Text = "Inventory"
	frame.Visible = true
	rebuild()
end

local function openPlace(baseIndex, slotNumber)
	mode = "place"
	target = {baseIndex = baseIndex, slotNumber = slotNumber}
	title.Text = "Place which brainrot?"
	frame.Visible = true
	rebuild()
end

invButton.MouseButton1Click:Connect(function()
	if frame.Visible then frame.Visible = false else openBrowse() end
end)
closeButton.MouseButton1Click:Connect(function()
	frame.Visible = false
	mode = "browse"
	target = nil
end)

updateRemote.OnClientEvent:Connect(function(newList)
	inventory = newList or {}
	rebuild()
end)

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.G then
		dropCarriedRemote:FireServer()
	elseif input.KeyCode == Enum.KeyCode.B then
		if frame.Visible then frame.Visible = false else openBrowse() end
	end
end)

-- Pressing E on an empty pedestal opens the picker
PPS.PromptTriggered:Connect(function(prompt, player)
	if player ~= plr then return end
	if prompt.Name ~= "SlotPrompt" or prompt.ActionText ~= "Place" then return end
	local slotPart = prompt.Parent
	local base = slotPart and slotPart.Parent
	local slotNumber = slotPart and tonumber(slotPart.Name:match("%d+"))
	local baseIndex = base and base:GetAttribute("BaseIndex")
	if not (slotNumber and baseIndex) then return end
	if #inventory == 0 then
		toast("Your inventory is empty", Color3.fromRGB(255, 130, 130))
		return
	end
	openPlace(baseIndex, slotNumber)
end)

-- Only show the pedestal prompts on your own base
task.spawn(function()
	local bases = workspace:WaitForChild("Game"):WaitForChild("Bases")
	while true do
		for _, b in ipairs(bases:GetChildren()) do
			local owned = b:GetAttribute("OwnerUserId") == plr.UserId
			for _, d in ipairs(b:GetDescendants()) do
				if d:IsA("ProximityPrompt") and d.Enabled ~= owned then
					d.Enabled = owned
				end
			end
		end
		task.wait(0.5)
	end
end)

rebuild()
