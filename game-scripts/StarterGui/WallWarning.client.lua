local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "WallWarningGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.Parent = playerGui

local banner = Instance.new("Frame")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Size = UDim2.fromOffset(620, 96)
banner.Position = UDim2.new(0.5, 0, 0.17, 0)
banner.BackgroundTransparency = 1
banner.Visible = false
banner.Parent = gui

local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 56)
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.TextSize = 40
title.TextColor3 = Color3.fromRGB(255, 60, 60)
title.Parent = banner
local ts = Instance.new("UIStroke")
ts.Thickness = 4
ts.Color = Color3.new(0, 0, 0)
ts.Parent = title

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, 0, 0, 36)
sub.Position = UDim2.fromOffset(0, 56)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.FredokaOne
sub.TextSize = 26
sub.TextColor3 = Color3.new(1, 1, 1)
sub.Parent = banner
local ss = Instance.new("UIStroke")
ss.Thickness = 3
ss.Color = Color3.new(0, 0, 0)
ss.Parent = sub

local function update()
	local count = workspace:GetAttribute("WallCountdown")
	if not count then
		banner.Visible = false
		return
	end
	local tier = workspace:GetAttribute("WallTier") or "FAST"
	local color = workspace:GetAttribute("WallColor") or Color3.fromRGB(255, 60, 60)
	title.Text = "⚠ " .. tier .. " WALL INCOMING ⚠"
	title.TextColor3 = color
	sub.Text = "Hide in a pit!  " .. count
	banner.Visible = true
	bannerScale.Scale = 1.25
	TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

workspace:GetAttributeChangedSignal("WallCountdown"):Connect(update)
update()
