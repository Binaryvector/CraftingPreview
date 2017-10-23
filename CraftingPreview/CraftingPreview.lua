
-- debug:
local d = function() end

--[[
TODO: add localization
--]]
local language = GetCVar("language.2")
if language == "de" then
	ZO_CreateStringId("SI_PREVIEW_IN_EMPTY_WORLD", "Alt. Vorschau")
	ZO_CreateStringId("SI_CRAFTING_COLOR_SCHEME", "Farbschema: ")
else
	ZO_CreateStringId("SI_PREVIEW_IN_EMPTY_WORLD", "Preview in empty world")
	ZO_CreateStringId("SI_CRAFTING_COLOR_SCHEME", "Color scheme: ")
end

local COLORSTAMP = 1

-- create an empty options fragment. we don't use any special options yet, but that may change in the future.
local CRAFTING_PREVIEW_OPTIONS_FRAGMENT = ZO_ItemPreviewOptionsFragment:New({})
-- create a new fragment to position the player on the screen. we can not use the default fragment, because it doesn't fully show the characters helmet
local function CalculateCenteredFramingTarget()
	local screenWidth, screenHeight = GuiRoot:GetDimensions()
	return screenWidth / 2, 0.6 * screenHeight
end
local FRAME_TARGET_CRAFTING_FRAGMENT = ZO_NormalizedPointFragment:New(CalculateCenteredFramingTarget, SetFrameLocalPlayerTarget)

-- add a new preview mode to ZOS' preview manager
local CRAFTING_PREVIEW = #ITEM_PREVIEW_KEYBOARD.previewTypeObjects + 1
ZO_ItemPreviewType_Crafting = ZO_ItemPreviewType:Subclass()

function ZO_ItemPreviewType_Crafting:SetStaticParameters(patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem, dyeBrushId)
    self.patternIndex = patternIndex or 1
    self.materialIndex = materialIndex or 1
    self.materialQuantity = materialQuantity or 1
    self.styleIndex = styleIndex or 1
    self.traitIndex = traitIndex or 1
    self.useUniversalStyleItem = useUniversalStyleItem
    self.dyeBrushId = dyeBrushId or 4
end

function ZO_ItemPreviewType_Crafting:GetStaticParameters()
	return self.patternIndex, self.materialIndex, self.materialQuantity, self.styleIndex, self.traitIndex, self.useUniversalStyleItem, self.dyeBrushId
end

function ZO_ItemPreviewType_Crafting:HasStaticParameters(patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem, dyeBrushId)
	local same = false
	same = same and patternIndex == self.patternIndex and materialIndex == self.materialIndex
	same = same and materialQuantity == self.materialQuantity and styleIndex == self.styleIndex
	same = same and traitIndex == self.traitIndex and dyeBrushId == self.dyeBrushId
	return same
end

function ZO_ItemPreviewType_Crafting:ResetStaticParameters()
	self.patternIndex = nil
    self.materialIndex = nil
    self.materialQuantity = nil
    self.styleIndex = nil
    self.traitIndex = nil
    self.useUniversalStyleItem = nil
    self.dyeBrushId = nil
end

function ZO_ItemPreviewType_Crafting:Apply(variationIndex)
	--d("style", self.styleIndex)
	PreviewCraftItem(self.patternIndex, self.materialIndex, self.materialQuantity, self.styleIndex+1, self.traitIndex, self.useUniversalStyleItem, self.dyeBrushId)
end

function ZO_ItemPreview_Shared:PreviewCraftItem(dyeBrushId, patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem)
	if dyeBrushId then dyeBrushId = dyeBrushId + 3 end
	--d("start", dyeBrushId, patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex)
	self:SharedPreviewSetup(CRAFTING_PREVIEW, patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem, dyeBrushId)
end

ITEM_PREVIEW_KEYBOARD.previewTypeObjects[CRAFTING_PREVIEW] = ZO_ItemPreviewType_Crafting:New()
ITEM_PREVIEW_GAMEPAD.previewTypeObjects[CRAFTING_PREVIEW] = ZO_ItemPreviewType_Crafting:New()

