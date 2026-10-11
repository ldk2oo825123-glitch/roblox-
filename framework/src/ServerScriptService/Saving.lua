--!strict
-- UpdateAsync store and runtime services are injected. No engine calls in new().
local Saving = {}
function Saving.new(Config, Logic, deps)
	local S, sessions = {}, {}
	local zero, one = Config.Math.Zero, Config.Math.One
	local policy = Config.Saving
	assert(policy.StoreName ~= policy.LegacyStoreName, "Legacy DataStore is read-only")
	local offline, closing = false, false
	local sequence = zero
	local function key(player) return policy.KeyPrefix .. tostring(player.UserId) end
	local function active(player) return not deps.isActive or deps.isActive(player) end
	local function warnFailure(reason) deps.warn("Saving: " .. tostring(reason)) end
	local function apiDisabled(reason)
		local text = string.lower(tostring(reason))
		return deps.isStudio and (string.find(text, "studio access to api", one, true)
			or string.find(text, "api services are not enabled", one, true)
			or string.find(text, "studioaccesstoapisnotallowed", one, true)
			or string.find(text, "api access is not enabled", one, true)
			or string.find(text, "api services are disabled", one, true))
	end
	local function retry(action, deadline)
		local last
		for attempt = one, policy.RetryAttempts do
			if deadline and deps.clock() >= deadline then return false, "time budget exhausted" end
			local ok, value = pcall(action)
			if ok then return true, value end
			last = value
			if apiDisabled(value) then return false, value end
			if attempt < policy.RetryAttempts then
				local delay = policy.RetryDelaySeconds * policy.RetryBackoff ^ (attempt - one)
				if deadline then delay = math.min(delay, math.max(zero, deadline - deps.clock())) end
				deps.wait(delay)
			end
		end
		return false, last
	end
	local function cleanup(player)
		deps.Bases.Remove(player); deps.Inventory.Remove(player); deps.Wheel.Remove(player); deps.Profile.Remove(player)
	end
	local function apply(player, profile)
		-- Wheel shares Profile's upgrade table; inventory owns a detached item state.
		deps.Profile.Init(player, profile)
		deps.Wheel.Init(player, profile.wheel, profile)
		deps.Inventory.Init(player, { carried = {}, inventory = profile.inventory, pedestals = profile.pedestals, indexFound = profile.indexFound })
		deps.Bases.Assign(player)
	end
	function S.load(player)
		if closing or sessions[player] then return false, "already loading or closing" end
		sequence = sequence + one
		local entry = { ready = false, token = deps.jobId .. ":" .. tostring(sequence), busy = false, nextSave = deps.now() + policy.IntervalSeconds }
		sessions[player] = entry -- Failed loads stay explicitly un-saveable.
		local reason, loaded, legacy
		local ok, result = true, nil
		if not offline then
			-- Read before UpdateAsync: transforms cannot yield. A concurrent v2 write wins.
			if deps.legacyStore then
				ok, result = retry(function() return deps.store:GetAsync(key(player)) end)
				if ok and result == nil then
					ok, legacy = retry(function() return deps.legacyStore:GetAsync(key(player)) end)
					if not ok then result = legacy end
				end
			end
			if ok then
				ok, result = retry(function()
					reason = nil
					return deps.store:UpdateAsync(key(player), function(raw)
						local profile, invalid = Logic.deserialize(raw or legacy, deps.now())
						if not profile then reason = invalid; return nil end
						local lock = type(raw) == "table" and raw._session
						if type(lock) == "table" and lock.token ~= entry.token then
							if type(lock.at) ~= "number" or lock.at ~= lock.at or math.abs(lock.at) == math.huge
								or lock.at + policy.SessionLockSeconds > deps.now() then reason = "session locked"; return nil end
						end
						local data = Logic.serialize(profile)
						data._session = { token = entry.token, jobId = deps.jobId, at = deps.now() }
						return data
					end)
				end)
			end
			if not ok and apiDisabled(result) then
				offline = true; warnFailure("Studio API services are disabled; running without persistence")
			elseif ok and type(result) == "table" and type(result._session) == "table" and result._session.token == entry.token then
				loaded, reason = Logic.deserialize(result)
			end
		end
		if offline then loaded = Logic.default() end
		if not loaded then
			entry.failure = reason or result or "load failed"
			warnFailure(entry.failure); if active(player) then player:Kick(policy.LoadFailureMessage) end
			return false, entry.failure
		end
		entry.profile = loaded; entry.ready = true
		if not active(player) or closing then
			-- Join yielded while the player left: release the claim without applying.
			S.save(player, true); sessions[player] = nil; return false, "player left"
		end
		local applied, failure = pcall(apply, player, loaded)
		if not applied then
			-- Release only the successfully decoded original; never save partial Init.
			S.save(player, true); entry.ready = false; cleanup(player)
			warnFailure(failure); player:Kick(policy.LoadFailureMessage); return false, failure
		end
		entry.applied = true; return true
	end
	function S.gather(player)
		local entry = sessions[player]; if not entry or not entry.ready then return nil end
		if not entry.applied then return Logic.validate(entry.profile) end
		local profile = deps.Profile.get(player); local inventory = deps.Inventory.getState(player)
		local wheel = deps.Wheel.getState(player)
		if not profile or not inventory or not wheel then return nil, "state missing; refusing blank save" end
		return Logic.validate({ version = profile.version, cash = profile.cash, upgrades = profile.upgrades,
			pedestals = inventory.pedestals, inventory = inventory.inventory, indexFound = inventory.indexFound,
			wheel = wheel, legacyDiscovered = profile.legacyDiscovered, savedAt = deps.now() }) -- carried is deliberately excluded.
	end
	function S.save(player, release, deadline)
		local entry = sessions[player]
		if not entry or not entry.ready then return false, "unsaveable" end
		while entry.busy do
			if deadline and deps.clock() >= deadline then return false, "time budget exhausted" end
			deps.wait(policy.PollSeconds)
		end
		if not entry.ready then return false, "unsaveable" end
		entry.busy = true
		local profile, reason = S.gather(player)
		if not profile then entry.busy = false; warnFailure(reason); return false, reason end
		profile.savedAt = deps.now()
		local data = Logic.serialize(profile)
		local ok, result = true, data
		if not offline then
			ok, result = retry(function()
				reason = nil
				return deps.store:UpdateAsync(key(player), function(raw)
					if type(raw) ~= "table" then reason = "session missing"; return nil end
					if type(raw.version) == "number" and raw.version > policy.SchemaVersion then reason = "future version"; return nil end
					local lock = raw._session
					if type(lock) ~= "table" or lock.token ~= entry.token then reason = "session lost"; return nil end
					local output = Logic.serialize(profile)
					if not release then output._session = { token = entry.token, jobId = deps.jobId, at = deps.now() } end
					return output
				end)
			end, deadline)
		end
		local success = ok and result ~= nil and reason == nil
		entry.busy = false; entry.nextSave = deps.now() + policy.IntervalSeconds
		if success and release then entry.ready = false end
		if reason == "future version" or reason == "session lost" or reason == "session missing" then
			entry.ready = false; if active(player) then player:Kick(policy.LoadFailureMessage) end
		end
		if not success then warnFailure(reason or result or "save failed") end
		return success, reason or (not ok and result or nil)
	end
	function S.remove(player)
		local entry = sessions[player]
		-- Snapshot/save completes before any module clears its state.
		if entry and entry.ready then S.save(player, true, deps.clock() + policy.CloseBudgetSeconds) end
		cleanup(player)
		if not entry or entry.ready or entry.profile or entry.failure then sessions[player] = nil end
	end
	function S.tick()
		if closing then return end
		for player, entry in pairs(sessions) do
			if entry.ready and not entry.busy and deps.now() >= entry.nextSave then
				entry.nextSave = deps.now() + policy.IntervalSeconds
				deps.spawn(function() S.save(player, false) end)
			end
		end
	end
	function S.close()
		closing = true
		local deadline, pending = deps.clock() + policy.CloseBudgetSeconds, zero
		for player, entry in pairs(sessions) do
			if entry.ready then
				pending = pending + one
				deps.spawn(function()
					local ok, failure = pcall(S.save, player, true, deadline)
					if not ok then warnFailure(failure) end
					pending = pending - one
				end)
			end
		end
		while pending > zero and deps.clock() < deadline do deps.wait(policy.PollSeconds) end
		if pending > zero then warnFailure("shutdown save time budget exhausted") end
		return pending == zero
	end
	return S
end
return Saving
