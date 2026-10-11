--!strict
-- Config and clock injection also permits plain Lua economy/stat verification.
local Profile = {}
function Profile.new(Config, WheelLogic, now)
	local P, entries = {}, {}
	local zero, one = Config.Math.Zero, Config.Math.One
	now = now or os.time
	local function finite(n) return type(n) == "number" and n == n and n >= zero and n < math.huge end
	function P.get(player) return entries[player] and entries[player].profile end
	function P.getUpgradeLevel(player, name)
		local profile = P.get(player); return profile and profile.upgrades[name]
	end
	function P.getEffectiveStats(player)
		local profile = P.get(player); if not profile then return nil end
		local base = { IncomeMult = one }
		for _, upgrade in ipairs(Config.Shop.Upgrades) do
			local value = upgrade.BaseValue + upgrade.Step * profile.upgrades[upgrade.Name]
			if upgrade.MaxValue then value = math.min(value, upgrade.MaxValue) end
			if upgrade.Stat == "IncomeBonus" then base.IncomeMult = one + value else base[upgrade.Stat] = value end
		end
		return WheelLogic.effectiveStats(profile.wheel, now(), base)
	end
	function P.applyStats(player)
		local stats = P.getEffectiveStats(player); if not stats then return end
		for name, value in pairs(stats) do player:SetAttribute(name, value) end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = stats.WalkSpeed; humanoid.UseJumpPower = true
			humanoid.JumpPower = stats.JumpPower; humanoid.MaxHealth = stats.MaxHealth
			humanoid.Health = math.min(humanoid.Health, stats.MaxHealth)
		end
		return stats
	end
	function P.addCash(player, n)
		local profile = P.get(player)
		if not profile or not finite(n) or not finite(profile.cash + n) then return false end
		profile.cash = profile.cash + n; player:SetAttribute("Cash", profile.cash); return true
	end
	function P.spendCash(player, n)
		local profile = P.get(player)
		if not profile or not finite(n) or n > profile.cash then return false end
		-- Check and subtract contain no yields: concurrent purchases cannot overspend.
		profile.cash = profile.cash - n; player:SetAttribute("Cash", profile.cash); return true
	end
	function P.setUpgradeLevel(player, name, level)
		local profile = P.get(player)
		if not profile or profile.upgrades[name] == nil or not finite(level)
			or level ~= math.floor(level) or level > Config.Shop.MaxUpgradeLevel then return false end
		profile.upgrades[name] = level; P.applyStats(player); return true
	end
	function P.Remove(player)
		local entry = entries[player]; if entry then entry.connection:Disconnect() end
		entries[player] = nil
	end
	function P.Init(player, profile)
		P.Remove(player)
		local entry = { profile = profile }; entries[player] = entry
		entry.connection = player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			if entries[player] == entry and player.Character == character then P.applyStats(player) end
		end)
		player:SetAttribute("Cash", profile.cash); P.applyStats(player)
	end
	return P
end
return Profile
