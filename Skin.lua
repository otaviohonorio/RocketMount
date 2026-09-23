-- RocketMount | Skin.lua
-- Single source of truth for the look. A new panel that copies values from the window
-- diverges on the third change; every screen in this addon reads from here.
local _, ns = ...

local FONT = "Fonts\\FRIZQT__.TTF"

ns.Skin = {
    font = FONT,

    -- The game's type scale (Fonts.xml): 20 / 16 / 14 / 12 / 10. Used by the sighting panel;
    -- the main window uses the game's own font objects (GameFontNormal & co.) since 23/09.
    rowFontSize = 12,
    subFontSize = 10,

    gold  = { 1, 0.82, 0 },
    text  = { 0.86, 0.87, 0.90 },
    cream = { 1, 0.96, 0.86 },
    dim   = { 0.55, 0.55, 0.58 },
}

-- (!) WHAT LEFT THIS FILE ON 23/09, when the window moved onto `ButtonFrameTemplate`: the damage
-- meter's header strip (`ui-damagemeters-header-bar` and its crop), the flat panel alpha, the
-- self-painted row backgrounds and the list/section rhythm. The template, the inset and the
-- mount journal's row atlases draw all of that now; keeping the numbers here would leave two
-- sources for a look only one of them draws.

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
