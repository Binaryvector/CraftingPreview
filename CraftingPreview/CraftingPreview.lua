
local PREVIEW = LibStub("LibPreview")

ZO_PreHook(ZO_Smithing, "SetMode", function(self, mode)
	if SMITHING_SCENE.state ~= SCENE_SHOWN then return end
	-- we exit creation mode, so exit creation preview
	if mode ~= SMITHING_MODE_CREATION then
		PREVIEW:DisablePreviewMode()
	end
end)

ZO_PreHook(ZO_SmithingCreation, "SetupResultTooltip", function(self, patternIndex, materialIndex,materialQuantity, itemStyleId, traitIndex)
	-- the crafting result changed, change the preview
	local itemLink = GetSmithingPatternResultLink(patternIndex, materialIndex,materialQuantity, itemStyleId, traitIndex)
	PREVIEW:PreviewItemLink(itemLink)
end)
