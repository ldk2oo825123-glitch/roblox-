local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local ShopConfig = require(RS:WaitForChild("ShopConfig"))
local remote = RS:WaitForChild("BuyUpgrade")

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local FONT = Enum.Font.FredokaOne

local function abbr(n)
	local units = {{1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}}
	for _, u in ipairs(units) do
		if n >= u[1] then
			local v = n / u[1]
			local s = string.format(v >= 100 and "%.0f" or (v >= 10 and "%.1f" or "%.2f"), v)
			if s:find("%.") then
				s = s:gsub("0+$", "")
				s = s:gsub("%.$", "")
			end
			return s .. u[2]
		end
	end
	return tostring(math.floor(n))
end

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
end
local function gradient(inst, c0, c1, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rot or 90
	g.Parent = inst
end
local function text(parent, str, size, pos, textSize, anchor)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	if anchor then l.AnchorPoint = anchor end
	l.Text = str
	l.Font = FONT
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Parent = parent
	return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "ShopGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- Main dark panel
local frame = Instance.new("Frame")
frame.Name = "ShopFrame"
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Size = UDim2.fromOffset(620, 352)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(15, 22, 30)
frame.BackgroundTransparency = 0.4
frame.ClipsDescendants = true
frame.Visible = false
frame.Parent = gui
corner(frame, 12)
border(frame, Color3.fromRGB(235, 245, 255), 3)

-- Scale to the screen
local scale = Instance.new("UIScale")
scale.Parent = frame
local function updateScale()
	local cam = workspace.CurrentCamera
	if cam then
		scale.Scale = math.clamp(cam.ViewportSize.Y / 1080 * 1.15, 0.6, 1.3)
	end
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- Header bar (cyan/blue) with title and red X
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 54)
header.BackgroundColor3 = Color3.new(1, 1, 1)
header.BorderSizePixel = 0
header.BackgroundTransparency = 0.15
header.Parent = frame
gradient(header, Color3.fromRGB(70, 200, 255), Color3.fromRGB(20, 110, 235), 90)
local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, 0, 0, 3)
divider.Position = UDim2.fromOffset(0, 54)
divider.BackgroundColor3 = Color3.fromRGB(235, 245, 255)
divider.BackgroundTransparency = 0.3
divider.BorderSizePixel = 0
divider.Parent = frame

local cart = text(header, "🛒", UDim2.fromOffset(44, 54), UDim2.fromOffset(8, 0), 32)
local title = text(header, "Shop", UDim2.fromOffset(300, 54), UDim2.fromOffset(56, 0), 34)
title.TextXAlignment = Enum.TextXAlignment.Left
tstroke(title, 3)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(54, 54)
closeButton.Position = UDim2.new(1, -54, 0, 0)
closeButton.BackgroundColor3 = Color3.new(1, 1, 1)
closeButton.BorderSizePixel = 0
closeButton.Text = ""
closeButton.Parent = frame
gradient(closeButton, Color3.fromRGB(245, 70, 70), Color3.fromRGB(170, 20, 20), 90)
border(closeButton, Color3.fromRGB(90, 0, 0), 3)
local xLabel = text(closeButton, "X", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 34)
tstroke(xLabel, 3)

-- Message line at the bottom
local message = text(frame, "", UDim2.new(1, -20, 0, 24), UDim2.new(0.5, 0, 1, -16), 20, Vector2.new(0.5, 0.5))
tstroke(message, 2)

