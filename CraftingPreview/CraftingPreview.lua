
local PREVIEW = LibStub("LibPreview")

local function MoveTooltip(self)
	self.creationPanel.resultTooltip:ClearAnchors()
	self.creationPanel.resultTooltip:SetAnchor(RIGHT, GuiRoot, CENTER, -self.creationPanel.resultTooltip:GetWidth() / 2, -self.creationPanel.resultTooltip:GetHeight() / 2)
	self.creationPanel.resultTooltip:SetMouseEnabled(true)
	self.creationPanel.resultTooltip:SetMovable(true)
end

local function ResetTooltip(self)
	self.creationPanel.resultTooltip:ClearAnchors()
	self.creationPanel.resultTooltip:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -245)
end

ZO_PreHook(ZO_Smithing, "SetMode", function(self, mode)
	if mode ~= SMITHING_MODE_CREATION then
		ResetTooltip(self)
		if SMITHING_SCENE.state ~= SCENE_SHOWN then return end
		-- we exit creation mode, so exit creation preview
		PREVIEW:DisablePreviewMode()
	else
		MoveTooltip(self)
	end
end)

local function TooltipHook(self, patternIndex, materialIndex,materialQuantity, itemStyleId, traitIndex)
	-- the crafting result changed, change the preview
	local itemLink = GetSmithingPatternResultLink(patternIndex, materialIndex,materialQuantity, itemStyleId, traitIndex)
	PREVIEW:PreviewItemLink(itemLink)
end
ZO_PreHook(ZO_SmithingCreation, "SetupResultTooltip", TooltipHook)
ZO_PreHook(ZO_GamepadSmithingCreation, "SetupResultTooltip", TooltipHook)