-- we have to hack a bit into the preview manager, because the default lighting settings don't work well with armor
-- the reflections on metal are too strong
local STARTED_PREVIEW = false -- true, if we started the preview mode, false if it was started by something else
do
	local EMPTY_WORLD_PREVIEW_SUN_AZIMUTH_RADIANS = math.rad(135)
	local EMPTY_WORLD_PREVIEW_SUN_ELEVATION_RADIANS = math.rad(45)

	function ZO_ItemPreview_Shared:RefreshPreviewInEmptyWorld()
		if self.previewInEmptyWorld then
			if STARTED_PREVIEW then -- if the preview mode was started by use, use different light settings
				SetPreviewInEmptyWorld(0, EMPTY_WORLD_PREVIEW_SUN_ELEVATION_RADIANS)
			else
				SetPreviewInEmptyWorld(EMPTY_WORLD_PREVIEW_SUN_AZIMUTH_RADIANS, EMPTY_WORLD_PREVIEW_SUN_ELEVATION_RADIANS)
			end
		else
			ClearPreviewInEmptyWorld()
		end
	end
end

-- we only want to use the preview mode when crafting armor (preview doesn't work for weapons)
local VALID_TYPES = {
	[ZO_SMITHING_CREATION_FILTER_TYPE_ARMOR] = true,
	[ZO_SMITHING_CREATION_FILTER_TYPE_SET_ARMOR] = true,
}

function ZO_Smithing:IsModeValidForPreview()
	return self.mode == SMITHING_MODE_CREATION and VALID_TYPES[self.creationPanel.typeFilter]
end

function ZO_Smithing:IsPreviewing()
	return ITEM_PREVIEW_KEYBOARD:IsInteractionCameraPreviewEnabled()
end

function ZO_Smithing_Gamepad:IsPreviewing()
	return ITEM_PREVIEW_GAMEPAD:IsInteractionCameraPreviewEnabled()
end

function ZO_Smithing:EnablePreview()
	if self:IsPreviewing() then return end
	-- previewing doesn't work for shields, so don't preview on a woodworking station
	if GetCraftingInteractionType() == CRAFTING_TYPE_WOODWORKING then return end
	d("enable")
	STARTED_PREVIEW = true
	-- enable the preview mode
	ITEM_PREVIEW_KEYBOARD:SetInteractionCameraPreviewEnabled(
		true,
		FRAME_TARGET_CRAFTING_FRAGMENT,
		FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT,
		CRAFTING_PREVIEW_OPTIONS_FRAGMENT)
	-- move the crafting tooltip so it doesn't occlude the character
	self.creationPanel.resultTooltip:ClearAnchors()
	self.creationPanel.resultTooltip:SetAnchor(RIGHT, GuiRoot, CENTER, -self.creationPanel.resultTooltip:GetWidth() / 2, -self.creationPanel.resultTooltip:GetHeight() / 2)
	VariationWindow:SetParent(self.creationPanel.resultTooltip:GetParent())
	VariationWindow:SetAnchor(TOP, self.creationPanel.resultTooltip, BOTTOM, 0, 64)
	VariationWindow:SetHidden(false)
	-- display the world checkbox and enable the empty world if needed
	self.creationPanel.emptyWorldCheckbox:SetHidden(false)
	ITEM_PREVIEW_KEYBOARD:SetPreviewInEmptyWorld(self.creationPanel.emptyWorldCheckbox:GetState() ~= 0)
	SYSTEMS:GetObject("itemPreview"):PreviewCraftItem(COLORSTAMP, ITEM_PREVIEW_KEYBOARD.previewTypeObjects[CRAFTING_PREVIEW]:GetStaticParameters())
end

function ZO_Smithing:DisablePreview()
	if not self:IsPreviewing() then return end
	d("disable")
	STARTED_PREVIEW = false
	-- disable the preview mode
	ITEM_PREVIEW_KEYBOARD:SetInteractionCameraPreviewEnabled(
		false,
		FRAME_TARGET_CRAFTING_FRAGMENT,
		FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT,
		CRAFTING_PREVIEW_OPTIONS_FRAGMENT)
	-- move the tooltip back to its correct location
	self.creationPanel.resultTooltip:ClearAnchors()
	self.creationPanel.resultTooltip:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -245)
	-- the preview mode doesn't work with crafting weapons, so we don't need this checkbox. so hide it.
	self.creationPanel.emptyWorldCheckbox:SetHidden(true)
	VariationWindow:SetHidden(true)
end

function ZO_Smithing_Gamepad:EnablePreview()
	if self:IsPreviewing() then return end
	STARTED_PREVIEW = true
	ITEM_PREVIEW_GAMEPAD:SetInteractionCameraPreviewEnabled(
		true,
		FRAME_TARGET_CRAFTING_FRAGMENT,
		FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT,
		CRAFTING_PREVIEW_OPTIONS_FRAGMENT)
