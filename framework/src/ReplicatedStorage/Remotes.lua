--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

type Definition = { Name: string, ClassName: "RemoteEvent" | "RemoteFunction" }

-- Task T5 fills the single allowlist as feature contracts are implemented.
local definitions: { Definition } = {
	{ Name = "DropItem", ClassName = "RemoteFunction" },
	{ Name = "PlaceItem", ClassName = "RemoteFunction" },
	{ Name = "PickUpItem", ClassName = "RemoteFunction" },
	{ Name = "InventoryUpdate", ClassName = "RemoteEvent" },
	{ Name = "GetInventoryState", ClassName = "RemoteFunction" },

	{ Name = "SpinWheel", ClassName = "RemoteFunction" },
	{ Name = "WheelUpdate", ClassName = "RemoteEvent" },
	{ Name = "GetWheelState", ClassName = "RemoteFunction" },
}
local folderName = "GameRemotes"
local Remotes = {}

local function getFolder(): Instance
	local existing = ReplicatedStorage:FindFirstChild(folderName)
	if existing then
		assert(existing:IsA("Folder"), folderName .. " must be a Folder")
		return existing
	end
	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = ReplicatedStorage
		return folder
	end
	local folder = ReplicatedStorage:WaitForChild(folderName)
	assert(folder:IsA("Folder"), folderName .. " must be a Folder")
	return folder
end

function Remotes.Get(name: string): Instance
	local definition: Definition? = nil
	for _, candidate in ipairs(definitions) do
		if candidate.Name == name then
			definition = candidate
			break
		end
	end
	assert(definition, "Unknown remote: " .. name)
	local folder = getFolder()
	local remote = folder:FindFirstChild(name)
	if not remote then
		if RunService:IsServer() then
			remote = Instance.new(definition.ClassName)
			remote.Name = name
			remote.Parent = folder
		else
			remote = folder:WaitForChild(name)
		end
	end
	assert(remote:IsA(definition.ClassName), "Wrong remote class: " .. name)
	return remote
end

function Remotes.Setup()
	assert(RunService:IsServer(), "Remote setup must run on the server")
	getFolder()
	for _, definition in ipairs(definitions) do
		Remotes.Get(definition.Name)
	end
end

return Remotes
