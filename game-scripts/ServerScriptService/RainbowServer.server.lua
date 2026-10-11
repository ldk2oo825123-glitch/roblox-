local CollectionService = game:GetService("CollectionService")

local hue = 0
while true do
	task.wait(0.1)
	hue = (hue + 0.02) % 1
	local color = Color3.fromHSV(hue, 1, 1)
	for _, part in ipairs(CollectionService:GetTagged("RainbowBrainrot")) do
		part.Color = color
	end
	for _, label in ipairs(CollectionService:GetTagged("RainbowText")) do
		label.TextColor3 = color
	end
end
