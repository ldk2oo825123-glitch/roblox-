local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local Catalog = require(RS:WaitForChild("BrainrotCatalog"))
local indexRemote = RS:WaitForChild("IndexUpdate")

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local FONT = Enum.Font.FredokaOne

local discovered = {}       -- name -> true
local rainbowObjs = {}      -- rebuilt with the list
local staticRainbow = {}    -- sidebar items that always exist
local filter = "All"

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
	return s
end
local function tstroke(inst, thick)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = Color3.new(0, 0, 0)
	s.Thickness = thick
	s.Parent = inst
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
gui.Name = "IndexGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.Parent = playerGui

-- ===== Side button =====
local button = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(0, 0.5)
button.Size = UDim2.fromOffset(150, 40)
button.Position = UDim2.new(0, 12, 0.5, 100)      -- under Inventory and Home
button.BackgroundColor3 = Color3.new(1, 1, 1)
button.BackgroundTransparency = 0.15
button.Text = ""
button.Parent = gui
corner(button, 10)
border(button, Color3.fromRGB(235, 245, 255), 2)
gradient(button, Color3.fromRGB(70, 200, 255), Color3.fromRGB(20, 110, 235), 90)
tstroke(label(button, "📖 Index (I)", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 18), 2)

-- ===== Panel =====
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Size = UDim2.fromOffset(860, 540)
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
	if cam then scale.Scale = math.clamp(cam.ViewportSize.Y / 1080, 0.55, 1.2) end
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
local title = label(header, "📖 Brainrot Index", UDim2.new(1, -70, 1, 0), UDim2.fromOffset(16, 0), 30)
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

-- ===== Left sidebar: filter by variant =====
local side = Instance.new("Frame")
side.Position = UDim2.fromOffset(8, 60)
side.Size = UDim2.new(0, 150, 1, -124)
side.BackgroundTransparency = 1
side.Parent = frame
local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 6)
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
sideLayout.Parent = side

local sideTitle = label(side, "FILTER", UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 0), 18)
sideTitle.LayoutOrder = 0
sideTitle.TextColor3 = Color3.fromRGB(190, 215, 235)
tstroke(sideTitle, 2)

local sideDivider = Instance.new("Frame")
sideDivider.Size = UDim2.new(0, 3, 1, -124)
sideDivider.Position = UDim2.fromOffset(164, 60)
sideDivider.BackgroundColor3 = Color3.fromRGB(235, 245, 255)
sideDivider.BackgroundTransparency = 0.5
sideDivider.BorderSizePixel = 0
sideDivider.Parent = frame

-- ===== Brainrot list (right of the sidebar) =====
local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(172, 58)
list.Size = UDim2.new(1, -172, 1, -122)
list.ScrollBarThickness = 8
list.ScrollBarImageColor3 = Color3.fromRGB(150, 220, 255)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = frame
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 6)
pad.PaddingRight = UDim.new(0, 6)
pad.PaddingTop = UDim.new(0, 4)
pad.PaddingBottom = UDim.new(0, 8)
pad.Parent = list

-- ===== Progress bar (only visible while the Index is open) =====
local barTrack = Instance.new("Frame")
barTrack.Size = UDim2.new(1, -32, 0, 30)
barTrack.Position = UDim2.new(0, 16, 1, -46)
barTrack.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
barTrack.BackgroundTransparency = 0.3
barTrack.Parent = frame
corner(barTrack, 15)
border(barTrack, Color3.fromRGB(235, 245, 255), 2)
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.new(1, 1, 1)
barFill.BorderSizePixel = 0
barFill.Parent = barTrack
corner(barFill, 15)
gradient(barFill, Color3.fromRGB(150, 240, 90), Color3.fromRGB(40, 180, 70), 90)
local barText = label(barTrack, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 20)
tstroke(barText, 2)

-- ===== Counting =====
local function variantCount(variant)
	local found = 0
	for _, t in ipairs(Catalog.Tiers) do
		if discovered[Catalog.fullName(t, variant)] then found += 1 end
	end
	return found, #Catalog.Tiers
