-- RocketMount | OptionsTab.lua
-- The window's Settings tab: draws the definitions of Options.lua in three columns inside the list's inset.
-- (03/11/2026) The settings left the game's Options > AddOns panel for the addon's own window, at the user's word.
-- The pieces are the game's (UICheckButtonTemplate, MinimalSliderWithSteppersTemplate, WowStyle1DropdownTemplate)
-- with the measures the game's own settings use: the box 28, a sub-option indented 15 (Blizzard_SettingControls),
-- a section marked by a gold title and a rule, not by air (wow-ui-design). A sub-option goes grey while the option
-- it hangs under is off, as SetParentInitializer did in the game's panel.
local ADDON, ns = ...
local L = ns.L

local Tab = {}
ns.OptionsTab = Tab

local MARGIN, COL_GAP, TOP = 18, 26, 14
local CHECK = 28
local CHECK_TEXT = 2          -- the label's anchor after the 28 box (ResizeCheckButtonTemplate: +2)
local INDENT = 15             -- a sub-option, as the game's panel indents it
local H_CHECK = 32
local H_LABEL = 12            -- GameFontHighlightSmall
local GAP_LABEL = 2
local H_CONTROL = 26
local H_FIELD = H_LABEL + GAP_LABEL + H_CONTROL + 10
local H_SECTION = H_LABEL + 4 + 10
local GAP_SECTION = 18

local page, controls = nil, {}

local function Tooltip(owner, d)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(GameTooltip, d.name)
    GameTooltip_AddNormalLine(GameTooltip, d.tip, true)
    GameTooltip:Show()
end

local function ParentOn(d)
    if not d.parent then return true end
    for _, c in ipairs(controls) do
        if c.def.key == d.parent then return c.def.get() and true or false end
    end
    return true
end

-- Values and the grey state of every control, from the saved settings.
function Tab.Refresh()
    for _, c in ipairs(controls) do
        local on = ParentOn(c.def)
        c.Refresh(on)
    end
end

local function Section(col, y, title)
    local text = col:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", col, "TOPLEFT", 0, -y)
    text:SetText(title)
    local rule = col:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", col, "TOPLEFT", 0, -y - H_LABEL - 4)
    rule:SetPoint("TOPRIGHT", col, "TOPRIGHT", 0, -y - H_LABEL - 4)
    ns.Style.Divider(rule)   -- (03/11) the design system's divider (Style.lua)
    return y + H_SECTION + 4
end

