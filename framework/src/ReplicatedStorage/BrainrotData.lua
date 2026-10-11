--!strict

local Config = require(script.Parent.Config)

export type Tier = { Name: string, BaseValue: number }
export type Variant = {
	Name: string,
	Bonus: number,
	Odds: number,
	Colour: string,
	ColourCycling: boolean,
}

local BrainrotData = {}

function BrainrotData.GetTier(name: string): Tier?
	for _, tier in ipairs(Config.Brainrots.Tiers) do
		if tier.Name == name then
			return tier
		end
	end
	return nil
end

function BrainrotData.GetVariant(name: string): Variant?
	for _, variant in ipairs(Config.Brainrots.Variants) do
		if variant.Name == name then
			return variant
		end
	end
	return nil
end

function BrainrotData.CalculateValue(tierName: string, variantName: string): number
	local tier = BrainrotData.GetTier(tierName)
	local variant = BrainrotData.GetVariant(variantName)
	assert(tier, "Unknown brainrot tier: " .. tierName)
	assert(variant, "Unknown brainrot variant: " .. variantName)
	local value = tier.BaseValue * (Config.Math.One + variant.Bonus)
	return math.round(value * Config.Math.ValueRoundingScale) / Config.Math.ValueRoundingScale
end

return BrainrotData