end

local function totalCount()
	local found, total = 0, 0
	for _, v in ipairs(Catalog.Variants) do
		local f, t = variantCount(v)
		found += f
		total += t
	end
	return found, total
end

local function updateProgress()
	local found, total = totalCount()
	local pct = total > 0 and (found / total) or 0
	barFill.Size = UDim2.fromScale(pct, 1)
	barText.Text = string.format("Collected %d / %d  (%d%%)", found, total, math.floor(pct * 100 + 0.5))
end

-- ===== Sidebar buttons =====
local filterButtons = {}   -- name -> {button, stroke, count}
local filterNames = {"All"}
for _, v in ipairs(Catalog.Variants) do table.insert(filterNames, v.name) end

local function variantByName(name)
	for _, v in ipairs(Catalog.Variants) do
		if v.name == name then return v end
	end
end

local rebuild  -- forward declaration

for i, fname in ipairs(filterNames) do
	local variant = variantByName(fname)
	local accent = variant and variant.textColor or Color3.fromRGB(235, 245, 255)

	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 46)
	b.LayoutOrder = i
	b.BackgroundColor3 = Color3.fromRGB(10, 18, 28)
	b.BackgroundTransparency = 0.5
	b.Text = ""
	b.AutoButtonColor = false
	b.Parent = side
	corner(b, 8)
	local stroke = border(b, accent, 2)

	local nameLabel = label(b, fname, UDim2.new(1, -62, 1, 0), UDim2.fromOffset(10, 0), 19)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = accent
	tstroke(nameLabel, 2)
	if variant and variant.rainbow then table.insert(staticRainbow, {obj = nameLabel, prop = "TextColor3"}) end

	local countLabel = label(b, "", UDim2.fromOffset(52, 46), UDim2.new(1, -56, 0, 0), 16)
	tstroke(countLabel, 2)

	b.MouseButton1Click:Connect(function()
		filter = fname
		rebuild()
		list.CanvasPosition = Vector2.new(0, 0)
	end)

	filterButtons[fname] = {button = b, stroke = stroke, count = countLabel}
end

local function updateSidebar()
	for _, fname in ipairs(filterNames) do
		local fb = filterButtons[fname]
		local selected = (fname == filter)
		fb.button.BackgroundTransparency = selected and 0.15 or 0.5
		fb.stroke.Thickness = selected and 4 or 2
		local f, t
		if fname == "All" then
			f, t = totalCount()
		else
			f, t = variantCount(variantByName(fname))
		end
		fb.count.Text = f .. "/" .. t
		fb.count.TextColor3 = (f == t) and Color3.fromRGB(150, 255, 150) or Color3.new(1, 1, 1)
	end
end