local list = Instance.new("ScrollingFrame")
list.Name = "List"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(0, 60)
list.Size = UDim2.new(1, 0, 1, -88)
list.ScrollBarThickness = 8
list.ScrollBarImageColor3 = Color3.fromRGB(150, 220, 255)
list.CanvasSize = UDim2.fromOffset(0, #ShopConfig.Items * 86 + 6)
list.Parent = frame

local rows = {}

local function refresh()
	local cashObj = plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Cash")
	local cash = cashObj and cashObj.Value or 0
	for _, row in ipairs(rows) do
		local item = row.item
		local level = plr:GetAttribute(item.attr) or 0
		local cur = ShopConfig.value(item, level)
		row.level.Text = "Lv " .. level .. "/" .. item.maxLevel
		row.cur.Text = cur .. item.suffix
		if level >= item.maxLevel then
			row.arrow.Visible = false
			row.nxt.Text = "MAX"
			row.nxt.TextColor3 = Color3.fromRGB(255, 90, 90)
			row.price.Text = "MAX"
			row.buttonGrad.Color = ColorSequence.new(Color3.fromRGB(150, 150, 160), Color3.fromRGB(90, 90, 100))
		else
			row.arrow.Visible = true
			row.nxt.Text = ShopConfig.value(item, level + 1) .. item.suffix
			row.nxt.TextColor3 = Color3.fromRGB(255, 170, 40)
			local cost = ShopConfig.cost(item, level)
			row.price.Text = "$" .. abbr(cost)
			if cash >= cost then
				row.buttonGrad.Color = ColorSequence.new(Color3.fromRGB(200, 240, 50), Color3.fromRGB(80, 195, 40))
			else
				row.buttonGrad.Color = ColorSequence.new(Color3.fromRGB(215, 110, 100), Color3.fromRGB(150, 50, 50))
			end
		end
	end
end

local function valueBox(parent, x, color)
	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(120, 34)
	box.Position = UDim2.fromOffset(x, 38)
	box.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
	box.BackgroundTransparency = 0.35
	box.Parent = parent
	corner(box, 6)
	border(box, Color3.fromRGB(150, 220, 255), 2)
	local t = text(box, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 26)
	t.TextColor3 = color
	t.TextScaled = true
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.Parent = t
	return t
end

for i, item in ipairs(ShopConfig.Items) do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -26, 0, 80)
	row.Position = UDim2.new(0, 10, 0, 4 + (i - 1) * 86)
	row.BackgroundColor3 = Color3.fromRGB(10, 18, 28)
	row.BackgroundTransparency = 0.5
	row.Parent = list
	corner(row, 8)
	border(row, Color3.fromRGB(150, 220, 255), 2)

	-- Icon box
	local iconBox = Instance.new("Frame")
	iconBox.Size = UDim2.fromOffset(64, 64)
	iconBox.Position = UDim2.fromOffset(8, 8)
	iconBox.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
	iconBox.BackgroundTransparency = 0.4
	iconBox.Parent = row
	corner(iconBox, 8)
	border(iconBox, Color3.fromRGB(150, 220, 255), 2)
	local icon = text(iconBox, item.icon, UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 2), 36)
	local lvl = text(iconBox, "", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 1, -19), 14)
	tstroke(lvl, 2)

	-- Title
	local ttl = text(row, item.title, UDim2.fromOffset(300, 28), UDim2.fromOffset(96, 6), 24)
	tstroke(ttl, 2)

	-- Value boxes:  [current]  ➡  [next]
	local cur = valueBox(row, 96, Color3.new(1, 1, 1))
	local arrow = text(row, "➡", UDim2.fromOffset(34, 34), UDim2.fromOffset(222, 38), 26)
	tstroke(arrow, 2)
	local nxt = valueBox(row, 262, Color3.fromRGB(255, 170, 40))

	-- Price button
	local buy = Instance.new("TextButton")
	buy.Size = UDim2.fromOffset(150, 60)
	buy.Position = UDim2.new(1, -160, 0, 10)
	buy.BackgroundColor3 = Color3.new(1, 1, 1)
	buy.BorderSizePixel = 0
	buy.Text = ""
	buy.Parent = row
	local buttonGrad = Instance.new("UIGradient")
	buttonGrad.Rotation = 90
	buttonGrad.Color = ColorSequence.new(Color3.fromRGB(200, 240, 50), Color3.fromRGB(80, 195, 40))
	buttonGrad.Parent = buy
	corner(buy, 8)
	border(buy, Color3.fromRGB(235, 255, 200), 3)
	local price = text(buy, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 28)
	price.TextScaled = true
	tstroke(price, 3)
	local ppad = Instance.new("UIPadding")
	ppad.PaddingLeft = UDim.new(0, 8)
	ppad.PaddingRight = UDim.new(0, 8)
	ppad.PaddingTop = UDim.new(0, 12)
	ppad.PaddingBottom = UDim.new(0, 12)
	ppad.Parent = price

	buy.MouseButton1Click:Connect(function()
		local ok, msg = remote:InvokeServer(item.id)
		message.Text = msg or ""
		message.TextColor3 = ok and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(255, 150, 150)
		refresh()
	end)

	table.insert(rows, {
		item = item, level = lvl, cur = cur, nxt = nxt, arrow = arrow,
		price = price, button = buy, buttonGrad = buttonGrad,
	})
end

closeButton.MouseButton1Click:Connect(function()
	frame.Visible = false
end)

-- Opens when you walk onto the shop pad, closes when you leave it
task.spawn(function()
	local zone = workspace:WaitForChild("Game"):WaitForChild("Shop"):WaitForChild("ShopZone")
	local inside = false
	while true do
		task.wait(0.15)
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local nowInside = false
		if root then
			local rel = zone.CFrame:PointToObjectSpace(root.Position)
			local h = zone.Size / 2
			nowInside = math.abs(rel.X) < h.X and math.abs(rel.Y) < h.Y and math.abs(rel.Z) < h.Z
		end
		if nowInside and not inside then
			frame.Visible = true
			message.Text = ""
			refresh()
		elseif not nowInside and inside then
			frame.Visible = false
		end
		inside = nowInside
	end
end)

for _, item in ipairs(ShopConfig.Items) do
	plr:GetAttributeChangedSignal(item.attr):Connect(refresh)
end
task.spawn(function()
	local ls = plr:WaitForChild("leaderstats")
	local cash = ls:WaitForChild("Cash")
	cash.Changed:Connect(refresh)
	refresh()
end)
refresh()
