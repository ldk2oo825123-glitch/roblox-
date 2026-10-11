--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Config)
local Logic = require(ReplicatedStorage.WheelLogic).new(Config)
local Remotes = require(ReplicatedStorage.Remotes)
local ui = Config.Wheel.UI
local zero, one = Config.Math.Zero, Config.Math.One
local player = Players.LocalPlayer
local spinRemote = Remotes.Get("SpinWheel") :: RemoteFunction
local stateRemote = Remotes.Get("GetWheelState") :: RemoteFunction
local updateRemote = Remotes.Get("WheelUpdate") :: RemoteEvent
local screen = Instance.new("ScreenGui")
screen.Name = "DailyWheel"
screen.ResetOnSpawn = false
screen.Parent = player:WaitForChild("PlayerGui")
local function colour(rgb) return Color3.fromRGB(table.unpack(rgb)) end
local function widget(className: string, parent: Instance, position: {number}, size: {number}, scalePosition: boolean?): any
	local object = Instance.new(className)
	object.Position = scalePosition and UDim2.fromScale(table.unpack(position)) or UDim2.fromOffset(table.unpack(position))
	object.Size = UDim2.fromOffset(table.unpack(size))
	object.BackgroundColor3 = colour(ui.BackgroundRGB)
	object.BorderSizePixel = zero
	object.Parent = parent
	return object
end
local function label(className: string, parent: Instance, position: {number}, size: {number}, text: string, scalePosition: boolean?): any
	local object = widget(className, parent, position, size, scalePosition)
	object.Text = text
	object.TextColor3 = colour(ui.TextRGB)
	object.TextSize = ui.TextSize
	object.TextWrapped = true
	return object
end
local open = label("TextButton", screen, ui.ButtonPosition, ui.ButtonSize, "Daily Wheel", true)
local panel = widget("Frame", screen, ui.PanelPosition, ui.PanelSize, true)
panel.AnchorPoint = Vector2.new(table.unpack(ui.Anchor))
panel.Visible = false
label("TextLabel", panel, ui.HeaderPosition, ui.HeaderSize, "Daily Wheel - target at top")
local disc = widget("Frame", panel, ui.WheelPosition, ui.WheelSize, false)
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(one, zero)
corner.Parent = disc
local labels = { SpeedBoost = "Speed Boost", DoubleMoney = "Double Money", HealthBoost = "Health Boost",
	RagdollResist = "Ragdoll Resist", JumpBoost = "Jump Boost", KnockbackResist = "Knockback Resist", Brainrot67 = "67 Brainrot" }
local step = ui.FullTurnDegrees / #Config.Wheel.RewardOrder
for index, name in ipairs(Config.Wheel.RewardOrder) do
	local angle = math.rad((index - one) * step) - math.pi / (one + one)
	local position = { ui.Anchor[one] + math.cos(angle) * ui.RewardRadiusScale,
		ui.Anchor[one + one] + math.sin(angle) * ui.RewardRadiusScale }
	local reward = label("TextLabel", disc, position, ui.RewardLabelSize, labels[name], true)
	reward.AnchorPoint = Vector2.new(table.unpack(ui.Anchor))
	reward.TextSize = ui.RewardTextSize
	reward.BackgroundTransparency = one
end
local result = label("TextLabel", panel, ui.ResultPosition, ui.ResultSize, "Loading wheel...")
local spin = label("TextButton", panel, ui.SpinPosition, ui.SpinSize, "Loading...")
local strip = label("TextLabel", screen, ui.StripPosition, ui.StripSize, "", true)
strip.BackgroundTransparency = one
strip.TextXAlignment = Enum.TextXAlignment.Left
strip.TextYAlignment = Enum.TextYAlignment.Top
local state: any = nil
local serverOffset = zero
local busy = false
local function now() return math.floor(os.time() + serverOffset) end
local function receive(newState, serverNow)
	if not Logic.validateState(newState) or type(serverNow) ~= "number" then return end
	state = newState
	serverOffset = serverNow - os.time()
end
local function duration(seconds)
	local hourSeconds = ui.SecondsPerMinute * ui.MinutesPerHour
	local hours = math.floor(seconds / hourSeconds)
	local minutes = math.floor(seconds % hourSeconds / ui.SecondsPerMinute)
	return string.format("%02d:%02d:%02d", hours, minutes, seconds % ui.SecondsPerMinute)
end
local function refresh()
	if not state then return end
	local allowed, remaining = Logic.canSpin(state, now())
	spin.Text = busy and "Spinning..." or (allowed and "Spin" or duration(remaining))
	spin.Active = allowed and not busy
	local timers = {}
	local active = Logic.activePotions(state, now())
	for _, name in ipairs(Config.Wheel.RewardOrder) do
		if active[name] then table.insert(timers, labels[name] .. "  " .. duration(active[name] - now())) end
	end
	strip.Text = table.concat(timers, "\n")
end
updateRemote.OnClientEvent:Connect(function(newState, serverNow) receive(newState, serverNow); refresh() end)
open.Activated:Connect(function() panel.Visible = not panel.Visible end)
spin.Activated:Connect(function()
	if busy or not state or not Logic.canSpin(state, now()) then return end
	busy = true
	refresh()
	local ok, response = pcall(function() return spinRemote:InvokeServer() end)
	if not ok or type(response) ~= "table" then
		result.Text = "Wheel unavailable. Try again."
	elseif not response.ok then
		if response.state then receive(response.state, response.serverNow) end
		result.Text = response.reason == "cooldown" and "Next spin: " .. duration(response.remainingSeconds)
			or "Wheel is not ready."
	else
		receive(response.state, response.serverNow)
		local index = table.find(Config.Wheel.RewardOrder, response.rewardName)
		if index then
			result.Text = "Spinning..."
			local target = (-(index - one) * step) % ui.FullTurnDegrees
			local rotation = disc.Rotation + ui.AnimationTurns * ui.FullTurnDegrees
				+ (target - disc.Rotation % ui.FullTurnDegrees) % ui.FullTurnDegrees
			local tween = TweenService:Create(disc, TweenInfo.new(ui.AnimationSeconds, Enum.EasingStyle.Quart,
				Enum.EasingDirection.Out), { Rotation = rotation })
			tween:Play()
			tween.Completed:Wait()
			result.Text = labels[response.rewardName] .. (response.outcome == "already owned"
				and " - already owned. Daily spin used; no refund." or " - granted")
		end
	end
	busy = false
	refresh()
end)
-- Snapshot closes the join/event race; never invoke SpinWheel to fetch state.
task.spawn(function()
	while not state do
		local ok, response = pcall(function() return stateRemote:InvokeServer() end)
		if ok and type(response) == "table" and response.ok then receive(response.state, response.serverNow) end
		if not state then task.wait(ui.RefreshSeconds) end
	end
	result.Text = "One spin every " .. duration(Config.Wheel.CooldownSeconds) .. "."
	while screen.Parent do refresh(); task.wait(ui.RefreshSeconds) end
end)