end

function ZO_Smithing_Gamepad:DisablePreview()
	if not self:IsPreviewing() then return end
	STARTED_PREVIEW = false
	ITEM_PREVIEW_GAMEPAD:SetInteractionCameraPreviewEnabled(
		false,
		FRAME_TARGET_CRAFTING_FRAGMENT,
		FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT,
		CRAFTING_PREVIEW_OPTIONS_FRAGMENT)
end

-- on the PC UI, the crafting UI will return to the previous tab.
-- so we have to reenable the preview mode, if the we quit the crafting station while previewing
SMITHING_SCENE:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
		if SMITHING:IsModeValidForPreview() then
			SMITHING:EnablePreview()
		end
        elseif newState == SCENE_HIDDEN then
		SMITHING:DisablePreview()
	end
end)


ZO_PreHook(ZO_Smithing, "SetMode", function(self, mode)
	if SMITHING_SCENE.state ~= SCENE_SHOWN then return end
	-- we switch to creation mode, so enable preview
	if mode == SMITHING_MODE_CREATION then
		if VALID_TYPES[self.creationPanel.typeFilter] then
			self:EnablePreview()
		end
		return
	end
	-- we exit creation mode, so exit preview
	if self:IsModeValidForPreview() then
		self:DisablePreview()
	end
	
end)

-- when switching between weapon/armor mode, we will have to dis-/enable the preview mode
ZO_PreHook(ZO_SharedSmithingCreation, "ChangeTypeFilter", function(self, filterData)
	if SMITHING_SCENE.state ~= SCENE_SHOWN then return end
	local typeFilter = filterData.descriptor
	if VALID_TYPES[typeFilter] then
		if SMITHING.mode == SMITHING_MODE_CREATION then
			SMITHING:EnablePreview()
		end
		return
	end
	-- we exit creation mode, so exit preview
	if VALID_TYPES[self.typeFilter] then
		SMITHING:DisablePreview()
	end
end)

do
	-- update the preview mode according to the current armor selection
	local lastMaterial
	ZO_PreHook(ZO_SmithingCreation, "SetupResultTooltip", function(self, ...)
		if not SMITHING:IsPreviewing() then return end
		d("setup")
		-- the material change isn't applied unless the pattern changes as well
		-- so switch between two patterns when the material changes, to circumvent this issue
		local pattern, material = ...
		if material ~= lastMaterial then
			d("hackfix")
			if pattern == GetNumSmithingPatterns() then
				--PreviewCraftItem(4, materialIndex, select(3,...))
				SYSTEMS:GetObject("itemPreview"):PreviewCraftItem(COLORSTAMP, 4, material, select(3,...))
			else
				local patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem, dyeBrushId = ...
				d("first", pattern+1, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem, COLORSTAMP)
				--PreviewCraftItem(pattern+1, materialIndex, materialQuantity, styleIndex, traitIndex, useUniversalStyleItem, COLORSTAMP)
				d("second", COLORSTAMP, pattern+1, material, select(3,...))
				SYSTEMS:GetObject("itemPreview"):PreviewCraftItem(COLORSTAMP, pattern+1, material, select(3,...))
			end
			lastMaterial = material
		end
		SYSTEMS:GetObject("itemPreview"):PreviewCraftItem(COLORSTAMP, ...)
	end)	
end

-- exit the preview mode, if the player quits the crafting station.
GAMEPAD_SMITHING_CREATION_SCENE:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_HIDING then
		SMITHING_GAMEPAD:DisablePreview()
	end
end)

-- when switchting between weapon/armor crafting mode, we will have to dis-/enable the preview mode
local originalGenerateTabBarEntries = ZO_GamepadSmithingCreation.GenerateTabBarEntries
function ZO_GamepadSmithingCreation:GenerateTabBarEntries(...)
	local tabBarEntries = originalGenerateTabBarEntries(self, ...)
	-- the tabBarEntries table contains the callbacks of the weapon/armor crafting modes
	-- we will hook into these callback function
	for _, entry in pairs(tabBarEntries) do
		local this = entry
		local callback = entry.callback
		entry.callback = function()
			local typeFilter = this.mode
			if VALID_TYPES[typeFilter] then
				if SMITHING_GAMEPAD.mode == SMITHING_MODE_CREATION then
					SMITHING_GAMEPAD:EnablePreview()
				end
				callback()
				return
			end
			-- we exit creation mode, so exit preview
			if VALID_TYPES[self.typeFilter] then
				SMITHING_GAMEPAD:DisablePreview()
			end
			callback()
		end
	end
	return tabBarEntries
