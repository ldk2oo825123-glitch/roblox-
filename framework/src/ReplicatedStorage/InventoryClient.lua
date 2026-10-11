--!strict
-- One shared client snapshot fetch, so Inventory and Index cannot miss Init or
-- race separate requests against the server snapshot cooldown.
local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS.Remotes)
local Config = require(RS.Config)
local Client = { state = nil }
local changed = Instance.new("BindableEvent")
Client.Changed = changed.Event
local function accept(state) Client.state = state; changed:Fire(state) end
Remotes.Get("InventoryUpdate").OnClientEvent:Connect(accept)
task.spawn(function()
	while not Client.state do
		local success, result = pcall(function() return Remotes.Get("GetInventoryState"):InvokeServer() end)
		if success and result.ok then accept(result.state) end
		if not Client.state then task.wait(Config.Wheel.UI.RefreshSeconds) end
	end
end)
function Client.invoke(name, ...)
	local success, result = pcall(Remotes.Get(name).InvokeServer, Remotes.Get(name), ...)
	if not success then return { ok = false, reason = "request unavailable" } end
	return result
end
return Client
