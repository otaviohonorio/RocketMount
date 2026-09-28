-- RocketMount | MapButton.lua
-- A button on the world map that hides and shows the markers of the mounts.
--
-- (!) THE USER (28/09), with MCL's three buttons at the corner of the map on screen: *"Icones para
-- esconder as marcações das montarias como o MCL faz, caso o jogador precise do mapa limpo"*.
-- The idea is MCL's; the button is the game's. It is built with the pieces and the measures of
-- the game's own map buttons (`WorldMapTrackingPinButtonTemplate`, Blizzard_WorldMapTemplates.xml,
-- 12.1.0): 32 by 32, the round background 25 wide at 3,-4, the icon 20 wide at 7,-6, the ring
-- 54 wide, the same highlight, the icon pushed to 8,-8 while the button is held. The icon is the
-- horseshoe the game draws for the mounts' category, which comes lit and unlit.
--
-- It goes in the column of the map's own buttons, at the top right, under the last one that is
-- there -- the game's two, and whatever else put a button in that column. What is read of the
-- others is where they are on the screen, nothing else.
local ADDON, ns = ...
local L = ns.L

local MapButton = {}
ns.MapButton = MapButton

MapButton.Geometry = {
    SIZE = 32, STEP = 32, X = -4, TOP = -2,
    BG = 25, BG_X = 3, BG_Y = -4,
    ICON = 20, ICON_X = 7, ICON_Y = -6, HELD_X = 8, HELD_Y = -8,
    BORDER = 54,
    -- The art of the category is a disc with a rim of its own; inside the ring of the map's
    -- buttons the rim is one too many. After `SetAtlas` the cut is a fraction of THE ART.
    CROP = 0.12,
}
MapButton.ICON_ON = "category-icons_mounts_active"
MapButton.ICON_OFF = "category-icons_mounts_inactive"

local button

---Whether the markers are on the map: the same switch the options panel has.
function MapButton.On()
    return not (ns.db and ns.db.mapPins == false)
end

---Whether the button itself is wanted.
function MapButton.Wanted()
    return not (ns.db and ns.db.mapButton == false)
end

---How far down the column the button goes: under the lowest of the buttons already in it.
---@param others table[] -- `{ shown, point, relativeTo, x, y, width }` of each frame of the map
---@param canvas table -- what the column is anchored to
---@return number y
function MapButton.Slot(others, canvas)
    local G = MapButton.Geometry
    local fundo
    for _, f in ipairs(type(others) == "table" and others or {}) do
        if type(f) == "table" and f.shown == true and f.point == "TOPRIGHT" and f.relativeTo == canvas
            and type(f.x) == "number" and type(f.y) == "number" and math.abs(f.x - G.X) <= 2
            and type(f.width) == "number" and math.abs(f.width - G.SIZE) <= 4 then
            if not fundo or f.y < fundo then fundo = f.y end
        end
    end
    if not fundo then return G.TOP end
    return fundo - G.STEP
end

---Where every other frame of the map is. A frame that does not answer is left out.
local function Others(map)
    local out = {}
    if not (map and map.GetChildren) then return out end
    for _, f in ipairs({ map:GetChildren() }) do
        if f ~= button and type(f) == "table" and f.GetPoint then
            local ok, point, rel, _, x, y = pcall(f.GetPoint, f, 1)
            if ok and type(point) == "string" then
                local okS, shown = pcall(f.IsShown, f)
                local okW, w = pcall(f.GetWidth, f)
                out[#out + 1] = {
                    shown = okS and shown == true, point = point, relativeTo = rel, x = x, y = y,
                    width = okW and w or nil,
                }
            end
        end
    end
    return out
end

---Puts the button in its place in the column. The others can come and go with the map.
function MapButton.Place()
    if not (button and WorldMapFrame and WorldMapFrame.GetCanvasContainer) then return end
    local canvas = WorldMapFrame:GetCanvasContainer()
    local y = MapButton.Slot(Others(WorldMapFrame), canvas)
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", MapButton.Geometry.X, y)
    button.slotY = y
end

---The icon says what the map is showing; the button is there only when it is wanted.
function MapButton.Update()
    if not button then return end
    local G = MapButton.Geometry
    button.Icon:SetAtlas(MapButton.On() and MapButton.ICON_ON or MapButton.ICON_OFF)
    button.Icon:SetTexCoord(G.CROP, 1 - G.CROP, G.CROP, 1 - G.CROP)
    button:SetShown(MapButton.Wanted())
end

---What the tooltip says: the title, what the map is showing, what the click does.
---@return string title, string line, string instruction
function MapButton.TooltipText()
    if MapButton.On() then
        return "Rocket Mount", L["The markers of the mounts you are missing are on the map."], L["Click: hide them"]
    end
    return "Rocket Mount", L["The markers of the mounts you are missing are hidden."], L["Click: show them"]
end

function MapButton.Toggle()
    if not ns.db then return end
    ns.db.mapPins = not MapButton.On()
    if PlaySound and SOUNDKIT then
        PlaySound(MapButton.On() and SOUNDKIT.UI_MAP_WAYPOINT_BUTTON_CLICK_ON
            or SOUNDKIT.UI_MAP_WAYPOINT_BUTTON_CLICK_OFF)
    end
    MapButton.Update()
    if ns.MapPins then ns.MapPins.Refresh() end
end

local function Tooltip(self)
    local titulo, linha, instrucao = MapButton.TooltipText()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(GameTooltip, titulo)
    GameTooltip_AddNormalLine(GameTooltip, linha)
    GameTooltip_AddBlankLineToTooltip(GameTooltip)
    GameTooltip_AddInstructionLine(GameTooltip, instrucao)
    GameTooltip:Show()
end

local function Build()
    local G = MapButton.Geometry
    local b = CreateFrame("Button", nil, WorldMapFrame)
    b:SetSize(G.SIZE, G.SIZE)
    b:SetFrameStrata("HIGH")

    b.Background = b:CreateTexture(nil, "BACKGROUND")
    b.Background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    b.Background:SetSize(G.BG, G.BG)
    b.Background:SetPoint("TOPLEFT", G.BG_X, G.BG_Y)

    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Icon:SetSize(G.ICON, G.ICON)
    b.Icon:SetPoint("TOPLEFT", G.ICON_X, G.ICON_Y)

    b.Border = b:CreateTexture(nil, "OVERLAY")
    b.Border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b.Border:SetSize(G.BORDER, G.BORDER)
    b.Border:SetPoint("TOPLEFT")

    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    b:SetScript("OnMouseDown", function(self)
        self.Icon:SetPoint("TOPLEFT", G.HELD_X, G.HELD_Y)
    end)
    b:SetScript("OnMouseUp", function(self)
        self.Icon:SetPoint("TOPLEFT", G.ICON_X, G.ICON_Y)
    end)
    b:SetScript("OnClick", function(self)
        MapButton.Toggle()
        if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then Tooltip(self) end
    end)
    b:SetScript("OnEnter", Tooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

---The button is made once, when the map exists.
function MapButton.Enable()
    if button or not (WorldMapFrame and WorldMapFrame.GetCanvasContainer) then return end
    button = Build()
    MapButton.button = button
    -- The column is another with each map: the game's own buttons are not on every one.
    if hooksecurefunc and WorldMapFrame.OnMapChanged then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", MapButton.Place)
    end
    if WorldMapFrame.HookScript then
        WorldMapFrame:HookScript("OnShow", MapButton.Place)
    end
    MapButton.Place()
    MapButton.Update()
end
