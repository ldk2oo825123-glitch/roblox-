local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

local function comma(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then formatted = formatted:sub(2) end
	return formatted
end

local gui = Instance.new("ScreenGui")
gui.Name = "CashHudGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- Main cash panel
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(150, 42)
panel.Position = UDim2.new(0.5, -75, 0, 10)
panel.BackgroundColor3 = Color3.fromRGB(25, 30, 25)
panel.BackgroundTransparency = 0.15
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 220, 120)
stroke.Thickness = 2
stroke.Parent = panel

local cashLabel = Instance.new("TextLabel")
cashLabel.Size = UDim2.new(1, -16, 1, -8)
cashLabel.Position = UDim2.fromOffset(8, 4)
cashLabel.BackgroundTransparency = 1
cashLabel.Text = "$0"
cashLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
cashLabel.Font = Enum.Font.GothamBlack
cashLabel.TextScaled = true
cashLabel.Parent = panel

-- Carrying indicator
local carryLabel = Instance.new("TextLabel")
carryLabel.Size = UDim2.fromOffset(300, 26)
carryLabel.Position = UDim2.new(0.5, -150, 0, 58)
carryLabel.BackgroundTransparency = 1
carryLabel.Text = ""
carryLabel.TextColor3 = Color3.fromRGB(255, 230, 130)
carryLabel.TextStrokeTransparency = 0.4
carryLabel.Font = Enum.Font.GothamBold
carryLabel.TextSize = 15
carryLabel.Parent = gui

local function updateCarry()
	local value = plr:GetAttribute("CarryValue") or 0
	local name = plr:GetAttribute("CarryName") or ""
	if value > 0 then
		carryLabel.Text = "Carrying: " .. name .. " ($" .. comma(value) .. ") - bring it to the safe zone!"
	else
		carryLabel.Text = ""
	end
end
plr:GetAttributeChangedSignal("CarryValue"):Connect(updateCarry)
plr:GetAttributeChangedSignal("CarryName"):Connect(updateCarry)
updateCarry()

-- Floating +$ / -$ popups
local function popup(delta)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(160, 34)
	label.Position = UDim2.new(0.5, -80, 0, 48)
	label.BackgroundTransparency = 1
	label.Text = (delta > 0 and "+$" or "-$") .. comma(math.abs(delta))
	label.TextColor3 = delta > 0 and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(255, 120, 120)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 22
	label.Parent = gui
	local tween = TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -80, 0, 95),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function() label:Destroy() end)
end

local function pulse()
	panel.Size = UDim2.fromOffset(164, 46)
	panel.Position = UDim2.new(0.5, -82, 0, 8)
	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(150, 42),
		Position = UDim2.new(0.5, -75, 0, 10),
	}):Play()
end

task.spawn(function()
	local cash = plr:WaitForChild("leaderstats"):WaitForChild("Cash")
	local last = cash.Value
	cashLabel.Text = "$" .. comma(last)
	cash.Changed:Connect(function(new)
		local delta = new - last
		last = new
		cashLabel.Text = "$" .. comma(new)
		if delta ~= 0 then
			popup(delta)
			if delta > 0 then pulse() end
		end
	end)
end)
