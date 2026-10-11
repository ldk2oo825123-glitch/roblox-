local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local remote = RS:WaitForChild("TeleportHome")

local gui = Instance.new("ScreenGui")
gui.Name = "HomeGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 4
gui.Parent = playerGui

local button = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(0, 0.5)
button.Size = UDim2.fromOffset(150, 40)
button.Position = UDim2.new(0, 12, 0.5, 50)     -- just under the Inventory button
button.BackgroundColor3 = Color3.new(1, 1, 1)
button.BackgroundTransparency = 0.15
button.Text = ""
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = button
local stroke = Instance.new("UIStroke")
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Color = Color3.fromRGB(235, 245, 255)
stroke.Thickness = 2
stroke.Parent = button
local grad = Instance.new("UIGradient")
grad.Rotation = 90
grad.Parent = button

local text = Instance.new("TextLabel")
text.BackgroundTransparency = 1
text.Size = UDim2.fromScale(1, 1)
text.Font = Enum.Font.FredokaOne
text.TextSize = 18
text.TextColor3 = Color3.new(1, 1, 1)
text.Text = "🏠 Home (H)"
text.Parent = button
local ts = Instance.new("UIStroke")
ts.Color = Color3.new(0, 0, 0)
ts.Thickness = 2
ts.Parent = text

local ACTIVE = ColorSequence.new(Color3.fromRGB(120, 230, 90), Color3.fromRGB(40, 170, 50))
local INACTIVE = ColorSequence.new(Color3.fromRGB(150, 150, 160), Color3.fromRGB(90, 90, 100))

local function inSafeZone()
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local game_ = workspace:FindFirstChild("Game")
	local zone = game_ and game_:FindFirstChild("SafeZone")
	if not root or not zone then return false end
	local rel = zone.CFrame:PointToObjectSpace(root.Position)
	local h = zone.Size / 2
	return math.abs(rel.X) < h.X and math.abs(rel.Z) < h.Z and math.abs(rel.Y) < 40
end

task.spawn(function()
	while true do
		task.wait(0.2)
		grad.Color = inSafeZone() and ACTIVE or INACTIVE
	end
end)

button.MouseButton1Click:Connect(function()
	remote:FireServer()
end)

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.H then
		remote:FireServer()
	end
end)
