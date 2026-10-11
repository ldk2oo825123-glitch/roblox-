local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local WheelConfig = require(RS:WaitForChild("WheelConfig"))
local spinRemote = RS:WaitForChild("SpinWheel")
local rewards = WheelConfig.Rewards
local N = #rewards

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
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
local function serverNow()
	return workspace:GetServerTimeNow()
end
local function fmt(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end
local function fmtShort(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local gui = Instance.new("ScreenGui")
gui.Name = "WheelGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.Parent = playerGui

-- ===== Side button (with a red "!" when a spin is ready) =====
local button = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(0, 0.5)
button.Size = UDim2.fromOffset(150, 40)
button.Position = UDim2.new(0, 12, 0.5, 150)       -- under Inventory, Home, Index
button.BackgroundColor3 = Color3.new(1, 1, 1)
button.BackgroundTransparency = 0.15
button.Text = ""
button.Parent = gui
corner(button, 10)
border(button, Color3.fromRGB(235, 245, 255), 2)
gradient(button, Color3.fromRGB(70, 200, 255), Color3.fromRGB(20, 110, 235), 90)
tstroke(label(button, "🎡 Daily Wheel", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 18), 2)

local badge = Instance.new("TextLabel")
badge.AnchorPoint = Vector2.new(0.5, 0.5)
badge.Size = UDim2.fromOffset(22, 22)
badge.Position = UDim2.new(1, -4, 0, 4)
badge.BackgroundColor3 = Color3.fromRGB(235, 40, 40)
badge.Text = "!"
badge.Font = FONT
badge.TextSize = 16
badge.TextColor3 = Color3.new(1, 1, 1)
badge.Visible = false
badge.Parent = button
corner(badge, 11)
border(badge, Color3.new(1, 1, 1), 2)

-- ===== Active potions list (bottom-left) =====
local boostList = Instance.new("Frame")
boostList.AnchorPoint = Vector2.new(0, 1)
boostList.Position = UDim2.new(0, 12, 1, -12)
boostList.Size = UDim2.fromOffset(240, 10)
boostList.AutomaticSize = Enum.AutomaticSize.Y
boostList.BackgroundTransparency = 1
boostList.Parent = gui
local bl = Instance.new("UIListLayout")
bl.Padding = UDim.new(0, 3)
bl.SortOrder = Enum.SortOrder.LayoutOrder
bl.VerticalAlignment = Enum.VerticalAlignment.Bottom
bl.Parent = boostList

local boostLabels = {}
for i, r in ipairs(rewards) do
	if r.attr then
		local l = label(boostList, "", UDim2.new(1, 0, 0, 22), UDim2.new(), 16)
		l.LayoutOrder = i
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = r.color
		l.Visible = false
		tstroke(l, 2)
		boostLabels[r.attr] = l
	end
end

-- ===== Wheel panel =====
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Size = UDim2.fromOffset(500, 620)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(15, 22, 30)
frame.BackgroundTransparency = 0.35
frame.ClipsDescendants = true
frame.Visible = false
frame.Parent = gui
corner(frame, 12)
border(frame, Color3.fromRGB(235, 245, 255), 3)

local scale = Instance.new("UIScale")
scale.Parent = frame
local function updateScale()
	local cam = workspace.CurrentCamera
	if cam then scale.Scale = math.clamp(cam.ViewportSize.Y / 1080, 0.5, 1.15) end
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
local title = label(header, "🎡 Daily Wheel", UDim2.new(1, -70, 1, 0), UDim2.fromOffset(16, 0), 30)
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

-- Pointer + wheel
local pointer = label(frame, "▼", UDim2.fromOffset(50, 40), UDim2.new(0.5, -25, 0, 62), 40)
pointer.TextColor3 = Color3.fromRGB(255, 70, 70)
pointer.ZIndex = 5
tstroke(pointer, 3)

local WHEEL = 340
local wheel = Instance.new("Frame")
wheel.AnchorPoint = Vector2.new(0.5, 0)
wheel.Size = UDim2.fromOffset(WHEEL, WHEEL)
wheel.Position = UDim2.new(0.5, 0, 0, 104)
wheel.BackgroundColor3 = Color3.fromRGB(25, 32, 48)
wheel.Parent = frame
corner(wheel, WHEEL // 2)
border(wheel, Color3.fromRGB(235, 245, 255), 5)

local spinner = Instance.new("Frame")
spinner.AnchorPoint = Vector2.new(0.5, 0.5)
spinner.Size = UDim2.fromOffset(WHEEL, WHEEL)
spinner.Position = UDim2.fromScale(0.5, 0.5)
spinner.BackgroundTransparency = 1
spinner.Parent = wheel

local half = WHEEL / 2
local radius = 122
for i, r in ipairs(rewards) do
	local theta = (i - 1) * 360 / N

	-- divider spoke between this segment and the next
	local spoke = Instance.new("Frame")
	spoke.AnchorPoint = Vector2.new(0.5, 1)
	spoke.Size = UDim2.fromOffset(3, half - 4)
	spoke.Position = UDim2.fromOffset(half, half)
	spoke.Rotation = theta + 180 / N
	spoke.BackgroundColor3 = Color3.fromRGB(235, 245, 255)
	spoke.BackgroundTransparency = 0.45
	spoke.BorderSizePixel = 0
	spoke.Parent = spinner

	-- reward bubble
	local rad = math.rad(theta)
	local bubble = Instance.new("Frame")
	bubble.AnchorPoint = Vector2.new(0.5, 0.5)
	bubble.Size = UDim2.fromOffset(64, 64)
	bubble.Position = UDim2.fromOffset(half + radius * math.sin(rad), half - radius * math.cos(rad))
	bubble.BackgroundColor3 = r.color
	bubble.Parent = spinner
	corner(bubble, 32)
	border(bubble, Color3.new(1, 1, 1), 3)
	local icon = label(bubble, r.icon, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), r.special and 26 or 34)
	tstroke(icon, r.special and 2 or 0)
end

-- hub
local hub = Instance.new("Frame")
hub.AnchorPoint = Vector2.new(0.5, 0.5)
hub.Size = UDim2.fromOffset(60, 60)
hub.Position = UDim2.fromScale(0.5, 0.5)
hub.BackgroundColor3 = Color3.fromRGB(15, 22, 30)
hub.ZIndex = 3
hub.Parent = wheel
corner(hub, 30)
border(hub, Color3.fromRGB(235, 245, 255), 3)
local hubIcon = label(hub, "🎡", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 28)
hubIcon.ZIndex = 4

-- Result text
local result = label(frame, "", UDim2.new(1, -30, 0, 56), UDim2.fromOffset(15, 454), 20)
result.TextWrapped = true
tstroke(result, 2)

-- Spin button
local spinButton = Instance.new("TextButton")
spinButton.AnchorPoint = Vector2.new(0.5, 0)
spinButton.Size = UDim2.fromOffset(260, 54)
spinButton.Position = UDim2.new(0.5, 0, 0, 512)
spinButton.BackgroundColor3 = Color3.new(1, 1, 1)
spinButton.Text = ""
spinButton.Parent = frame
corner(spinButton, 12)
border(spinButton, Color3.fromRGB(235, 255, 200), 3)
local spinGrad = gradient(spinButton, Color3.fromRGB(120, 230, 90), Color3.fromRGB(40, 170, 50), 90)
local spinText = label(spinButton, "SPIN!", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 26)
tstroke(spinText, 3)

local hint = label(frame, "One free spin every 24 hours. Potions last 15 minutes.",
	UDim2.new(1, -30, 0, 36), UDim2.fromOffset(15, 574), 14)
hint.TextColor3 = Color3.fromRGB(190, 215, 235)
hint.TextWrapped = true
tstroke(hint, 2)

local GREEN = ColorSequence.new(Color3.fromRGB(120, 230, 90), Color3.fromRGB(40, 170, 50))
local GREY = ColorSequence.new(Color3.fromRGB(150, 150, 160), Color3.fromRGB(90, 90, 100))

local spinning = false

local function remaining()
	return (plr:GetAttribute("NextSpin") or 0) - serverNow()
end

local function refreshUI()
	local rem = remaining()
	local ready = (not spinning) and rem <= 0
	badge.Visible = ready
	if spinning then
		spinText.Text = "SPINNING..."
		spinGrad.Color = GREY
	elseif rem > 0 then
		spinText.Text = "Next spin in " .. fmt(rem)
		spinText.TextSize = 20
		spinGrad.Color = GREY
	else
		spinText.Text = "SPIN!"
		spinText.TextSize = 26
		spinGrad.Color = GREEN
	end

	-- active potions
	for attr, l in pairs(boostLabels) do
		local r
		for _, rw in ipairs(rewards) do
			if rw.attr == attr then r = rw break end
		end
		local left = (plr:GetAttribute(attr) or 0) - serverNow()
		if r and left > 0 then
			l.Text = r.icon .. " " .. r.name .. "  " .. fmtShort(left)
			l.Visible = true
		else
			l.Visible = false
		end
	end
end

task.spawn(function()
	while true do
		refreshUI()
		task.wait(0.5)
	end
end)

spinButton.MouseButton1Click:Connect(function()
	if spinning or remaining() > 0 then return end
	spinning = true
	result.Text = ""
	refreshUI()

	local ok, a = spinRemote:InvokeServer()
	if not ok then
		spinning = false
		result.Text = tostring(a or "Couldn't spin")
		result.TextColor3 = Color3.fromRGB(255, 130, 130)
		refreshUI()
		return
	end

	local index = a
	local reward = rewards[index]
	local theta = (index - 1) * 360 / N
	local offset = math.random(-math.floor(180 / N * 0.6), math.floor(180 / N * 0.6))

	spinner.Rotation = spinner.Rotation % 360
	local base = spinner.Rotation
	local final = base + 360 * 5 + ((-theta + offset - base) % 360)
	local tween = TweenService:Create(spinner, TweenInfo.new(5.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Rotation = final})
	tween:Play()
	tween.Completed:Wait()

	spinning = false
	if reward.special then
		result.Text = "🎉 JACKPOT!! You won the " .. reward.name .. "!\n" .. reward.desc
	else
		result.Text = "You won: " .. reward.icon .. " " .. reward.name .. "\n" .. reward.desc
	end
	result.TextColor3 = reward.color
	refreshUI()
end)

button.MouseButton1Click:Connect(function()
	frame.Visible = not frame.Visible
end)
closeButton.MouseButton1Click:Connect(function()
	frame.Visible = false
end)

refreshUI()
