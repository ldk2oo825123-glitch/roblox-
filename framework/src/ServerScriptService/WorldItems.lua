--!strict
-- Shared Roblox rendering; inventory/variant/value authority lives elsewhere.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Config)
local Data = require(RS.BrainrotData)
local WorldItems = {}
function WorldItems.label(part, text, variantName)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ItemLabel"; gui.Size = UDim2.fromOffset(table.unpack(Config.Inventory.LabelSize))
	gui.StudsOffset = Vector3.new(Config.Math.Zero, Config.Inventory.LabelHeight, Config.Math.Zero)
	gui.MaxDistance = Config.Inventory.LabelMaxDistance; gui.AlwaysOnTop = true; gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(Config.Math.One, Config.Math.One); label.BackgroundTransparency = Config.Math.One
	label.TextSize = Config.Inventory.LabelTextSize; label.Text = text
	local variant = Data.GetVariant(variantName)
	label.TextColor3 = variant and Config.Brainrots.VariantColours[variant.Colour] or Config.Inventory.UI.TextColour
	label:SetAttribute("RainbowLabel", variant and variant.ColourCycling or false); label.Parent = gui
	return label
end
function WorldItems.create(item, position, parent)
	local part = Instance.new("Part")
	part.Name = "BrainrotItem"; part.Anchored = true; part.CanCollide = false
	part.Size = Vector3.new(table.unpack(Config.Inventory.WorldItemSize)); part.Position = position
	local variant = Data.GetVariant(item.variant)
	local tier = Data.GetTier(item.tier)
	part.Color = item.r and Color3.new(item.r or 0.8, item.g or 0.8, item.b or 0.8) or variant.BaseColour or (tier and tier.Colour) or Config.Brainrots.VariantColours[variant.Colour]
	part.Material = Enum.Material[item.mat or variant.Material or (tier and tier.Material) or "SmoothPlastic"] or Enum.Material.SmoothPlastic
	part:SetAttribute("ItemId", item.id); part.Parent = parent
	WorldItems.label(part, item.tier .. " / " .. item.variant .. " $" .. tostring(item.value), item.variant)
	return part
end
return WorldItems
