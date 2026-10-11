local TweenService = game:GetService("TweenService")

local game_ = workspace:WaitForChild("Game")
local wall = game_:WaitForChild("Wall")
local face = wall:WaitForChild("Face")
local safe = game_:WaitForChild("SafeZone")

local START_X = wall.Position.X
local END_X = safe.Position.X + safe.Size.X / 2 + wall.Size.X / 2
local WAIT_TIME = 20
local MIN_SPEED = 14   -- studs per second (slowest round)
local MAX_SPEED = 120  -- studs per second (fastest round)

local Players = game:GetService("Players")

local HIT_DAMAGE = 100                       -- HP lost per hit
local FLING_VELOCITY = Vector3.new(-95, 70, 0) -- back toward the safe zone (the wall moves toward -X)
local RAGDOLL_TIME = 3
local HIT_COOLDOWN = 2.5                     -- stops one pass of the wall from hitting many times

local Inventory = require(game:GetService("ServerStorage"):WaitForChild("BrainrotInventory"))

local lastHit = {}

local function ragdoll(char, hum, root, flingMult, timeMult)
	if char:GetAttribute("Ragdolled") then return end
	char:SetAttribute("Ragdolled", true)

	hum.PlatformStand = true
	hum:ChangeState(Enum.HumanoidStateType.Physics)

	-- Swap each joint for a loose ball-and-socket so the body flops
	local created = {}
	for _, m in ipairs(char:GetDescendants()) do
		if m:IsA("Motor6D") and m.Name ~= "RootJoint" and m.Part0 and m.Part1 then
			local a0 = Instance.new("Attachment")
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			socket.Parent = m.Part0
			m.Enabled = false
			table.insert(created, {motor = m, a0 = a0, a1 = a1, socket = socket})
		end
	end

	-- Let the server drive the physics so the fling isn't overridden by the client
	pcall(function() root:SetNetworkOwner(nil) end)
	root.AssemblyLinearVelocity = FLING_VELOCITY * (flingMult or 1)
	root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))

	task.delay(RAGDOLL_TIME * (timeMult or 1), function()
		-- If they died, the respawn replaces the character; nothing to put back together
		if not char.Parent or hum.Health <= 0 then return end
		for _, c in ipairs(created) do
			if c.motor then c.motor.Enabled = true end
			if c.socket then c.socket:Destroy() end
			if c.a0 then c.a0:Destroy() end
			if c.a1 then c.a1:Destroy() end
		end
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		local plr = Players:GetPlayerFromCharacter(char)
		if plr then
			pcall(function() root:SetNetworkOwner(plr) end)
		end
		char:SetAttribute("Ragdolled", nil)
	end)
end

wall.Touched:Connect(function(hit)
	local char = hit.Parent
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then return end

	local now = os.clock()
	if lastHit[char] and now - lastHit[char] < HIT_COOLDOWN then return end
	lastHit[char] = now

	-- Direct health change so a spawn ForceField can't block it
	hum.Health = math.max(0, hum.Health - HIT_DAMAGE)
	local rplr = Players:GetPlayerFromCharacter(char)
	local kb = rplr and (rplr:GetAttribute("KnockbackLevel") or 0) or 0
	local rg = rplr and (rplr:GetAttribute("RagdollLevel") or 0) or 0
	if rplr then Inventory.dropAllCarried(rplr, char) end   -- getting ragdolled makes you drop what you're carrying
	ragdoll(char, hum, root, math.max(0.1, 1 - 0.08 * (kb + (rplr and (rplr:GetAttribute("BoostKnockback") or 0) > os.time() and 5 or 0))), math.max(0.1, 1 - 0.08 * (rg + (rplr and (rplr:GetAttribute("BoostRagdoll") or 0) > os.time() and 5 or 0))))
end)

local TIERS = {
	{name = "SLOW",       min = 14, max = 22,  weight = 22, color = Color3.fromRGB(60, 220, 60)},
	{name = "MEDIUM",     min = 22, max = 32,  weight = 22, color = Color3.fromRGB(255, 225, 40)},
	{name = "FAST",       min = 32, max = 45,  weight = 20, color = Color3.fromRGB(255, 140, 30)},
	{name = "EXTREME",    min = 45, max = 60,  weight = 15, color = Color3.fromRGB(230, 30, 30)},
	{name = "INSANE",     min = 60, max = 85,  weight = 12, color = Color3.fromRGB(140, 0, 0)},
	{name = "LIGHTSPEED", min = 85, max = 120, weight = 9,  color = Color3.fromRGB(190, 70, 255)},
}
local totalWeight = 0
for _, tr in ipairs(TIERS) do totalWeight += tr.weight end

local WARNING_TIME = 5
local light = wall:FindFirstChildOfClass("PointLight")

local function pickTier()
	local r = math.random() * totalWeight
	for _, tr in ipairs(TIERS) do
		r -= tr.weight
		if r <= 0 then return tr end
	end
	return TIERS[1]
end

while true do
	-- Pick this round's tier + speed up front so players can be warned
	local tier = pickTier()
	local speed = math.random(tier.min * 10, tier.max * 10) / 10
	local t = (speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)          -- 0 = slowest, 1 = fastest
	local travelTime = math.abs(START_X - END_X) / speed
	HIT_DAMAGE = math.floor(60 + t * 340)                             -- 60 .. 400 HP
	FLING_VELOCITY = Vector3.new(-(60 + t * 300), 50 + t * 150, 0)    -- weak .. enormous fling
	RAGDOLL_TIME = 2 + t * 7                                          -- 2 .. 9 seconds

	wall.Color = tier.color
	if light then light.Color = tier.color end

	workspace:SetAttribute("WallSpeed", speed)
	workspace:SetAttribute("WallTier", tier.name)
	workspace:SetAttribute("WallColor", tier.color)
	print(string.format("Wall round: %s | %.1f studs/s | damage %d | ragdoll %.1fs", tier.name, speed, HIT_DAMAGE, RAGDOLL_TIME))

	wall.Position = Vector3.new(START_X, wall.Position.Y, wall.Position.Z)
	wall.Transparency = 1
	face.Enabled = false
	task.wait(math.max(0, WAIT_TIME - WARNING_TIME))

	-- Countdown warning shown to every player
	for i = WARNING_TIME, 1, -1 do
		workspace:SetAttribute("WallCountdown", i)
		task.wait(1)
	end
	workspace:SetAttribute("WallCountdown", nil)

	wall.Transparency = 0
	face.Enabled = true
	local goal = {Position = Vector3.new(END_X, wall.Position.Y, wall.Position.Z)}
	local tween = TweenService:Create(wall, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), goal)
	tween:Play()
	tween.Completed:Wait()
end
