local FADE_DURATION = 10

-- Keep the controller independent of UIParent so it can restore the UI.
local controller = CreateFrame("Frame", nil, nil)

local inCombat = false
local fadeElapsed = 0
local enabled = true


-- Each group is one checkbox. Frame names are resolved when used, so
-- frames created later can still participate in the fade.
local hudGroups = {
    { key = "player", label = "Player frame", frames = { "PlayerFrame" } },
    { key = "target", label = "Target frame", frames = { "TargetFrame" } },
    { key = "focus", label = "Focus frame", frames = { "FocusFrame" } },
    { key = "minimap", label = "Minimap (map only)", default = false,
      frames = { "MinimapCluster" } },
    { key = "mainBar", label = "Main action bar", frames = { "MainActionBar" } },
    { key = "bottomLeft", label = "Bottom-left action bar", frames = { "MultiBarBottomLeft" } },
    { key = "bottomRight", label = "Bottom-right action bar", frames = { "MultiBarBottomRight" } },
    { key = "rightBar", label = "Right action bar", frames = { "MultiBarRight" } },
    { key = "leftBar", label = "Left action bar", frames = { "MultiBarLeft" } },
    { key = "bar5", label = "Additional bar 5", frames = { "MultiBar5" } },
    { key = "bar6", label = "Additional bar 6", frames = { "MultiBar6" } },
    { key = "bar7", label = "Additional bar 7", frames = { "MultiBar7" } },
    { key = "petBar", label = "Pet action bar", frames = { "PetActionBar" } },
    { key = "stanceBar", label = "Stance bar", frames = { "StanceBar" } },
    { key = "quests", label = "Quest tracker", frames = { "ObjectiveTrackerFrame" } },
    { key = "buffs", label = "Buffs", frames = { "BuffFrame" } },
    { key = "debuffs", label = "Debuffs", frames = { "DebuffFrame" } },
    { key = "menu", label = "Menu buttons", frames = { "MicroMenu" } },
    { key = "bags", label = "Bag buttons", frames = { "BagsBar" } },
    { key = "progress", label = "Experience / reputation", frames = { "StatusTrackingBarManager" } },
    { key = "chat", label = "Chat and chat controls", frames = {
        "ChatFrameMenuButton", "ChatFrameChannelButton",
        "GeneralDockManager", "QuickJoinToastButton",
    } },
    { key = "swing", label = "Main-hand swing timer", frames = { "SwingTimerMainHandFrame" } },
}

local chatGroup = hudGroups[21]
local chatParts = { "", "Background", "ButtonFrame", "EditBox" }
for i = 1, NUM_CHAT_WINDOWS do
    for _, suffix in ipairs(chatParts) do
        table.insert(chatGroup.frames, "ChatFrame" .. i .. suffix)
    end
end
-- Docked tabs inherit GeneralDockManager's fade; do not fade tabs twice.

local originalAlphas = {} --Stores original alpha values of frames

local function SaveOriginalAlphas()
    for _, group in ipairs(hudGroups) do
        for _, name in ipairs(group.frames) do
            local frame = _G[name]
            if frame then
                originalAlphas[frame] = frame:GetAlpha()
            end
        end 
    end
end

local db
local optionsPanel
local currentHUDAlpha = 1

local function InitializeOptions()
    if type(ImmersiveUIDB) ~= "table" then
        ImmersiveUIDB = {}
    end
    if type(ImmersiveUIDB.elements) ~= "table" then
        ImmersiveUIDB.elements = {}
    end
    db = ImmersiveUIDB

    for _, group in ipairs(hudGroups) do
        -- Check nil/type explicitly so a saved false stays false.
        if type(db.elements[group.key]) ~= "boolean" then
            db.elements[group.key] = group.default ~= false
        end
    end
end


local function SetHUDAlpha(alpha)
    if not db then return end

    for _, group in ipairs(hudGroups) do
        for _, name in ipairs(group.frames) do
            local frame = _G[name]
            if frame and db.elements[group.key] then
                frame:SetAlpha(originalAlphas[frame] * alpha)
            end
        end
    end
end

local function FadeUpdate(self, elapsed)
    fadeElapsed = math.min(fadeElapsed + elapsed, FADE_DURATION)
    SetHUDAlpha(1 - fadeElapsed / FADE_DURATION)

    if fadeElapsed >= FADE_DURATION then
        self:SetScript("OnUpdate", nil)
    end
end

local panelNames = {
    "CharacterFrame",
    "WorldMapFrame",
    "SpellBookFrame",
    "PlayerSpellsFrame",
    "ContainerFrameCombinedBags",
}

local function IsPanelOpen()
    if optionsPanel and optionsPanel:IsShown() then return true end

    for _, name in ipairs(panelNames) do
        local frame = _G[name]

        if frame and frame:IsShown() then
            return true
        end
    end

    -- Check separate bag windows.
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]

        if frame and frame:IsShown() then
            return true
        end
    end

    return false