-- ===== Build the list for the selected filter =====
rebuild = function()
	rainbowObjs = {}
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end

	for vi, variant in ipairs(Catalog.Variants) do
		if filter == "All" or filter == variant.name then
			local found = variantCount(variant)

			local head = Instance.new("Frame")
			head.Size = UDim2.new(1, -12, 0, 38)
			head.LayoutOrder = vi * 2 - 1
			head.BackgroundColor3 = Color3.fromRGB(10, 18, 28)
			head.BackgroundTransparency = 0.35
			head.Parent = list
			corner(head, 8)
			border(head, variant.textColor, 2)

			local bonusText = variant.bonus > 0 and ("   +" .. math.floor(variant.bonus * 100 + 0.5) .. "% value") or ""
			local ht = label(head, variant.name .. bonusText, UDim2.new(1, -100, 1, 0), UDim2.fromOffset(12, 0), 22)
			ht.TextXAlignment = Enum.TextXAlignment.Left
			ht.TextColor3 = variant.textColor
			tstroke(ht, 2)
			if variant.rainbow then table.insert(rainbowObjs, {obj = ht, prop = "TextColor3"}) end

			local hc = label(head, found .. "/" .. #Catalog.Tiers, UDim2.fromOffset(80, 38), UDim2.new(1, -88, 0, 0), 22)
			tstroke(hc, 2)
			if found == #Catalog.Tiers then hc.TextColor3 = Color3.fromRGB(150, 255, 150) end

			local grid = Instance.new("Frame")
			grid.Size = UDim2.new(1, -12, 0, 156)
			grid.LayoutOrder = vi * 2
			grid.BackgroundTransparency = 1
			grid.Parent = list
			local ug = Instance.new("UIGridLayout")
			ug.CellSize = UDim2.fromOffset(120, 150)
			ug.CellPadding = UDim2.fromOffset(6, 6)
			ug.SortOrder = Enum.SortOrder.LayoutOrder
			ug.Parent = grid

			for ti, tier in ipairs(Catalog.Tiers) do
				local name = Catalog.fullName(tier, variant)
				local have = discovered[name] == true

				local cell = Instance.new("Frame")
				cell.LayoutOrder = ti
				cell.BackgroundColor3 = Color3.fromRGB(10, 18, 28)
				cell.BackgroundTransparency = 0.45
				cell.Parent = grid
				corner(cell, 8)
				border(cell, have and variant.textColor or Color3.fromRGB(70, 85, 100), 2)

				local ball = Instance.new("Frame")
				ball.Size = UDim2.fromOffset(64, 64)
				ball.Position = UDim2.new(0.5, -32, 0, 12)
				ball.Parent = cell
				corner(ball, 32)
				border(ball, Color3.new(0, 0, 0), 3)

				local nameLabel = label(cell, "", UDim2.new(1, -8, 0, 40), UDim2.fromOffset(4, 80), 16)
				nameLabel.TextWrapped = true
				tstroke(nameLabel, 2)
				local valueLabel = label(cell, "", UDim2.new(1, -8, 0, 22), UDim2.fromOffset(4, 122), 14)
				tstroke(valueLabel, 2)

				if have then
					ball.BackgroundColor3 = variant.color or tier.color
					nameLabel.Text = name
					nameLabel.TextColor3 = variant.textColor
					valueLabel.Text = "$" .. Catalog.value(tier, variant) .. " per 5s"
					valueLabel.TextColor3 = Color3.fromRGB(200, 240, 200)
					if variant.rainbow then
						table.insert(rainbowObjs, {obj = ball, prop = "BackgroundColor3"})
						table.insert(rainbowObjs, {obj = nameLabel, prop = "TextColor3"})
					end
				else
					ball.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
					local q = label(ball, "?", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 36)
					q.TextColor3 = Color3.fromRGB(120, 130, 145)
					nameLabel.Text = "???"
					nameLabel.TextColor3 = Color3.fromRGB(140, 150, 165)
					valueLabel.Text = "Not found yet"
					valueLabel.TextColor3 = Color3.fromRGB(120, 130, 145)
				end
			end
		end
	end

	updateSidebar()
	updateProgress()
end

-- Rainbow colour cycling
task.spawn(function()
	local hue = 0
	while true do
		task.wait(0.1)
		hue = (hue + 0.02) % 1
		local col = Color3.fromHSV(hue, 1, 1)
		for _, r in ipairs(rainbowObjs) do
			if r.obj.Parent then r.obj[r.prop] = col end
		end
		for _, r in ipairs(staticRainbow) do
			if r.obj.Parent then r.obj[r.prop] = col end
		end
	end
end)

local function toggle()
	if frame.Visible then
		frame.Visible = false
	else
		rebuild()
		frame.Visible = true
	end
end

button.MouseButton1Click:Connect(toggle)
closeButton.MouseButton1Click:Connect(function() frame.Visible = false end)
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.I then toggle() end
end)

indexRemote.OnClientEvent:Connect(function(names)
	discovered = {}
	for _, n in ipairs(names or {}) do discovered[n] = true end
	if frame.Visible then rebuild() end
end)

updateSidebar()
updateProgress()