end

do
	local lastMaterial
	ZO_PreHook(ZO_GamepadSmithingCreation, "SetupResultTooltip", function(self, ...)
		if not SMITHING_GAMEPAD:IsPreviewing() then return end
		local pattern, material = ...
		if material ~= lastMaterial then
			if pattern == GetNumSmithingPatterns() then
				SYSTEMS:GetObject("itemPreview"):PreviewCraftItem(COLORSTAMP, 4, material, select(3,...))
			else
				SYSTEMS:GetObject("itemPreview"):PreviewCraftItem(COLORSTAMP, pattern+1, material, select(3,...))
			end
			lastMaterial = material
		end
		SYSTEMS:GetObject("itemPreview"):PreviewCraftItem(COLORSTAMP, ...)
	end)
end

-- move the knowledge checkbox to the left and add a new checkbox for the empty world preview mode
local creationPanel = SMITHING.creationPanel
creationPanel.haveKnowledgeCheckBox:ClearAnchors()

creationPanel.emptyWorldCheckbox = GetWindowManager():CreateControlFromVirtual("PreviewInEmptyWorld", creationPanel.haveKnowledgeCheckBox:GetParent(), "ZO_CheckButton")
creationPanel.emptyWorldCheckbox:SetHidden(true)

if language == "de" then
	creationPanel.haveKnowledgeCheckBox:SetAnchor(LEFT,creationPanel.haveMaterialsCheckBox, RIGHT, 175, 0)
	creationPanel.emptyWorldCheckbox:SetAnchor(LEFT,creationPanel.haveKnowledgeCheckBox, RIGHT, 170, 0)
else
	creationPanel.haveKnowledgeCheckBox:SetAnchor(LEFT,creationPanel.haveMaterialsCheckBox, RIGHT, 120, 0)
	creationPanel.emptyWorldCheckbox:SetAnchor(LEFT,creationPanel.haveKnowledgeCheckBox, RIGHT, 150, 0)
end

ZO_CheckButton_SetLabelText(creationPanel.emptyWorldCheckbox, GetString(SI_PREVIEW_IN_EMPTY_WORLD))
ZO_CheckButton_SetToggleFunction(creationPanel.emptyWorldCheckbox, function()
	ITEM_PREVIEW_KEYBOARD:SetPreviewInEmptyWorld(creationPanel.emptyWorldCheckbox:GetState() ~= 0)
	if creationPanel.emptyWorldCheckbox:GetState() == 0 then
		SYSTEMS:GetObject("itemPreview"):EndCurrentPreview()
	end
	-- we have to reset the crafting selection, because it is removed when switchting between empty/normal world.
	SYSTEMS:GetObject("itemPreview"):PreviewCraftItem(COLORSTAMP, ITEM_PREVIEW_KEYBOARD.previewTypeObjects[CRAFTING_PREVIEW]:GetStaticParameters())
end)

function CraftingPreview_OnInitialize(control)
	--ZO_Spinner:New(control)
	--self.pointsSpinner:SetMinMax(0, zo_min(numAvailablePoints + self:GetNumPendingPoints(), maxPossiblePoints))
	--self.pointsSpinner:SetValue(self:GetNumPendingPoints() + self.pointsSpinner:GetMin())
	VariationWindowLabel:SetText(GetString(SI_CRAFTING_COLOR_SCHEME) .. COLORSTAMP)
	VariationWindowRightArrow:SetHandler("OnClicked", function(control)
		COLORSTAMP = COLORSTAMP + 1
		VariationWindowLabel:SetText(GetString(SI_CRAFTING_COLOR_SCHEME) .. COLORSTAMP)
		SYSTEMS:GetObject("itemPreview"):PreviewCraftItem(COLORSTAMP, ITEM_PREVIEW_KEYBOARD.previewTypeObjects[CRAFTING_PREVIEW]:GetStaticParameters())
	end)
	VariationWindowLeftArrow:SetHandler("OnClicked", function(control)
		COLORSTAMP = zo_max(COLORSTAMP - 1,1)
		VariationWindowLabel:SetText(GetString(SI_CRAFTING_COLOR_SCHEME) .. COLORSTAMP)
		SYSTEMS:GetObject("itemPreview"):PreviewCraftItem(COLORSTAMP, ITEM_PREVIEW_KEYBOARD.previewTypeObjects[CRAFTING_PREVIEW]:GetStaticParameters())
	end)
end