end

local function UpdateVisibility()
    if not db then return end

    if not enabled or inCombat or UnitExists("target") or IsPanelOpen() then
        controller:SetScript("OnUpdate", nil)
        SetHUDAlpha(1)
    else
		fadeElapsed = 0
        controller:SetScript("OnUpdate", FadeUpdate)
    end
end

function ImmersiveUI_Toggle()
	enabled = not enabled
	UpdateVisibility()
end

local panelWatcher = CreateFrame("Frame", nil, nil)
local checkElapsed = 0
local panelWasOpen = false

panelWatcher:SetScript("OnUpdate", function(self, elapsed)
    checkElapsed = checkElapsed + elapsed

    if checkElapsed < 0.1 then
        return
    end

    checkElapsed = 0

    local panelIsOpen = IsPanelOpen()

    if panelIsOpen ~= panelWasOpen then
        panelWasOpen = panelIsOpen
        UpdateVisibility()
    end
end)


BINDING_HEADER_IMMERSIVEUI = "ImmersiveUI"
BINDING_NAME_IMMERSIVEUI_TOGGLE = "Toggle UI fading"


controller:RegisterEvent("ADDON_LOADED")
controller:RegisterEvent("PLAYER_ENTERING_WORLD")
controller:RegisterEvent("PLAYER_LOGIN")
controller:RegisterEvent("PLAYER_TARGET_CHANGED")
controller:RegisterEvent("PLAYER_REGEN_DISABLED")
controller:RegisterEvent("PLAYER_REGEN_ENABLED")
controller:SetScript("OnEvent", function(self, event, addonName)

    if event == "ADDON_LOADED" then
        if addonName == "ImmersiveUI" then
            InitializeOptions()
            self:UnregisterEvent("ADDON_LOADED")
        end
        return
    elseif event == "PLAYER_LOGIN" then
        SaveOriginalAlphas()
        self:UnregisterEvent("PLAYER_LOGIN")
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        inCombat = InCombatLockdown()
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    end

    UpdateVisibility()
end)

local bindingFrame = CreateFrame("Frame")
bindingFrame:RegisterEvent("PLAYER_LOGIN")

bindingFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    if InCombatLockdown() then
        return
    end

    local action = "IMMERSIVEUI_TOGGLE"
    local defaultKey = "CTRL-SHIFT-Z"

    -- Preserve a shortcut already assigned to our toggle.
    if GetBindingKey(action) then
        return
    end

    -- Preserve any other action already using this key.
    local existingAction = GetBindingAction(defaultKey)

    if existingAction and existingAction ~= "" then
        return
    end

    if SetBinding(defaultKey, action) then
        SaveBindings(GetCurrentBindingSet())
    end
end)

-- A small standalone options window. No external settings library needed.
local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "ImmersiveUIOptionsPanel", UIParent)
    panel:Hide()
    optionsPanel = panel
    panel:SetSize(590, 460)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.06, 0.06, 0.08, 0.97)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -20)
    title:SetText("ImmersiveUI - Elements to fade")

    local help = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 22, -50)
    help:SetText("Checked: fade this element. Unchecked: leave it visible. Changes save automatically.")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() panel:Hide() end)

    local checkboxes = {}
    for index, group in ipairs(hudGroups) do
        local key = group.key
        local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        checkbox:SetSize(26, 26)
        checkbox:SetPoint("TOPLEFT", 22 + column * 282, -80 - row * 29)
        local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", checkbox, "RIGHT", 3, 0)
        label:SetText(group.label)
        checkbox:SetScript("OnClick", function(self)
            db.elements[key] = self:GetChecked() and true or false
            SetHUDAlpha(1)
        end)
        table.insert(checkboxes, { button = checkbox, key = key })
    end

    local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("BOTTOMLEFT", 22, 20)
    note:SetText("Minimap markers may remain visible. HUD stays visible while these options are open.")

    panel:SetScript("OnShow", function()
        for _, entry in ipairs(checkboxes) do
            entry.button:SetChecked(db.elements[entry.key])
        end
        UpdateVisibility()
    end)
    panel:SetScript("OnHide", function() UpdateVisibility() end)
    table.insert(UISpecialFrames, "ImmersiveUIOptionsPanel")
    return panel
end

SLASH_IMMERSIVEUIOPTIONS1 = "/immersiveoptions"
SLASH_IMMERSIVEUIOPTIONS2 = "/iui"
SlashCmdList.IMMERSIVEUIOPTIONS = function()
    if not db then return end
    local panel = optionsPanel or CreateOptionsPanel()
    if panel:IsShown() then panel:Hide() else panel:Show() end
end