local function Check(col, y, x, width, d)
    local check = CreateFrame("CheckButton", nil, col, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", col, "TOPLEFT", x, -y)
    check:SetSize(CHECK, CHECK)
    if type(check.Text) == "table" and check.Text.SetText then
        check.Text:SetText(d.name)
        check.Text:SetFontObject("GameFontHighlightSmall")
        check.Text:ClearAllPoints()
        check.Text:SetPoint("LEFT", check, "RIGHT", CHECK_TEXT, 0)
        check.Text:SetWidth(width - x - CHECK - CHECK_TEXT)
        check.Text:SetJustifyH("LEFT")
    end
    check:SetScript("OnClick", function(self)
        d.set(self:GetChecked() and true or false)
        Tab.Refresh()
    end)
    check:SetScript("OnEnter", function(self) Tooltip(self, d) end)
    check:SetScript("OnLeave", GameTooltip_Hide)
    -- the tooltip also on a greyed box: it says what the option does and why it is grey
    check:SetMotionScriptsWhileDisabled(true)
    return y + H_CHECK, {
        def = d, widget = check,
        Refresh = function(on)
            check:SetChecked(d.get() and true or false)
            check:SetEnabled(on)
            if type(check.Text) == "table" and check.Text.SetTextColor then
                local c = on and HIGHLIGHT_FONT_COLOR or DISABLED_FONT_COLOR
                check.Text:SetTextColor(c.r, c.g, c.b)
            end
        end,
    }
end

local function Label(col, y, x, width)
    local text = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", col, "TOPLEFT", x, -y)
    text:SetWidth(width - x)
    text:SetJustifyH("LEFT")
    return text
end

-- The value goes in the label above the slider (the template's own side labels stay hidden: they leaked out of
-- the column in the Rocket Meter's options).
local function Slider(col, y, x, width, d)
    local text = Label(col, y, x, width)
    local slider = CreateFrame("Slider", nil, col, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("TOPLEFT", col, "TOPLEFT", x, -(y + H_LABEL + GAP_LABEL))
    slider:SetWidth(width - x)
    slider:SetHeight(H_CONTROL)
    local function Write(on)
        local value = (d.format or "%d"):format(d.get())
        local c = on == false and DISABLED_FONT_COLOR or HIGHLIGHT_FONT_COLOR
        text:SetText(c:WrapTextInColorCode(d.name) .. "   " .. NORMAL_FONT_COLOR:WrapTextInColorCode(value))
    end
    local steps = math.floor((d.max - d.min) / d.step + 0.5)
    if slider.Init and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Event then
        slider:Init(d.get(), d.min, d.max, steps)
        slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
            if value ~= d.get() then d.set(value) end
            Write(true)
        end)
    end
    slider:SetScript("OnEnter", function(self) Tooltip(self, d) end)
    slider:SetScript("OnLeave", GameTooltip_Hide)
    return y + H_FIELD, {
        def = d, widget = slider,
        Refresh = function(on)
            if slider.SetValue then slider:SetValue(d.get()) end
            if slider.SetEnabled then slider:SetEnabled(on) end
            Write(on)
        end,
    }
end

local function Dropdown(col, y, x, width, d)
    local text = Label(col, y, x, width)
    text:SetText(d.name)
    local dropdown = CreateFrame("DropdownButton", nil, col, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", col, "TOPLEFT", x, -(y + H_LABEL + GAP_LABEL))
    dropdown:SetWidth(width - x)
    dropdown:SetHeight(H_CONTROL)
    if MenuUtil and MenuUtil.CreateRadioMenu then
        local list = {}
        for _, e in ipairs(d.entries()) do list[#list + 1] = { e.label, e.value } end
        MenuUtil.CreateRadioMenu(dropdown,
            function(value) return d.get() == value end,
            function(value) d.set(value) end,
            unpack(list))
    end
    dropdown:SetScript("OnEnter", function(self) Tooltip(self, d) end)
    dropdown:SetScript("OnLeave", GameTooltip_Hide)
    return y + H_FIELD, {
        def = d, widget = dropdown,
        Refresh = function(on)
            if dropdown.GenerateMenu then dropdown:GenerateMenu() end
            if dropdown.SetEnabled then dropdown:SetEnabled(on) end
            local c = on and HIGHLIGHT_FONT_COLOR or DISABLED_FONT_COLOR
            text:SetTextColor(c.r, c.g, c.b)
        end,
    }
end

---Builds the page inside the list's inset (hidden until the tab is chosen).
function Tab.Build(host, hostWidth)
    if page then return page end
    page = CreateFrame("Frame", nil, host)
    page:SetPoint("TOPLEFT", host, "TOPLEFT", MARGIN, -TOP)
    page:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -MARGIN, 8)
    page:Hide()
    local width = math.floor((hostWidth - 2 * MARGIN - 2 * COL_GAP) / 3)
    local cols, ys = {}, {}
    for i = 1, 3 do
        local col = CreateFrame("Frame", nil, page)
        col:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * (width + COL_GAP), 0)
        col:SetSize(width, 1)
        cols[i], ys[i] = col, 0
    end
    page.cols, page.colWidth = cols, width
    local column = 1
    for _, d in ipairs(ns.OptionDefs()) do
        if d.section then
            column = d.column or column
            local col = cols[column]
            if ys[column] > 0 then ys[column] = ys[column] + GAP_SECTION end
            ys[column] = Section(col, ys[column], d.section)
        else
            local col, x = cols[column], d.parent and INDENT or 0
            local y, c = ys[column], nil
            if d.kind == "checkbox" then
                y, c = Check(col, y, x, width, d)
            elseif d.kind == "slider" then
                y, c = Slider(col, y, x, width, d)
            elseif d.kind == "dropdown" then
                y, c = Dropdown(col, y, x, width, d)
            end
            ys[column] = y
            if c then
                c.column, c.y = column, ys[column]
                controls[#controls + 1] = c
            end
        end
    end
    page.heights = ys
    return page
end

function Tab.Show(on)
    if not page then return end
    page:SetShown(on)
    if on then Tab.Refresh() end
end

function Tab.IsShown() return page ~= nil and page:IsShown() end
function Tab.__controls() return controls end
function Tab.__page() return page end
