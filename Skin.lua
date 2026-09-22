-- RocketMounts | Skin.lua
-- Single source of truth for the look. A new panel that copies values from the window
-- diverges on the third change; every screen in this addon reads from here.
local _, ns = ...

local FONT = "Fonts\\FRIZQT__.TTF"

ns.Skin = {
    font = FONT,

    -- The game's type scale (Fonts.xml): 20 / 16 / 14 / 12 / 10.
    titleFontSize = 14,
    rowFontSize   = 12,
    subFontSize   = 10,
    headFontSize  = 12,

    -- DATA ROW rhythm (native meter): 25 of ink + 4 of breathing room = 29. This is not
    -- the form rhythm (26 + 9 = 35) -- this is a list, not a field.
    -- The ink goes from 25 to 36 because a row here has TWO lines: the name and the reason
    -- it sits in that position. 12pt + 10pt + spacing does not fit in 25. The 4 between
    -- rows stays as it is -- that is what sets the rhythm, not the height of the ink.
    rowHeight  = 36,
    rowSpacing = 4,

    -- Blizzard's section header block: 45px with the title at y=-16, which leaves 25 of
    -- white above. The section here is lighter (it is a list, not a form), but the ratio
    -- holds: the section gap must be >= 2x the row gap.
    sectionHeight = 22,
    sectionGap    = 12,

    -- Content margins (Blizzard_SettingsList.lua:44-45).
    padding     = 10,
    leftMargin  = 12,

    -- A reading panel needs a background: without one the text competes with the scenery.
    panelAlpha = 0.92,
    rowBackground     = { 1, 1, 1, 0.045 },
    rowBackgroundHl   = { 1, 1, 1, 0.12 },
    rowBackgroundSel  = { 1, 0.82, 0, 0.14 },

    gold  = { 1, 0.82, 0 },
    text  = { 0.86, 0.87, 0.90 },
    cream = { 1, 0.96, 0.86 },
    dim   = { 0.55, 0.55, 0.58 },

    headerAtlas = "ui-damagemeters-header-bar",
    -- The crop Details' Midnight skin uses to strip the transparent padding.
    headerCrop  = { 0.045, 0.965, 4 / 60, 56 / 60 },
    headerHeight = 32,
}

-- Colour per effort band. Not a class colour and it does not compete with one:
-- green/blue/yellow/orange/grey is the vocabulary of difficulty, not of identity.
--
-- (!) There were SIX colours here for seven bands, and they had drifted a step: when the
-- "check with the vendor" band was inserted in second place, every colour below it kept its
-- old position and took on a meaning that was not its own. The visible result was inverted
-- severity -- "short farm" came out red while "long road", which is worse, came out grey --
-- and the seventh band had no colour at all, falling back to whatever each caller chose.
-- The band is the meaning; the colour follows it, and now there is one per band.
ns.TIER_COLOR = {
    { 0.30, 0.85, 0.40 },   -- 1 guaranteed, just go get it   green
    { 0.45, 0.78, 0.95 },   -- 2 guaranteed, nearly unlocked  blue
    { 0.94, 0.80, 0.25 },   -- 3 guaranteed, halfway          yellow
    { 0.95, 0.60, 0.25 },   -- 4 luck, good odds              orange
    { 0.85, 0.35, 0.35 },   -- 5 long road                    red
    { 0.62, 0.55, 0.70 },   -- 6 costs more than the price    muted violet: a caveat, not a rank
    { 0.55, 0.55, 0.58 },   -- 7 no estimate                  grey: absence, not severity
    { 0.40, 0.40, 0.42 },   -- 8 gone from the game           darker grey: not a rank at all
}

function ns.ApplyHeaderArt(texture)
    local info = C_Texture and C_Texture.GetAtlasInfo
        and C_Texture.GetAtlasInfo(ns.Skin.headerAtlas)

    if info and (info.file or info.filename) then
        texture:SetTexture(info.file or info.filename)
        local l, r = info.leftTexCoord or 0, info.rightTexCoord or 1
        local t, b = info.topTexCoord or 0, info.bottomTexCoord or 1
        local w, h = r - l, b - t
        local crop = ns.Skin.headerCrop
        texture:SetTexCoord(l + w * crop[1], l + w * crop[2], t + h * crop[3], t + h * crop[4])
        texture:SetVertexColor(1, 1, 1)
        return true
    end

    -- `SetAtlas` fails silently; the fallback is explicit on purpose.
    texture:SetColorTexture(0.13, 0.11, 0.07, 0.95)
    return false
end

-- A FontString created without a template has no font, and SetText answers
-- "Font not set" -- which usually reaches the player as "I clicked and nothing opened".
function ns.NewText(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetFont(ns.Skin.font, size or ns.Skin.rowFontSize, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    local c = color or ns.Skin.text
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetJustifyH(justify or "LEFT")
    return fs
end
